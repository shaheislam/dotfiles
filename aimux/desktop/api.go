package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"time"

	"github.com/shaheislam/aimux/internal/queue"
	"github.com/shaheislam/aimux/internal/state"
)

// --- Workspace API ---

// WorkspaceInfo is the JSON-serializable workspace data sent to the frontend.
type WorkspaceInfo struct {
	Name       string `json:"name"`
	Branch     string `json:"branch"`
	Status     string `json:"status"`
	Provider   string `json:"provider"`
	Ticket     string `json:"ticket"`
	Worktree   string `json:"worktree"`
	AgentState string `json:"agent_state"`
	CreatedAt  string `json:"created_at"`
	TerminalID string `json:"terminal_id"`
}

// GetWSPort returns the WebSocket server port for terminal connections.
func (a *App) GetWSPort() int {
	return a.wsPort
}

// ListWorkspaces returns all tracked workspaces.
func (a *App) ListWorkspaces() ([]WorkspaceInfo, error) {
	states, err := state.List()
	if err != nil {
		return nil, err
	}

	var workspaces []WorkspaceInfo
	for _, ws := range states {
		workspaces = append(workspaces, WorkspaceInfo{
			Name:       ws.Name,
			Branch:     ws.Branch,
			Status:     ws.Status,
			Provider:   ws.Provider,
			Ticket:     ws.Ticket,
			Worktree:   ws.Worktree,
			AgentState: string(ws.AgentState),
			CreatedAt:  ws.CreatedAt.Format(time.RFC3339),
		})
	}

	sort.Slice(workspaces, func(i, j int) bool {
		return workspaces[i].CreatedAt > workspaces[j].CreatedAt
	})

	return workspaces, nil
}

// CreateWorkspace creates a new workspace via aimux CLI.
func (a *App) CreateWorkspace(branch string, noDevcon bool) (WorkspaceInfo, error) {
	args := []string{"new", branch}
	if noDevcon {
		args = []string{"new", "--no-devcon", branch}
	}

	// Find aimux binary
	aimuxBin := a.findAimuxBin()
	cmd := exec.CommandContext(a.ctx, aimuxBin, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return WorkspaceInfo{}, fmt.Errorf("failed to create workspace: %s: %w", string(out), err)
	}

	// Read back the state
	ws, err := state.Read(branch)
	if err != nil {
		return WorkspaceInfo{
			Name:   branch,
			Branch: branch,
			Status: "active",
		}, nil
	}

	return WorkspaceInfo{
		Name:      ws.Name,
		Branch:    ws.Branch,
		Status:    ws.Status,
		Provider:  ws.Provider,
		Worktree:  ws.Worktree,
		CreatedAt: ws.CreatedAt.Format(time.RFC3339),
	}, nil
}

// KillWorkspace kills a workspace via aimux CLI.
func (a *App) KillWorkspace(name string, force bool) error {
	args := []string{"kill", name}
	if force {
		args = []string{"kill", "--force", name}
	}

	cmd := exec.CommandContext(a.ctx, a.findAimuxBin(), args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to kill workspace: %s: %w", string(out), err)
	}

	// Close any associated terminal
	a.ptyMgr.Close(name)

	return nil
}

// RunTicket executes a ticket via aimux CLI.
func (a *App) RunTicket(ticket, prompt, provider string) (WorkspaceInfo, error) {
	args := []string{"run", ticket}
	if prompt != "" {
		args = append(args, prompt)
	}
	if provider != "" {
		args = append(args, "--provider", provider)
	}

	cmd := exec.CommandContext(a.ctx, a.findAimuxBin(), args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return WorkspaceInfo{}, fmt.Errorf("failed to run ticket: %s: %w", string(out), err)
	}

	// Read back state
	ws, _ := state.Read(ticket)
	if ws != nil {
		return WorkspaceInfo{
			Name:     ws.Name,
			Branch:   ws.Branch,
			Status:   ws.Status,
			Provider: ws.Provider,
			Ticket:   ws.Ticket,
		}, nil
	}

	return WorkspaceInfo{Name: ticket, Ticket: ticket}, nil
}

