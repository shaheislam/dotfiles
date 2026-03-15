package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"sync"

	"github.com/shaheislam/aimux/internal/config"
)

// App struct holds the application state
type App struct {
	ctx        context.Context
	cfg        *config.Config
	ptyMgr     *PTYManager
	wsHub      *WSHub
	httpServer *http.Server
	wsPort     int
	mu         sync.RWMutex
}

// NewApp creates a new App instance
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	// Load config
	cfg, err := config.Load("")
	if err != nil {
		cfg = config.Default()
	}
	a.cfg = cfg

	// Initialize PTY manager
	a.ptyMgr = NewPTYManager()

	// Initialize WebSocket hub
	a.wsHub = NewWSHub(a.ptyMgr)

	// Start WebSocket server on random port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Printf("Failed to start WebSocket server: %v\n", err)
		return
	}
	a.wsPort = listener.Addr().(*net.TCPAddr).Port

	mux := http.NewServeMux()
	mux.HandleFunc("/ws/terminal/", a.wsHub.HandleTerminal)

	a.httpServer = &http.Server{Handler: mux}
	go a.httpServer.Serve(listener)

	fmt.Printf("WebSocket server started on port %d\n", a.wsPort)
}

// shutdown is called when the app is closing
func (a *App) shutdown(ctx context.Context) {
	if a.ptyMgr != nil {
		a.ptyMgr.CloseAll()
	}
	if a.httpServer != nil {
		a.httpServer.Close()
	}
}
