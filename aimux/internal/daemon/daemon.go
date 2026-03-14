// Package daemon implements the aimux monitoring daemon.
//
// The daemon polls tmux panes on a configurable interval, detects AI agent
// processes, tracks their state, colorizes tmux windows, sends notifications
// on completion, and optionally dispatches queued tickets.
package daemon

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/shaheislam/aimux/internal/config"
	"github.com/shaheislam/aimux/internal/provider"
	"github.com/shaheislam/aimux/internal/queue"
)

const (
	// DefaultPIDFile is the default location for the daemon PID file.
	DefaultPIDFile = "/tmp/aimuxd.pid"
)

// Daemon is the main aimuxd process. It owns the poll loop, signal handling,
// PID file management, and optional queue dispatcher.
type Daemon struct {
	poller       *Poller
	dispatcher   *queue.Dispatcher
	config       *config.Config
	pidFile      string
	pollInterval time.Duration
	logger       *log.Logger
	stopCh       chan struct{}
}

// New creates a new daemon instance from the given configuration.
func New(cfg *config.Config) (*Daemon, error) {
	// Set up logger
	logger, err := setupLogger(cfg.General.LogFile)
	if err != nil {
		return nil, fmt.Errorf("setting up logger: %w", err)
	}

	// Create provider registry
	registry := provider.NewRegistry(cfg.Providers)

	// Create notifier
	notifier := NewNotifier(cfg.Notifications.Channels, cfg.Notifications.WebhookURL)

	// Create poller
	stuckTimeout := time.Duration(cfg.General.StuckTimeout) * time.Second
	poller := NewPoller(registry, notifier, stuckTimeout, logger)

	// Create queue dispatcher
	q := queue.New("")
	if err := q.Load(); err != nil {
		logger.Printf("warning: failed to load queue, starting empty: %v", err)
	}
	cooldown := time.Duration(cfg.Queue.Cooldown) * time.Second
	dispatcher := queue.NewDispatcher(q, cfg.Queue.MaxConcurrent, cooldown, logger)

	return &Daemon{
		poller:       poller,
		dispatcher:   dispatcher,
		config:       cfg,
		pidFile:      DefaultPIDFile,
		pollInterval: time.Duration(cfg.General.PollInterval) * time.Second,
		logger:       logger,
		stopCh:       make(chan struct{}),
	}, nil
}

// Run starts the daemon main loop. It writes the PID file, sets up signal
// handlers, and polls on the configured interval until stopped.
func (d *Daemon) Run() error {
	if err := d.WritePIDFile(); err != nil {
		return fmt.Errorf("writing PID file: %w", err)
	}
	defer d.CleanupPIDFile()

	d.logger.Printf("aimuxd started (PID %d, poll every %s, stuck timeout %ds)",
		os.Getpid(), d.pollInterval, d.config.General.StuckTimeout)

	// Signal handling
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	// Start queue dispatcher in background
	go func() {
		if err := d.dispatcher.Run(); err != nil {
			d.logger.Printf("dispatcher error: %v", err)
		}
	}()

	ticker := time.NewTicker(d.pollInterval)
	defer ticker.Stop()

	// Do an initial poll immediately
	if err := d.poller.Poll(); err != nil {
		d.logger.Printf("poll error: %v", err)
	}

	for {
		select {
		case <-ticker.C:
			if err := d.poller.Poll(); err != nil {
				d.logger.Printf("poll error: %v", err)
			}
		case sig := <-sigCh:
			d.logger.Printf("received signal %v, shutting down", sig)
			d.Stop()
			return nil
		case <-d.stopCh:
			d.logger.Printf("daemon stopped")
			return nil
		}
	}
}

// RunOnce performs a single poll cycle and returns. Useful for testing
// and the --once CLI flag.
func (d *Daemon) RunOnce() error {
	d.logger.Printf("running single poll cycle")
	return d.poller.Poll()
}

// Stop signals the daemon to shut down gracefully.
func (d *Daemon) Stop() {
	d.dispatcher.Stop()
	select {
	case <-d.stopCh:
		// already closed
	default:
		close(d.stopCh)
	}
}

// WritePIDFile writes the current process PID to the PID file.
// It uses an exclusive file lock (flock) to prevent multiple daemon instances.
func (d *Daemon) WritePIDFile() error {
	// Check for stale PID file
	if data, err := os.ReadFile(d.pidFile); err == nil {
		if pid, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil {
			// Check if the process is still running
			if process, err := os.FindProcess(pid); err == nil {
				if err := process.Signal(syscall.Signal(0)); err == nil {
					return fmt.Errorf("daemon already running (PID %d)", pid)
				}
			}
		}
		// Stale PID file, remove it
		os.Remove(d.pidFile)
	}

	pid := os.Getpid()
	if err := os.WriteFile(d.pidFile, []byte(strconv.Itoa(pid)), 0o644); err != nil {
		return fmt.Errorf("writing PID file %s: %w", d.pidFile, err)
	}

	return nil
}

// CleanupPIDFile removes the PID file on shutdown.
func (d *Daemon) CleanupPIDFile() error {
	if err := os.Remove(d.pidFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing PID file: %w", err)
	}
	d.logger.Printf("PID file removed")
	return nil
}

// IsRunning checks if a daemon is already running by inspecting the PID file.
func IsRunning() (int, bool) {
	data, err := os.ReadFile(DefaultPIDFile)
	if err != nil {
		return 0, false
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil {
		return 0, false
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return 0, false
	}
	if err := process.Signal(syscall.Signal(0)); err != nil {
		return 0, false
	}
	return pid, true
}

// setupLogger creates a logger that writes to the given file path.
// It creates parent directories as needed.
func setupLogger(path string) (*log.Logger, error) {
	if path == "" || path == "-" || path == "/dev/stderr" {
		return log.New(os.Stderr, "aimuxd: ", log.LstdFlags), nil
	}

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("creating log directory %s: %w", dir, err)
	}

	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, fmt.Errorf("opening log file %s: %w", path, err)
	}

	return log.New(f, "aimuxd: ", log.LstdFlags), nil
}
