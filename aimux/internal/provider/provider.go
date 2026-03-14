// Package provider defines the agent provider interface and built-in providers.
//
// A provider knows how to detect its agent process on a TTY, analyze pane content
// to determine agent state, and build the launch command for autonomous execution.
package provider

import (
	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/state"
)

// Provider is the interface for AI agent providers.
type Provider interface {
	// Name returns the provider identifier (e.g., "claude", "codex", "ollama").
	Name() string
	// DetectProcess returns true if the agent process is found on the given TTY.
	DetectProcess(tty string) bool
	// DetectState analyzes pane content and returns the agent state.
	DetectState(content string) state.AgentState
	// LaunchCommand builds the shell command to launch the agent in a worktree.
	LaunchCommand(worktree, prompt string) string
}

// Registry holds known providers and supports lookup by name or TTY detection.
type Registry struct {
	providers map[string]Provider
	order     []string // preserves insertion order for deterministic iteration
}

// NewRegistry creates a registry populated from the config provider map.
// It instantiates the appropriate provider implementation for each config entry.
func NewRegistry(cfgProviders map[string]config.ProviderConfig) *Registry {
	r := &Registry{
		providers: make(map[string]Provider),
	}

	for name, cfg := range cfgProviders {
		var p Provider
		switch name {
		case "claude":
			p = NewClaude(cfg)
		case "codex":
			p = NewCodex(cfg)
		case "ollama":
			p = NewOllama(cfg)
		default:
			// Generic provider for user-defined entries
			p = NewGeneric(name, cfg)
		}
		r.providers[name] = p
		r.order = append(r.order, name)
	}

	return r
}

// Get returns the provider with the given name, or false if not found.
func (r *Registry) Get(name string) (Provider, bool) {
	p, ok := r.providers[name]
	return p, ok
}

// DetectAny scans all providers and returns the first one that detects a process
// on the given TTY. Returns nil and false if no provider matches.
func (r *Registry) DetectAny(tty string) (Provider, bool) {
	for _, name := range r.order {
		p := r.providers[name]
		if p.DetectProcess(tty) {
			return p, true
		}
	}
	return nil, false
}

// List returns the names of all registered providers.
func (r *Registry) List() []string {
	names := make([]string, len(r.order))
	copy(names, r.order)
	return names
}
