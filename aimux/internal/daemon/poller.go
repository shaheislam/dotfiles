package daemon

import (
	"crypto/sha256"
	"fmt"
	"log"
	"os/exec"
	"strings"
	"time"

	"github.com/shaheislam/aimux/internal/provider"
	"github.com/shaheislam/aimux/internal/state"
)

// Tokyo Night hex colors for tmux window status, matching _common.sh.
const (
	colorWorking = "#f7768e" // red
	colorWaiting = "#e0af68" // yellow
	colorDone    = "#9ece6a" // green
	colorStuck   = "#bb9af7" // magenta
)

// PaneInfo represents a single tmux pane discovered during polling.
type PaneInfo struct {
	Target     string // full target: session:window.pane
	TTY        string // e.g., /dev/ttys005
	WindowName string
	Session    string
	WindowIdx  string
}

// lastOutputInfo tracks the content hash and timestamp for stuck detection.
type lastOutputInfo struct {
	hash      string
	changedAt time.Time
}

// Poller iterates all tmux panes, detects agent processes, analyzes content,
// updates state files, and triggers notifications.
type Poller struct {
	providers    *provider.Registry
	notifier     *Notifier
	stuckTimeout time.Duration
	logger       *log.Logger

	// Track last output change per pane target for stuck detection
	lastOutput map[string]lastOutputInfo
}

// NewPoller creates a poller with the given provider registry and notifier.
func NewPoller(providers *provider.Registry, notifier *Notifier, stuckTimeout time.Duration, logger *log.Logger) *Poller {
	return &Poller{
		providers:    providers,
		notifier:     notifier,
		stuckTimeout: stuckTimeout,
		logger:       logger,
		lastOutput:   make(map[string]lastOutputInfo),
	}
}

// Poll performs one complete polling cycle across all tmux panes.
func (p *Poller) Poll() error {
	panes, err := p.listPanes()
	if err != nil {
		return fmt.Errorf("listing panes: %w", err)
	}

	// Track which panes have active agents so we can clear stale entries
	activePanes := make(map[string]bool)

	for _, pane := range panes {
		prov, found := p.providers.DetectAny(pane.TTY)
		if !found {
			// No agent on this pane -- clear color and notification state
			p.clearPaneState(pane)
			continue
		}

		activePanes[pane.Target] = true

		content, err := p.capturePaneContent(pane.Target, 20)
		if err != nil {
			p.logger.Printf("warning: failed to capture pane %s: %v", pane.Target, err)
			continue
		}

		agentState := prov.DetectState(content)

		// Stuck detection: if agent is working but output hasn't changed
		agentState = p.checkStuck(pane.Target, content, agentState)

		// Update tmux window color
		p.applyWindowColor(pane, agentState)

		// Update workspace state file
		p.updateWorkspaceState(pane, prov, agentState)

		// Notify on completion (deduplicated)
		if agentState == state.AgentDone {
			if p.notifier.ShouldNotify(pane.Target) {
				p.notifier.MarkNotified(pane.Target)
				msg := fmt.Sprintf("Agent complete: %s", pane.WindowName)
				p.notifier.Notify("aimux", msg)
				p.logger.Printf("notify: agent complete on %s (%s)", pane.Target, pane.WindowName)
			}
		} else {
			// Agent is not done -- allow re-notification if it completes later
			p.notifier.ClearNotified(pane.Target)
		}
	}

	// Clean up lastOutput entries for panes that no longer have agents
	for target := range p.lastOutput {
		if !activePanes[target] {
			delete(p.lastOutput, target)
		}
	}

	return nil
}

// listPanes queries tmux for all panes across all sessions.
func (p *Poller) listPanes() ([]PaneInfo, error) {
	format := "#{session_name}:#{window_index}.#{pane_index}\t#{pane_tty}\t#{window_name}\t#{session_name}\t#{window_index}"
	out, err := exec.Command("tmux", "list-panes", "-a", "-F", format).Output()
	if err != nil {
		return nil, fmt.Errorf("tmux list-panes: %w", err)
	}

	var panes []PaneInfo
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		fields := strings.SplitN(line, "\t", 5)
		if len(fields) < 5 {
			continue
		}
		panes = append(panes, PaneInfo{
			Target:     fields[0],
			TTY:        fields[1],
			WindowName: fields[2],
			Session:    fields[3],
			WindowIdx:  fields[4],
		})
	}

	return panes, nil
}

