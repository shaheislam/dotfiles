package queue

import (
	"fmt"
	"log"
	"os/exec"
	"time"
)

// Dispatcher watches the queue and launches tickets when capacity is available.
// It runs in its own goroutine and checks for work on each cooldown interval.
type Dispatcher struct {
	queue         *Queue
	maxConcurrent int
	cooldown      time.Duration
	logger        *log.Logger
	stopCh        chan struct{}
}

// NewDispatcher creates a dispatcher for the given queue.
func NewDispatcher(q *Queue, maxConcurrent int, cooldown time.Duration, logger *log.Logger) *Dispatcher {
	return &Dispatcher{
		queue:         q,
		maxConcurrent: maxConcurrent,
		cooldown:      cooldown,
		logger:        logger,
		stopCh:        make(chan struct{}),
	}
}

// Run starts the dispatcher loop. It blocks until Stop is called.
func (d *Dispatcher) Run() error {
	ticker := time.NewTicker(d.cooldown)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			d.tick()
		case <-d.stopCh:
			return nil
		}
	}
}

// Stop signals the dispatcher to shut down.
func (d *Dispatcher) Stop() {
	select {
	case <-d.stopCh:
		// already closed
	default:
		close(d.stopCh)
	}
}

// tick performs one dispatch cycle: check capacity, dequeue, and launch.
func (d *Dispatcher) tick() {
	running := d.queue.CountByStatus("running") + d.queue.CountByStatus("dispatching")
	if running >= d.maxConcurrent {
		return
	}

	entry, ok := d.queue.Next()
	if !ok || entry == nil {
		return // nothing queued
	}

	d.logger.Printf("dispatcher: dequeuing ticket %s (provider: %s, priority: %d)",
		entry.Ticket, entry.Provider, entry.Priority)

	if err := d.dispatch(entry); err != nil {
		d.logger.Printf("dispatcher: failed to dispatch %s: %v", entry.Ticket, err)
		_ = d.queue.UpdateStatus(entry.Ticket, "failed")
	}
}

// dispatch launches an aimux run command for the given queue entry.
func (d *Dispatcher) dispatch(entry *Entry) error {
	if err := d.queue.UpdateStatus(entry.Ticket, "dispatching"); err != nil {
		return fmt.Errorf("updating status to dispatching: %w", err)
	}

	// Find the aimux binary to shell out to
	aimuxBin, err := findAimuxBinary()
	if err != nil {
		return fmt.Errorf("finding aimux binary: %w", err)
	}

	// Build arguments: aimux run <ticket> <prompt> --provider <provider>
	args := []string{"run", entry.Ticket}
	if entry.Prompt != "" {
		args = append(args, entry.Prompt)
	}
	if entry.Provider != "" {
		args = append(args, "--provider", entry.Provider)
	}

	cmd := exec.Command(aimuxBin, args...)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("starting aimux run: %w", err)
	}

	// Update status to running and let the process run detached
	if err := d.queue.UpdateStatus(entry.Ticket, "running"); err != nil {
		d.logger.Printf("dispatcher: warning: failed to update %s to running: %v", entry.Ticket, err)
	}

	d.logger.Printf("dispatcher: launched %s (PID %d)", entry.Ticket, cmd.Process.Pid)

	// Wait for completion in background goroutine
	go func() {
		if err := cmd.Wait(); err != nil {
			d.logger.Printf("dispatcher: ticket %s failed: %v", entry.Ticket, err)
			_ = d.queue.UpdateStatus(entry.Ticket, "failed")
		} else {
			d.logger.Printf("dispatcher: ticket %s completed", entry.Ticket)
			_ = d.queue.UpdateStatus(entry.Ticket, "completed")
		}
	}()

	return nil
}

// findAimuxBinary locates the aimux CLI binary.
func findAimuxBinary() (string, error) {
	// Check PATH first
	if path, err := exec.LookPath("aimux"); err == nil {
		return path, nil
	}

	// Common install locations
	candidates := []string{
		"/usr/local/bin/aimux",
		"/opt/homebrew/bin/aimux",
	}
	for _, c := range candidates {
		if _, err := exec.LookPath(c); err == nil {
			return c, nil
		}
	}

	return "", fmt.Errorf("aimux binary not found in PATH or standard locations")
}
