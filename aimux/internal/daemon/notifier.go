package daemon

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"sync"
	"time"
)

// Notifier dispatches notifications through configured channels.
// It tracks which tmux targets have already been notified to avoid duplicates.
type Notifier struct {
	channels   []string
	webhookURL string

	mu       sync.Mutex
	notified map[string]bool
}

// NewNotifier creates a notifier with the given channels and optional webhook URL.
func NewNotifier(channels []string, webhookURL string) *Notifier {
	return &Notifier{
		channels:   channels,
		webhookURL: webhookURL,
		notified:   make(map[string]bool),
	}
}

// Notify sends a notification through all configured channels.
func (n *Notifier) Notify(title, message string) {
	for _, ch := range n.channels {
		switch ch {
		case "bell":
			n.notifyBell()
		case "osc":
			n.notifyOSC(message)
		case "native":
			n.notifyNative(title, message)
		case "webhook":
			n.notifyWebhook(title, message)
		}
	}
}

// ShouldNotify returns true if this target has not yet been notified.
func (n *Notifier) ShouldNotify(target string) bool {
	n.mu.Lock()
	defer n.mu.Unlock()
	return !n.notified[target]
}

// MarkNotified records that a notification has been sent for this target.
func (n *Notifier) MarkNotified(target string) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.notified[target] = true
}

// ClearNotified removes the notification record for a target,
// allowing future notifications for it.
func (n *Notifier) ClearNotified(target string) {
	n.mu.Lock()
	defer n.mu.Unlock()
	delete(n.notified, target)
}

// notifyBell writes the BEL character to stdout.
func (n *Notifier) notifyBell() {
	fmt.Print("\a")
}

// notifyOSC sends OSC 9 (iTerm2/WezTerm) and OSC 99 (kitty) escape sequences.
func (n *Notifier) notifyOSC(message string) {
	// OSC 9: iTerm2, WezTerm
	fmt.Fprintf(os.Stdout, "\033]9;%s\007", message)
	// OSC 99: kitty
	fmt.Fprintf(os.Stdout, "\033]99;i=aimux:d=0;%s\033\\", message)
}

// notifyNative sends a native OS notification.
func (n *Notifier) notifyNative(title, message string) {
	switch runtime.GOOS {
	case "darwin":
		n.notifyMacOS(title, message)
	case "linux":
		n.notifyLinux(title, message)
	}
}

// notifyMacOS uses terminal-notifier if available, falling back to osascript.
func (n *Notifier) notifyMacOS(title, message string) {
	if path, err := exec.LookPath("terminal-notifier"); err == nil {
		_ = exec.Command(path, "-title", title, "-message", message, "-group", "aimux").Run()
		return
	}
	script := fmt.Sprintf(`display notification %q with title %q`, message, title)
	_ = exec.Command("osascript", "-e", script).Run()
}

// notifyLinux uses notify-send if available.
func (n *Notifier) notifyLinux(title, message string) {
	if path, err := exec.LookPath("notify-send"); err == nil {
		_ = exec.Command(path, title, message).Run()
	}
}

// notifyWebhook posts a JSON payload to the configured webhook URL.
func (n *Notifier) notifyWebhook(title, message string) {
	if n.webhookURL == "" {
		return
	}

	payload := struct {
		Text string `json:"text"`
	}{
		Text: fmt.Sprintf("[%s] %s", title, message),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return
	}

	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest(http.MethodPost, n.webhookURL, bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return
	}
	resp.Body.Close()
}
