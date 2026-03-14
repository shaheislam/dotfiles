package provider

import (
	"fmt"
	"strings"

	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/state"
)

// Ollama implements the Provider interface for Ollama local LLM.
type Ollama struct {
	cfg config.ProviderConfig
}

// NewOllama creates an Ollama provider from its config entry.
func NewOllama(cfg config.ProviderConfig) *Ollama {
	return &Ollama{cfg: cfg}
}

// Name returns "ollama".
func (o *Ollama) Name() string { return "ollama" }

// DetectProcess returns true if an Ollama process is found on the given TTY.
func (o *Ollama) DetectProcess(tty string) bool {
	return detectProcessByPatterns(tty, o.cfg.DetectPatterns)
}

// DetectState analyzes pane content for Ollama-specific patterns.
// Done: ">>>" prompt indicates Ollama is ready for input (idle/complete).
func (o *Ollama) DetectState(content string) state.AgentState {
	return detectStateFromContent(content, o.cfg.WorkingPattern, o.cfg.DonePatterns)
}

// LaunchCommand builds the shell command to launch Ollama in a worktree.
func (o *Ollama) LaunchCommand(worktree, prompt string) string {
	parts := []string{o.cfg.Command}
	parts = append(parts, o.cfg.Args...)

	if prompt != "" {
		parts = append(parts, fmt.Sprintf("%q", prompt))
	}

	cmd := strings.Join(parts, " ")
	if worktree != "" {
		cmd = fmt.Sprintf("cd %s && %s", worktree, cmd)
	}
	return cmd
}
