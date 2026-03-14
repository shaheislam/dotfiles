package provider

import (
	"fmt"
	"strings"

	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/state"
)

// Claude implements the Provider interface for Claude Code.
type Claude struct {
	cfg config.ProviderConfig
}

// NewClaude creates a Claude provider from its config entry.
func NewClaude(cfg config.ProviderConfig) *Claude {
	return &Claude{cfg: cfg}
}

// Name returns "claude".
func (c *Claude) Name() string { return "claude" }

// DetectProcess returns true if a Claude Code process is found on the given TTY.
func (c *Claude) DetectProcess(tty string) bool {
	return detectProcessByPatterns(tty, c.cfg.DetectPatterns)
}

// DetectState analyzes pane content for Claude-specific patterns.
// Working: the thinking spinner pattern (e.g., "... (")
// Done: completion markers like COMPLETE, _DONE, TICKET_TASK_COMPLETE
func (c *Claude) DetectState(content string) state.AgentState {
	return detectStateFromContent(content, c.cfg.WorkingPattern, c.cfg.DonePatterns)
}

// LaunchCommand builds the shell command to launch Claude Code in a worktree.
func (c *Claude) LaunchCommand(worktree, prompt string) string {
	parts := []string{c.cfg.Command}
	parts = append(parts, c.cfg.Args...)

	if prompt != "" {
		// Use -p flag to pass the prompt directly
		parts = append(parts, "-p", fmt.Sprintf("%q", prompt))
	}

	cmd := strings.Join(parts, " ")
	if worktree != "" {
		cmd = fmt.Sprintf("cd %s && %s", worktree, cmd)
	}
	return cmd
}
