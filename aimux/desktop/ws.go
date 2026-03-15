package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow Wails webview to connect
	},
}

// WSMessage represents a message between frontend and backend
type WSMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

// WSResizeData represents terminal resize data
type WSResizeData struct {
	Cols uint16 `json:"cols"`
	Rows uint16 `json:"rows"`
}

// WSHub manages WebSocket connections for terminal I/O
type WSHub struct {
	ptyMgr *PTYManager
	conns  map[string]*websocket.Conn
	mu     sync.RWMutex
}

// NewWSHub creates a new WebSocket hub
func NewWSHub(ptyMgr *PTYManager) *WSHub {
	return &WSHub{
		ptyMgr: ptyMgr,
		conns:  make(map[string]*websocket.Conn),
	}
}

// HandleTerminal handles WebSocket connections for terminal sessions
// URL format: /ws/terminal/{session_id}
func (h *WSHub) HandleTerminal(w http.ResponseWriter, r *http.Request) {
	// Extract session ID from URL
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 4 {
		http.Error(w, "invalid path", http.StatusBadRequest)
		return
	}
	sessionID := parts[len(parts)-1]

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Printf("WebSocket upgrade error: %v\n", err)
		return
	}

	h.mu.Lock()
	h.conns[sessionID] = conn
	h.mu.Unlock()

	// Set up PTY -> WebSocket streaming
	h.ptyMgr.SetCallbacks(sessionID, func(data []byte) {
		h.mu.RLock()
		c, ok := h.conns[sessionID]
		h.mu.RUnlock()
		if ok {
			c.WriteMessage(websocket.BinaryMessage, data)
		}
	}, func() {
		// PTY closed
		h.mu.Lock()
		delete(h.conns, sessionID)
		h.mu.Unlock()
		conn.Close()
	})

	// Read from WebSocket -> PTY (user input)
	for {
		msgType, data, err := conn.ReadMessage()
		if err != nil {
			break
		}

		if msgType == websocket.TextMessage {
			// Could be a control message (resize, etc.)
			var msg WSMessage
			if json.Unmarshal(data, &msg) == nil {
				switch msg.Type {
				case "resize":
					var resize WSResizeData
					if json.Unmarshal(msg.Data, &resize) == nil {
						h.ptyMgr.Resize(sessionID, resize.Cols, resize.Rows)
					}
				case "input":
					var input string
					if json.Unmarshal(msg.Data, &input) == nil {
						h.ptyMgr.Write(sessionID, []byte(input))
					}
				}
			}
		} else if msgType == websocket.BinaryMessage {
			// Direct binary input to PTY
			h.ptyMgr.Write(sessionID, data)
		}
	}

	// Cleanup
	h.mu.Lock()
	delete(h.conns, sessionID)
	h.mu.Unlock()
	conn.Close()
}