// --- Terminal API ---

// CreateTerminal creates a new PTY terminal session.
func (a *App) CreateTerminal(id string, workdir string) (string, error) {
	if workdir == "" {
		var err error
		workdir, err = os.Getwd()
		if err != nil {
			workdir = os.Getenv("HOME")
		}
	}

	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}

	err := a.ptyMgr.Create(id, shell, workdir)
	if err != nil {
		return "", err
	}

	return id, nil
}

// ResizeTerminal resizes a PTY.
func (a *App) ResizeTerminal(id string, cols, rows uint16) error {
	return a.ptyMgr.Resize(id, cols, rows)
}

// CloseTerminal closes a PTY terminal session.
func (a *App) CloseTerminal(id string) error {
	a.ptyMgr.Close(id)
	return nil
}

// --- Queue API ---

// QueueEntry is the JSON-serializable queue entry sent to the frontend.
type QueueEntry struct {
	Ticket      string  `json:"ticket"`
	Prompt      string  `json:"prompt"`
	Provider    string  `json:"provider"`
	Priority    int     `json:"priority"`
	Status      string  `json:"status"`
	AddedAt     string  `json:"added_at"`
	StartedAt   *string `json:"started_at"`
	CompletedAt *string `json:"completed_at"`
}

// ListQueue returns all queue entries.
func (a *App) ListQueue() ([]QueueEntry, error) {
	home := os.Getenv("AIMUX_HOME")
	if home == "" {
		home = filepath.Join(os.Getenv("HOME"), ".aimux")
	}

	q := queue.New(filepath.Join(home, "queue.json"))
	if err := q.Load(); err != nil {
		return nil, err
	}

	var entries []QueueEntry
	for _, e := range q.List() {
		entry := QueueEntry{
			Ticket:   e.Ticket,
			Prompt:   e.Prompt,
			Provider: e.Provider,
			Priority: e.Priority,
			Status:   e.Status,
			AddedAt:  e.AddedAt.Format(time.RFC3339),
		}
		if e.StartedAt != nil {
			s := e.StartedAt.Format(time.RFC3339)
			entry.StartedAt = &s
		}
		if e.CompletedAt != nil {
			s := e.CompletedAt.Format(time.RFC3339)
			entry.CompletedAt = &s
		}
		entries = append(entries, entry)
	}

	return entries, nil
}

// AddToQueue adds a ticket to the queue.
func (a *App) AddToQueue(ticket, prompt, provider string, priority int) error {
	home := os.Getenv("AIMUX_HOME")
	if home == "" {
		home = filepath.Join(os.Getenv("HOME"), ".aimux")
	}

	q := queue.New(filepath.Join(home, "queue.json"))
	// OK if file doesn't exist yet
	_ = q.Load()

	return q.Add(queue.Entry{
		Ticket:   ticket,
		Prompt:   prompt,
		Provider: provider,
		Priority: priority,
		Status:   "queued",
		AddedAt:  time.Now(),
	})
}

// RemoveFromQueue removes a ticket from the queue.
func (a *App) RemoveFromQueue(ticket string) error {
	home := os.Getenv("AIMUX_HOME")
	if home == "" {
		home = filepath.Join(os.Getenv("HOME"), ".aimux")
	}

	q := queue.New(filepath.Join(home, "queue.json"))
	if err := q.Load(); err != nil {
		return err
	}

	return q.Remove(ticket)
}

// --- Helpers ---

func (a *App) findAimuxBin() string {
	// Check relative to desktop binary
	dir, _ := os.Executable()
	candidate := filepath.Join(filepath.Dir(dir), "..", "bin", "aimux")
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}

	// Check PATH
	if path, err := exec.LookPath("aimux"); err == nil {
		return path
	}

	return "aimux"
}