// capturePaneContent returns the last N lines of a tmux pane.
func (p *Poller) capturePaneContent(target string, lines int) (string, error) {
	startLine := fmt.Sprintf("-%d", lines)
	out, err := exec.Command("tmux", "capture-pane", "-t", target, "-p", "-S", startLine).Output()
	if err != nil {
		return "", fmt.Errorf("tmux capture-pane -t %s: %w", target, err)
	}
	return string(out), nil
}

// checkStuck implements stuck detection by hashing pane content.
// If the content hash has not changed for longer than the stuck timeout
// while the agent is in the working state, we transition to stuck.
func (p *Poller) checkStuck(target, content string, current state.AgentState) state.AgentState {
	hash := hashContent(content)
	now := time.Now()

	info, exists := p.lastOutput[target]
	if !exists || info.hash != hash {
		// Content changed -- record new hash and timestamp
		p.lastOutput[target] = lastOutputInfo{
			hash:      hash,
			changedAt: now,
		}
		return current
	}

	// Content unchanged -- check if stuck timeout exceeded while working
	if current == state.AgentWorking || current == state.AgentIdle {
		elapsed := now.Sub(info.changedAt)
		if elapsed >= p.stuckTimeout {
			return state.AgentStuck
		}
	}

	return current
}

// applyWindowColor sets the tmux @wname_style option based on agent state.
func (p *Poller) applyWindowColor(pane PaneInfo, agentState state.AgentState) {
	win := pane.Session + ":" + pane.WindowIdx

	var color string
	switch agentState {
	case state.AgentWorking:
		color = colorWorking
	case state.AgentIdle:
		color = colorWaiting
	case state.AgentDone:
		color = colorDone
	case state.AgentStuck:
		color = colorStuck
	default:
		color = colorWaiting
	}

	style := fmt.Sprintf("fg=%s", color)
	_ = exec.Command("tmux", "set-window-option", "-t", win, "@wname_style", style).Run()
}

// clearPaneState removes color styling and notification records for a pane
// that no longer has an agent process.
func (p *Poller) clearPaneState(pane PaneInfo) {
	win := pane.Session + ":" + pane.WindowIdx
	_ = exec.Command("tmux", "set-window-option", "-t", win, "-u", "@wname_style").Run()
	p.notifier.ClearNotified(pane.Target)
}

// updateWorkspaceState persists the current agent state for a pane.
func (p *Poller) updateWorkspaceState(pane PaneInfo, prov provider.Provider, agentState state.AgentState) {
	ws := state.FindByTmuxTarget(pane.Target)
	if ws == nil {
		// Create a new workspace state entry for this pane
		now := time.Now()
		ws = &state.WorkspaceState{
			Name:       pane.WindowName,
			Status:     "active",
			Provider:   prov.Name(),
			CreatedAt:  now,
			LastOutput: now,
			TmuxTarget: pane.Target,
		}
	}

	ws.AgentState = agentState
	ws.TmuxTarget = pane.Target

	switch agentState {
	case state.AgentWorking:
		ws.Status = "running"
		if ws.StartedAt == nil {
			now := time.Now()
			ws.StartedAt = &now
		}
	case state.AgentDone:
		ws.Status = "done"
		if ws.CompletedAt == nil {
			now := time.Now()
			ws.CompletedAt = &now
		}
	case state.AgentStuck:
		ws.Status = "stuck"
	case state.AgentFailed:
		ws.Status = "failed"
	default:
		ws.Status = "active"
	}

	if info, ok := p.lastOutput[pane.Target]; ok {
		ws.LastOutput = info.changedAt
		ws.LastChecksum = info.hash
	}

	if err := state.Write(ws); err != nil {
		p.logger.Printf("warning: failed to write workspace state for %s: %v", pane.WindowName, err)
	}
}

// hashContent returns a short hex-encoded SHA-256 hash of the content string.
func hashContent(content string) string {
	h := sha256.Sum256([]byte(content))
	return fmt.Sprintf("%x", h[:8])
}
