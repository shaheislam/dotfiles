package provider

import (
	"fmt"
	"strings"

	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/state"
)

// Generic implements the Provider interface for user-defined providers
// that do not have a specialized implementation.
type Generic struct {
	name string
	cfg  config.ProviderConfig
}

// NewGeneric creates a generic provider with the given name and config.
func NewGeneric(name string, cfg config.ProviderConfig) *Generic {
	return &Generic{name: name, cfg: cfg}
}

// Name returns the provider name.
func (g *Generic) Name() string { return g.name }

// DetectProcess returns true if the provider's process is found on the given TTY.
func (g *Generic) DetectProcess(tty string) bool {
	return detectProcessByPatterns(tty, g.cfg.DetectPatterns)
}

// DetectState analyzes pane content using the configured patterns.
func (g *Generic) DetectState(content string) state.AgentState {
	return detectStateFromContent(content, g.cfg.WorkingPattern, g.cfg.DonePatterns)
}

// LaunchCommand builds the shell command to launch the provider in a worktree.
func (g *Generic) LaunchCommand(worktree, prompt string) string {
	parts := []string{g.cfg.Command}
	parts = append(parts, g.cfg.Args...)

	if prompt != "" {
		parts = append(parts, fmt.Sprintf("%q", prompt))
	}

	cmd := strings.Join(parts, " ")
	if worktree != "" {
		cmd = fmt.Sprintf("cd %s && %s", worktree, cmd)
	}
	return cmd
}
