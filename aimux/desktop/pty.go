package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"

	"github.com/creack/pty"
)

// PTYSession represents a single terminal session
type PTYSession struct {
	ID      string
	cmd     *exec.Cmd
	ptmx    *os.File
	mu      sync.Mutex
	done    chan struct{}
	onData  func([]byte) // callback when data arrives from PTY
	onClose func()       // callback when PTY closes
}

// PTYManager manages all PTY sessions
type PTYManager struct {
	sessions map[string]*PTYSession
	mu       sync.RWMutex
}

// NewPTYManager creates a new PTY manager
func NewPTYManager() *PTYManager {
	return &PTYManager{
		sessions: make(map[string]*PTYSession),
	}
}

// Create creates a new PTY session
func (m *PTYManager) Create(id, shell, workdir string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.sessions[id]; exists {
		return fmt.Errorf("session %s already exists", id)
	}

	cmd := exec.Command(shell)
	cmd.Dir = workdir
	cmd.Env = append(os.Environ(),
		"TERM=xterm-256color",
		"COLORTERM=truecolor",
		fmt.Sprintf("AIMUX_SESSION=%s", id),
	)

	ptmx, err := pty.Start(cmd)
	if err != nil {
		return fmt.Errorf("failed to start PTY: %w", err)
	}

	session := &PTYSession{
		ID:   id,
		cmd:  cmd,
		ptmx: ptmx,
		done: make(chan struct{}),
	}

	m.sessions[id] = session

	// Start reading from PTY in background
	go session.readLoop()

	return nil
}

// readLoop reads data from the PTY and sends it to the onData callback
func (s *PTYSession) readLoop() {
	defer close(s.done)

	buf := make([]byte, 32*1024)
	for {
		n, err := s.ptmx.Read(buf)
		if n > 0 {
			s.mu.Lock()
			if s.onData != nil {
				data := make([]byte, n)
				copy(data, buf[:n])
				s.onData(data)
			}
			s.mu.Unlock()
		}
		if err != nil {
			if err != io.EOF {
				fmt.Printf("PTY read error for %s: %v\n", s.ID, err)
			}
			break
		}
	}

	s.mu.Lock()
	if s.onClose != nil {
		s.onClose()
	}
	s.mu.Unlock()
}

// Write sends data to the PTY (user input)
func (m *PTYManager) Write(id string, data []byte) error {
	m.mu.RLock()
	session, exists := m.sessions[id]
	m.mu.RUnlock()

	if !exists {
		return fmt.Errorf("session %s not found", id)
	}

	_, err := session.ptmx.Write(data)
	return err
}

// Resize resizes a PTY
func (m *PTYManager) Resize(id string, cols, rows uint16) error {
	m.mu.RLock()
	session, exists := m.sessions[id]
	m.mu.RUnlock()

	if !exists {
		return fmt.Errorf("session %s not found", id)
	}

	return pty.Setsize(session.ptmx, &pty.Winsize{
		Rows: rows,
		Cols: cols,
	})
}

// SetCallbacks sets the data and close callbacks for a session
func (m *PTYManager) SetCallbacks(id string, onData func([]byte), onClose func()) error {
	m.mu.RLock()
	session, exists := m.sessions[id]
	m.mu.RUnlock()

	if !exists {
		return fmt.Errorf("session %s not found", id)
	}

	session.mu.Lock()
	session.onData = onData
	session.onClose = onClose
	session.mu.Unlock()

	return nil
}

// Close closes a PTY session
func (m *PTYManager) Close(id string) {
	m.mu.Lock()
	session, exists := m.sessions[id]
	if exists {
		delete(m.sessions, id)
	}
	m.mu.Unlock()

	if exists && session != nil {
		session.ptmx.Close()
		if session.cmd.Process != nil {
			session.cmd.Process.Kill()
		}
		<-session.done // wait for readLoop to finish
	}
}

// CloseAll closes all PTY sessions
func (m *PTYManager) CloseAll() {
	m.mu.Lock()
	ids := make([]string, 0, len(m.sessions))
	for id := range m.sessions {
		ids = append(ids, id)
	}
	m.mu.Unlock()

	for _, id := range ids {
		m.Close(id)
	}
}

// Get returns a session by ID
func (m *PTYManager) Get(id string) (*PTYSession, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s, ok := m.sessions[id]
	return s, ok
}
