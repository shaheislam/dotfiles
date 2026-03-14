package provider

import (
	"fmt"
	"strings"

	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/state"
)

// Codex implements the Provider interface for Codex CLI.
type Codex struct {
	cfg config.ProviderConfig
}

// NewCodex creates a Codex provider from its config entry.
func NewCodex(cfg config.ProviderConfig) *Codex {
	return &Codex{cfg: cfg}
}

// Name returns "codex".
func (c *Codex) Name() string { return "codex" }

// DetectProcess returns true if a Codex CLI process is found on the given TTY.
func (c *Codex) DetectProcess(tty string) bool {
	return detectProcessByPatterns(tty, c.cfg.DetectPatterns)
}

// DetectState analyzes pane content for Codex-specific patterns.
func (c *Codex) DetectState(content string) state.AgentState {
	return detectStateFromContent(content, c.cfg.WorkingPattern, c.cfg.DonePatterns)
}

// LaunchCommand builds the shell command to launch Codex CLI in a worktree.
func (c *Codex) LaunchCommand(worktree, prompt string) string {
	parts := []string{c.cfg.Command}
	parts = append(parts, c.cfg.Args...)

	if prompt != "" {
		parts = append(parts, fmt.Sprintf("%q", prompt))
	}

	cmd := strings.Join(parts, " ")
	if worktree != "" {
		cmd = fmt.Sprintf("cd %s && %s", worktree, cmd)
	}
	return cmd
}
