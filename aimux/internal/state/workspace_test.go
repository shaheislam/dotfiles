package state

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func setupTestStateDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("AIMUX_HOME", dir)
	return dir
}

func newTestWorkspace(name string) *WorkspaceState {
	now := time.Now()
	return &WorkspaceState{
		Name:       name,
		Status:     "active",
		Branch:     name,
		Worktree:   "/tmp/repo-" + name,
		Repo:       "/tmp/repo",
		Provider:   "claude",
		Ticket:     "TEST-001",
		Prompt:     "Fix the bug",
		CreatedAt:  now,
		AgentState: AgentIdle,
		LastOutput: now,
	}
}

func TestWriteAndRead(t *testing.T) {
	setupTestStateDir(t)

	ws := newTestWorkspace("test-write-read")
	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	got, err := Read("test-write-read")
	if err != nil {
		t.Fatalf("Read failed: %v", err)
	}

	if got.Name != ws.Name {
		t.Errorf("Name = %q, want %q", got.Name, ws.Name)
	}
	if got.Branch != ws.Branch {
		t.Errorf("Branch = %q, want %q", got.Branch, ws.Branch)
	}
	if got.Provider != ws.Provider {
		t.Errorf("Provider = %q, want %q", got.Provider, ws.Provider)
	}
	if got.Ticket != ws.Ticket {
		t.Errorf("Ticket = %q, want %q", got.Ticket, ws.Ticket)
	}
	if got.AgentState != ws.AgentState {
		t.Errorf("AgentState = %q, want %q", got.AgentState, ws.AgentState)
	}
}

func TestWriteEmptyNameFails(t *testing.T) {
	setupTestStateDir(t)

	ws := &WorkspaceState{}
	err := Write(ws)
	if err == nil {
		t.Error("Write with empty name should fail")
	}
}

func TestWriteIsAtomic(t *testing.T) {
	dir := setupTestStateDir(t)

	ws := newTestWorkspace("atomic-test")
	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Verify the file exists at the expected path
	stateDir := filepath.Join(dir, "state")
	entries, err := os.ReadDir(stateDir)
	if err != nil {
		t.Fatalf("ReadDir failed: %v", err)
	}

	found := false
	for _, e := range entries {
		if e.Name() == "atomic-test.json" {
			found = true
		}
		// No temp files should remain
		if filepath.Ext(e.Name()) == ".tmp" {
			t.Errorf("Temp file left behind: %s", e.Name())
		}
	}
	if !found {
		t.Error("State file not found after write")
	}
}

func TestReadNonexistent(t *testing.T) {
	setupTestStateDir(t)

	_, err := Read("does-not-exist")
	if err == nil {
		t.Error("Read of nonexistent workspace should return error")
	}
}

func TestRemove(t *testing.T) {
	setupTestStateDir(t)

	ws := newTestWorkspace("remove-test")
	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Verify it exists
	if _, err := Read("remove-test"); err != nil {
		t.Fatalf("Read after write failed: %v", err)
	}

	// Remove it
	if err := Remove("remove-test"); err != nil {
		t.Fatalf("Remove failed: %v", err)
	}

	// Verify it is gone
	if _, err := Read("remove-test"); err == nil {
		t.Error("Read after remove should fail")
	}
}

func TestRemoveNonexistent(t *testing.T) {
	setupTestStateDir(t)

	err := Remove("nonexistent-workspace")
	if err != nil {
		t.Errorf("Remove of nonexistent workspace should not error, got: %v", err)
	}
}

func TestList(t *testing.T) {
	setupTestStateDir(t)

	// Write multiple workspaces
	for _, name := range []string{"ws-alpha", "ws-beta", "ws-gamma"} {
		ws := newTestWorkspace(name)
		if err := Write(ws); err != nil {
			t.Fatalf("Write %q failed: %v", name, err)
		}
	}

	states, err := List()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	if len(states) != 3 {
		t.Errorf("List returned %d workspaces, want 3", len(states))
	}

	names := map[string]bool{}
	for _, s := range states {
		names[s.Name] = true
	}
	for _, expected := range []string{"ws-alpha", "ws-beta", "ws-gamma"} {
		if !names[expected] {
			t.Errorf("List missing workspace %q", expected)
		}
	}
}

func TestListEmpty(t *testing.T) {
	setupTestStateDir(t)

	states, err := List()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	if len(states) != 0 {
		t.Errorf("List of empty state dir returned %d entries, want 0", len(states))
	}
}

func TestListSkipsMalformedFiles(t *testing.T) {
	dir := setupTestStateDir(t)

	// Write a valid workspace
	ws := newTestWorkspace("valid")
	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Write a malformed JSON file
	stateDir := filepath.Join(dir, "state")
	malformed := filepath.Join(stateDir, "bad.json")
	if err := os.WriteFile(malformed, []byte("{not valid json}"), 0644); err != nil {
		t.Fatalf("WriteFile failed: %v", err)
	}

	states, err := List()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	// Should only return the valid workspace
	if len(states) != 1 {
		t.Errorf("List returned %d entries, want 1 (should skip malformed)", len(states))
	}
}

func TestSanitizeName(t *testing.T) {
	tests := []struct {
		input, want string
	}{
		{"simple", "simple"},
		{"feat/my-branch", "feat-my-branch"},
		{"has:colons", "has-colons"},
		{"has.dots", "has-dots"},
		{"has spaces", "has-spaces"},
		{"multi--dashes", "multi-dashes"},
		{"-leading-trailing-", "leading-trailing"},
		{"", "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			if got := sanitizeName(tt.input); got != tt.want {
				t.Errorf("sanitizeName(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestFindByTmuxTarget(t *testing.T) {
	setupTestStateDir(t)

	ws := newTestWorkspace("tmux-find-test")
	ws.TmuxTarget = "main:2.0"
	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	found := FindByTmuxTarget("main:2.0")
	if found == nil {
		t.Fatal("FindByTmuxTarget returned nil")
	}
	if found.Name != "tmux-find-test" {
		t.Errorf("Found name = %q, want %q", found.Name, "tmux-find-test")
	}

	notFound := FindByTmuxTarget("nonexistent:99.0")
	if notFound != nil {
		t.Error("FindByTmuxTarget should return nil for nonexistent target")
	}
}

func TestWritePreservesOptionalFields(t *testing.T) {
	setupTestStateDir(t)

	now := time.Now()
	ws := newTestWorkspace("optional-fields")
	ws.StartedAt = &now
	ws.CompletedAt = &now
	ws.Attempts = 5
	ws.LastChecksum = "abc123"
	ws.TmuxTarget = "test:1.0"

	if err := Write(ws); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	got, err := Read("optional-fields")
	if err != nil {
		t.Fatalf("Read failed: %v", err)
	}

	if got.StartedAt == nil {
		t.Error("StartedAt should not be nil")
	}
	if got.CompletedAt == nil {
		t.Error("CompletedAt should not be nil")
	}
	if got.Attempts != 5 {
		t.Errorf("Attempts = %d, want 5", got.Attempts)
	}
	if got.LastChecksum != "abc123" {
		t.Errorf("LastChecksum = %q, want %q", got.LastChecksum, "abc123")
	}
	if got.TmuxTarget != "test:1.0" {
		t.Errorf("TmuxTarget = %q, want %q", got.TmuxTarget, "test:1.0")
	}
}
