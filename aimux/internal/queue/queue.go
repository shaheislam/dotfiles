// Package queue implements the ticket execution queue for aimuxd.
//
// The queue is persisted as a JSON file at ~/.aimux/queue.json.
// All writes are atomic (write to temp file, then rename).
package queue

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// Entry represents a single ticket in the execution queue.
type Entry struct {
	Ticket      string     `json:"ticket"`
	Prompt      string     `json:"prompt"`
	Provider    string     `json:"provider"`
	Priority    int        `json:"priority"`
	Status      string     `json:"status"` // queued, dispatching, running, completed, failed
	AddedAt     time.Time  `json:"added_at"`
	StartedAt   *time.Time `json:"started_at,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	Error       string     `json:"error,omitempty"`
}

// Queue manages an ordered list of ticket entries with thread-safe operations.
type Queue struct {
	path    string
	entries []Entry
	mu      sync.Mutex
}

// New creates a queue that persists to the given path.
// If path is empty, the default ~/.aimux/queue.json is used.
// The queue starts empty; call Load to read existing entries from disk.
func New(path string) *Queue {
	if path == "" {
		path = defaultQueuePath()
	}
	return &Queue{
		path: path,
	}
}

// defaultQueuePath returns ~/.aimux/queue.json.
func defaultQueuePath() string {
	home := os.Getenv("AIMUX_HOME")
	if home == "" {
		userHome, err := os.UserHomeDir()
		if err != nil {
			home = filepath.Join(".", ".aimux")
		} else {
			home = filepath.Join(userHome, ".aimux")
		}
	}
	return filepath.Join(home, "queue.json")
}

// Load reads the queue from disk. If the file does not exist, the queue
// starts empty (this is not an error).
func (q *Queue) Load() error {
	q.mu.Lock()
	defer q.mu.Unlock()

	data, err := os.ReadFile(q.path)
	if err != nil {
		if os.IsNotExist(err) {
			q.entries = nil
			return nil
		}
		return fmt.Errorf("reading queue file %s: %w", q.path, err)
	}

	var entries []Entry
	if err := json.Unmarshal(data, &entries); err != nil {
		return fmt.Errorf("parsing queue file %s: %w", q.path, err)
	}

	q.entries = entries
	return nil
}

// Save atomically writes the queue to disk.
func (q *Queue) Save() error {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.saveLocked()
}

// saveLocked writes the queue while already holding the lock.
func (q *Queue) saveLocked() error {
	data, err := json.MarshalIndent(q.entries, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling queue: %w", err)
	}
	data = append(data, '\n')

	dir := filepath.Dir(q.path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("creating queue directory: %w", err)
	}

	tmp, err := os.CreateTemp(dir, ".queue-*.json.tmp")
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

	if err := os.Rename(tmpPath, q.path); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("renaming temp to queue file: %w", err)
	}

	return nil
}

// Add appends an entry to the queue and persists it.
// Default values are applied for empty Status and zero AddedAt.
func (q *Queue) Add(e Entry) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	if e.Status == "" {
		e.Status = "queued"
	}
	if e.AddedAt.IsZero() {
		e.AddedAt = time.Now()
	}

	q.entries = append(q.entries, e)
	return q.saveLocked()
}

// Remove deletes the entry with the given ticket identifier.
func (q *Queue) Remove(ticket string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	idx := -1
	for i, e := range q.entries {
		if e.Ticket == ticket {
			idx = i
			break
		}
	}
	if idx < 0 {
		return fmt.Errorf("ticket %q not found in queue", ticket)
	}

	q.entries = append(q.entries[:idx], q.entries[idx+1:]...)
	return q.saveLocked()
}

// List returns a copy of all queue entries, sorted by priority then add time.
// Lower priority number = higher priority (0 is highest).
func (q *Queue) List() []Entry {
	q.mu.Lock()
	defer q.mu.Unlock()

	result := make([]Entry, len(q.entries))
	copy(result, q.entries)

	sort.Slice(result, func(i, j int) bool {
		if result[i].Priority != result[j].Priority {
			return result[i].Priority < result[j].Priority
		}
		return result[i].AddedAt.Before(result[j].AddedAt)
	})

	return result
}

// Next returns the highest-priority queued entry and true, or nil and false
// if the queue is empty or all entries are in non-queued states.
func (q *Queue) Next() (*Entry, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()

	var best *Entry
	for i := range q.entries {
		e := &q.entries[i]
		if e.Status != "queued" {
			continue
		}
		if best == nil || e.Priority < best.Priority ||
			(e.Priority == best.Priority && e.AddedAt.Before(best.AddedAt)) {
			best = e
		}
	}

	if best == nil {
		return nil, false
	}

	// Return a copy
	entryCopy := *best
	return &entryCopy, true
}

// UpdateStatus changes the status of the entry matching the given ticket.
func (q *Queue) UpdateStatus(ticket, status string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	for i := range q.entries {
		if q.entries[i].Ticket == ticket {
			q.entries[i].Status = status
			now := time.Now()
			switch status {
			case "dispatching", "running":
				if q.entries[i].StartedAt == nil {
					q.entries[i].StartedAt = &now
				}
			case "completed", "failed":
				q.entries[i].CompletedAt = &now
			}
			return q.saveLocked()
		}
	}

	return fmt.Errorf("ticket %q not found in queue", ticket)
}

// CountByStatus returns the number of entries with the given status.
func (q *Queue) CountByStatus(status string) int {
	q.mu.Lock()
	defer q.mu.Unlock()

	count := 0
	for _, e := range q.entries {
		if e.Status == status {
			count++
		}
	}
	return count
}

// Clear removes all entries with the given statuses. If no statuses are
// provided, it clears "completed" and "failed" entries by default.
func (q *Queue) Clear(statuses ...string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	if len(statuses) == 0 {
		statuses = []string{"completed", "failed"}
	}

	statusSet := make(map[string]bool, len(statuses))
	for _, s := range statuses {
		statusSet[s] = true
	}

	filtered := make([]Entry, 0, len(q.entries))
	for _, e := range q.entries {
		if !statusSet[e.Status] {
			filtered = append(filtered, e)
		}
	}

	q.entries = filtered
	return q.saveLocked()
}
