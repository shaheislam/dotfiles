package queue

import (
	"os"
	"path/filepath"
	"testing"
)

func setupTestQueue(t *testing.T) (*Queue, string) {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("AIMUX_HOME", dir)
	queueFile := filepath.Join(dir, "queue.json")
	q := New(queueFile)
	return q, queueFile
}

func addEntry(t *testing.T, q *Queue, ticket, prompt string, priority int) {
	t.Helper()
	err := q.Add(Entry{
		Ticket:   ticket,
		Prompt:   prompt,
		Priority: priority,
	})
	if err != nil {
		t.Fatalf("Add(%q) failed: %v", ticket, err)
	}
}

func TestNewQueue(t *testing.T) {
	q, _ := setupTestQueue(t)
	if q == nil {
		t.Fatal("New returned nil")
	}
}

func TestAddAndList(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "TEST-001", "Fix the login bug", 5)

	items := q.List()
	if len(items) != 1 {
		t.Fatalf("List returned %d items, want 1", len(items))
	}
	if items[0].Ticket != "TEST-001" {
		t.Errorf("Ticket = %q, want %q", items[0].Ticket, "TEST-001")
	}
	if items[0].Prompt != "Fix the login bug" {
		t.Errorf("Prompt = %q, want %q", items[0].Prompt, "Fix the login bug")
	}
	if items[0].Priority != 5 {
		t.Errorf("Priority = %d, want 5", items[0].Priority)
	}
	if items[0].Status != "queued" {
		t.Errorf("Status = %q, want %q (default)", items[0].Status, "queued")
	}
}

func TestAddMultipleEntries(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "A", "First", 10)
	addEntry(t, q, "B", "Second", 5)
	addEntry(t, q, "C", "Third", 0)

	items := q.List()
	if len(items) != 3 {
		t.Fatalf("List returned %d items, want 3", len(items))
	}
}

func TestNextReturnsByPriority(t *testing.T) {
	q, _ := setupTestQueue(t)

	// Priority 0 = highest, 10 = lowest
	addEntry(t, q, "LOW", "Low priority task", 10)
	addEntry(t, q, "HIGH", "High priority task", 0)
	addEntry(t, q, "NORMAL", "Normal priority task", 5)

	next, ok := q.Next()
	if !ok {
		t.Fatal("Next returned false")
	}
	if next == nil {
		t.Fatal("Next returned nil entry")
	}
	if next.Ticket != "HIGH" {
		t.Errorf("Next.Ticket = %q, want %q (priority 0 = highest)", next.Ticket, "HIGH")
	}
}

func TestNextFromEmptyQueue(t *testing.T) {
	q, _ := setupTestQueue(t)

	next, ok := q.Next()
	if ok {
		t.Error("Next from empty queue should return false")
	}
	if next != nil {
		t.Error("Next from empty queue should return nil")
	}
}

func TestNextOnlyReturnsQueued(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "RUNNING", "Already dispatched", 0)
	_ = q.UpdateStatus("RUNNING", "running")

	next, ok := q.Next()
	if ok {
		t.Errorf("Next should return false when no queued items exist, got ticket %q", next.Ticket)
	}
}

func TestRemove(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "REMOVE-ME", "To be removed", 5)
	if len(q.List()) != 1 {
		t.Fatalf("Expected 1 item before remove")
	}

	err := q.Remove("REMOVE-ME")
	if err != nil {
		t.Fatalf("Remove failed: %v", err)
	}

	if len(q.List()) != 0 {
		t.Error("Queue should be empty after remove")
	}
}

func TestRemoveNonexistent(t *testing.T) {
	q, _ := setupTestQueue(t)

	err := q.Remove("DOES-NOT-EXIST")
	if err == nil {
		t.Error("Remove of nonexistent item should return error")
	}
}

func TestPersistence(t *testing.T) {
	q1, queueFile := setupTestQueue(t)

	addEntry(t, q1, "PERSIST-1", "First", 5)
	addEntry(t, q1, "PERSIST-2", "Second", 0)

	// Reload from same file
	q2 := New(queueFile)
	if err := q2.Load(); err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	items := q2.List()
	if len(items) != 2 {
		t.Errorf("Reloaded queue has %d items, want 2", len(items))
	}
}

func TestSaveCreatesFile(t *testing.T) {
	_, queueFile := setupTestQueue(t)

	// Add an entry to trigger save
	q := New(queueFile)
	addEntry(t, q, "SAVE-TEST", "test", 5)

	if _, err := os.Stat(queueFile); os.IsNotExist(err) {
		t.Error("Add should persist queue file to disk")
	}
}

