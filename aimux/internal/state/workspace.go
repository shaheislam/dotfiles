package state

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// WorkspaceState holds the persisted state of a single aimux workspace.
type WorkspaceState struct {
	Name         string     `json:"name"`
	Status       string     `json:"status"`       // active, running, done, stuck, failed
	Branch       string     `json:"branch"`
	Worktree     string     `json:"worktree"`
	Repo         string     `json:"repo"`
	Provider     string     `json:"provider"`
	Ticket       string     `json:"ticket"`
	Prompt       string     `json:"prompt"`
	CreatedAt    time.Time  `json:"created_at"`
	StartedAt    *time.Time `json:"started_at,omitempty"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
	AgentState   AgentState `json:"agent_state"`
	Attempts     int        `json:"attempts"`
	LastOutput   time.Time  `json:"last_output_change"`
	TmuxTarget   string     `json:"tmux_target,omitempty"`   // session:window.pane
	LastChecksum string     `json:"last_checksum,omitempty"` // hash of last captured output
}

// StateDir returns the directory where workspace state files are stored.
// Creates the directory if it does not exist.
func StateDir() string {
	home := os.Getenv("AIMUX_HOME")
	if home == "" {
		userHome, err := os.UserHomeDir()
		if err != nil {
			home = filepath.Join(".", ".aimux")
		} else {
			home = filepath.Join(userHome, ".aimux")
		}
	}
	dir := filepath.Join(home, "state")
	_ = os.MkdirAll(dir, 0o755)
	return dir
}

// statePath returns the file path for a workspace state file.
func statePath(name string) string {
	safe := sanitizeName(name)
	return filepath.Join(StateDir(), safe+".json")
}

// sanitizeName replaces characters that are unsafe for file names.
func sanitizeName(name string) string {
	replacer := strings.NewReplacer("/", "-", ":", "-", ".", "-", " ", "-")
	s := replacer.Replace(name)
	// Collapse multiple hyphens
	for strings.Contains(s, "--") {
		s = strings.ReplaceAll(s, "--", "-")
	}
	s = strings.Trim(s, "-")
	if s == "" {
		s = "unknown"
	}
	return s
}

// Read loads a workspace state from its JSON file.
// Returns nil and an error if the file does not exist or cannot be parsed.
func Read(name string) (*WorkspaceState, error) {
	path := statePath(name)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading workspace state %s: %w", name, err)
	}

	var ws WorkspaceState
	if err := json.Unmarshal(data, &ws); err != nil {
		return nil, fmt.Errorf("parsing workspace state %s: %w", name, err)
	}
	return &ws, nil
}

// Write atomically persists workspace state as JSON.
// It writes to a temporary file first, then renames to avoid partial writes.
func Write(ws *WorkspaceState) error {
	if ws.Name == "" {
		return fmt.Errorf("workspace state has no name")
	}

	data, err := json.MarshalIndent(ws, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling workspace state: %w", err)
	}
	data = append(data, '\n')

	target := statePath(ws.Name)
	dir := filepath.Dir(target)
	_ = os.MkdirAll(dir, 0o755)

	tmp, err := os.CreateTemp(dir, ".ws-*.json.tmp")
	if err != nil {
		return fmt.Errorf("creating temp file: %w", err)
	}
	tmpPath := tmp.Name()

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("writing temp file: %w", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("closing temp file: %w", err)
	}

	if err := os.Rename(tmpPath, target); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("renaming temp to state file: %w", err)
	}

	return nil
}

// Remove deletes the state file for a workspace.
func Remove(name string) error {
	path := statePath(name)
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing workspace state %s: %w", name, err)
	}
	return nil
}

// List returns all workspace states found in the state directory.
// Malformed state files are skipped with their errors logged to stderr.
func List() ([]*WorkspaceState, error) {
	dir := StateDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("reading state directory: %w", err)
	}

	var states []*WorkspaceState
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".json")
		ws, err := Read(name)
		if err != nil {
			fmt.Fprintf(os.Stderr, "aimuxd: skipping malformed state file %s: %v\n", entry.Name(), err)
			continue
		}
		states = append(states, ws)
	}

	return states, nil
}

// FindByTmuxTarget returns the workspace state matching a tmux target, or nil.
func FindByTmuxTarget(target string) *WorkspaceState {
	states, err := List()
	if err != nil {
		return nil
	}
	for _, ws := range states {
		if ws.TmuxTarget == target {
			return ws
		}
	}
	return nil
}