func TestPriorityOrdering(t *testing.T) {
	q, _ := setupTestQueue(t)

	// 0 = highest, 10 = lowest
	addEntry(t, q, "T1", "task 1", 10)
	addEntry(t, q, "T2", "task 2", 0)
	addEntry(t, q, "T3", "task 3", 5)
	addEntry(t, q, "T4", "task 4", 0)

	// List should be sorted by priority (lowest number first), then by add time
	items := q.List()
	if len(items) < 2 {
		t.Fatalf("List returned %d items, want at least 2", len(items))
	}
	if items[0].Priority > items[1].Priority {
		t.Errorf("List not sorted: items[0].Priority=%d > items[1].Priority=%d",
			items[0].Priority, items[1].Priority)
	}
}

func TestUpdateStatus(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "STATUS-TEST", "test", 5)

	if err := q.UpdateStatus("STATUS-TEST", "running"); err != nil {
		t.Fatalf("UpdateStatus failed: %v", err)
	}

	items := q.List()
	if items[0].Status != "running" {
		t.Errorf("Status = %q, want %q", items[0].Status, "running")
	}
	if items[0].StartedAt == nil {
		t.Error("StartedAt should be set when status changes to running")
	}
}

func TestUpdateStatusCompleted(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "COMPLETE-TEST", "test", 5)
	_ = q.UpdateStatus("COMPLETE-TEST", "running")
	_ = q.UpdateStatus("COMPLETE-TEST", "completed")

	items := q.List()
	if items[0].Status != "completed" {
		t.Errorf("Status = %q, want %q", items[0].Status, "completed")
	}
	if items[0].CompletedAt == nil {
		t.Error("CompletedAt should be set when status changes to completed")
	}
}

func TestUpdateStatusNonexistent(t *testing.T) {
	q, _ := setupTestQueue(t)

	err := q.UpdateStatus("GHOST", "running")
	if err == nil {
		t.Error("UpdateStatus on nonexistent ticket should return error")
	}
}

func TestCountByStatus(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "A", "a", 5)
	addEntry(t, q, "B", "b", 5)
	addEntry(t, q, "C", "c", 5)

	if q.CountByStatus("queued") != 3 {
		t.Errorf("CountByStatus(queued) = %d, want 3", q.CountByStatus("queued"))
	}

	_ = q.UpdateStatus("A", "running")
	if q.CountByStatus("running") != 1 {
		t.Errorf("CountByStatus(running) = %d, want 1", q.CountByStatus("running"))
	}
	if q.CountByStatus("queued") != 2 {
		t.Errorf("CountByStatus(queued) = %d, want 2", q.CountByStatus("queued"))
	}
}

func TestClear(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "A", "a", 5)
	addEntry(t, q, "B", "b", 5)
	addEntry(t, q, "C", "c", 5)

	_ = q.UpdateStatus("A", "completed")
	_ = q.UpdateStatus("B", "failed")

	if err := q.Clear(); err != nil {
		t.Fatalf("Clear failed: %v", err)
	}

	items := q.List()
	if len(items) != 1 {
		t.Errorf("After clear, List has %d items, want 1 (only queued)", len(items))
	}
	if items[0].Ticket != "C" {
		t.Errorf("Remaining ticket = %q, want %q", items[0].Ticket, "C")
	}
}

func TestClearWithCustomStatuses(t *testing.T) {
	q, _ := setupTestQueue(t)

	addEntry(t, q, "A", "a", 5)
	addEntry(t, q, "B", "b", 5)

	_ = q.UpdateStatus("A", "running")

	if err := q.Clear("running"); err != nil {
		t.Fatalf("Clear failed: %v", err)
	}

	items := q.List()
	if len(items) != 1 {
		t.Errorf("After Clear(running), List has %d items, want 1", len(items))
	}
}

func TestLoadNonexistentFile(t *testing.T) {
	dir := t.TempDir()
	queueFile := filepath.Join(dir, "nonexistent.json")

	q := New(queueFile)
	if err := q.Load(); err != nil {
		t.Errorf("Load of nonexistent file should not error: %v", err)
	}

	items := q.List()
	if len(items) != 0 {
		t.Errorf("Queue loaded from nonexistent file has %d items, want 0", len(items))
	}
}

func TestAddSetsDefaultStatus(t *testing.T) {
	q, _ := setupTestQueue(t)

	// Add with empty status to verify it defaults to "queued"
	err := q.Add(Entry{
		Ticket:   "DEFAULT-STATUS",
		Prompt:   "test",
		Priority: 5,
	})
	if err != nil {
		t.Fatalf("Add failed: %v", err)
	}

	items := q.List()
	if items[0].Status != "queued" {
		t.Errorf("Default status = %q, want %q", items[0].Status, "queued")
	}
}

func TestAddSetsDefaultAddedAt(t *testing.T) {
	q, _ := setupTestQueue(t)

	err := q.Add(Entry{
		Ticket:   "TIME-TEST",
		Prompt:   "test",
		Priority: 5,
	})
	if err != nil {
		t.Fatalf("Add failed: %v", err)
	}

	items := q.List()
	if items[0].AddedAt.IsZero() {
		t.Error("AddedAt should be set automatically")
	}
}
