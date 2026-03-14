package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefault(t *testing.T) {
	cfg := Default()

	if cfg.General.PollInterval != 10 {
		t.Errorf("Default PollInterval = %d, want 10", cfg.General.PollInterval)
	}
	if cfg.General.StuckTimeout != 300 {
		t.Errorf("Default StuckTimeout = %d, want 300", cfg.General.StuckTimeout)
	}
	if cfg.General.DefaultProvider != "claude" {
		t.Errorf("Default DefaultProvider = %q, want %q", cfg.General.DefaultProvider, "claude")
	}
	if cfg.Queue.MaxConcurrent != 3 {
		t.Errorf("Default MaxConcurrent = %d, want 3", cfg.Queue.MaxConcurrent)
	}
	if cfg.Queue.Cooldown != 60 {
		t.Errorf("Default Cooldown = %d, want 60", cfg.Queue.Cooldown)
	}
	if len(cfg.Notifications.Channels) != 3 {
		t.Errorf("Default Channels len = %d, want 3", len(cfg.Notifications.Channels))
	}
}

func TestDefaultProviders(t *testing.T) {
	cfg := Default()

	for _, name := range []string{"claude", "codex", "ollama"} {
		p, ok := cfg.Providers[name]
		if !ok {
			t.Errorf("Provider %q not found in defaults", name)
			continue
		}
		if p.Command == "" {
			t.Errorf("Provider %q has empty command", name)
		}
		if len(p.DetectPatterns) == 0 {
			t.Errorf("Provider %q has no detect patterns", name)
		}
	}
}

func TestLoadMissingFile(t *testing.T) {
	// Loading a nonexistent config should succeed with defaults
	cfg, err := Load("/nonexistent/path/config.toml")
	if err != nil {
		t.Fatalf("Load of missing file failed: %v", err)
	}
	if cfg.General.PollInterval != 10 {
		t.Errorf("PollInterval = %d, want 10 (default)", cfg.General.PollInterval)
	}
}

func TestLoadValidTOML(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.toml")

	content := `
[general]
poll_interval = 30
stuck_timeout = 600
default_provider = "codex"

[queue]
max_concurrent = 5
cooldown = 120

[notifications]
channels = ["webhook"]
webhook_url = "https://example.com/hook"
`
	if err := os.WriteFile(cfgPath, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write config: %v", err)
	}

	cfg, err := Load(cfgPath)
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.General.PollInterval != 30 {
		t.Errorf("PollInterval = %d, want 30", cfg.General.PollInterval)
	}
	if cfg.General.StuckTimeout != 600 {
		t.Errorf("StuckTimeout = %d, want 600", cfg.General.StuckTimeout)
	}
	if cfg.General.DefaultProvider != "codex" {
		t.Errorf("DefaultProvider = %q, want %q", cfg.General.DefaultProvider, "codex")
	}
	if cfg.Queue.MaxConcurrent != 5 {
		t.Errorf("MaxConcurrent = %d, want 5", cfg.Queue.MaxConcurrent)
	}
	if cfg.Queue.Cooldown != 120 {
		t.Errorf("Cooldown = %d, want 120", cfg.Queue.Cooldown)
	}
	if cfg.Notifications.WebhookURL != "https://example.com/hook" {
		t.Errorf("WebhookURL = %q, want %q", cfg.Notifications.WebhookURL, "https://example.com/hook")
	}
}

func TestLoadInvalidTOML(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.toml")

	if err := os.WriteFile(cfgPath, []byte("this is not valid toml [[["), 0644); err != nil {
		t.Fatalf("Failed to write config: %v", err)
	}

	_, err := Load(cfgPath)
	if err == nil {
		t.Error("Expected error for invalid TOML, got nil")
	}
}

func TestEnvOverridePollInterval(t *testing.T) {
	t.Setenv("AIMUX_POLL_INTERVAL", "42")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if cfg.General.PollInterval != 42 {
		t.Errorf("PollInterval = %d, want 42 (env override)", cfg.General.PollInterval)
	}
}

func TestEnvOverrideStuckTimeout(t *testing.T) {
	t.Setenv("AIMUX_STUCK_TIMEOUT", "900")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if cfg.General.StuckTimeout != 900 {
		t.Errorf("StuckTimeout = %d, want 900 (env override)", cfg.General.StuckTimeout)
	}
}

func TestEnvOverrideDefaultProvider(t *testing.T) {
	t.Setenv("AIMUX_DEFAULT_PROVIDER", "ollama")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if cfg.General.DefaultProvider != "ollama" {
		t.Errorf("DefaultProvider = %q, want %q (env override)", cfg.General.DefaultProvider, "ollama")
	}
}

func TestEnvOverrideWebhookURL(t *testing.T) {
	t.Setenv("AIMUX_WEBHOOK_URL", "https://hooks.slack.com/test")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if cfg.Notifications.WebhookURL != "https://hooks.slack.com/test" {
		t.Errorf("WebhookURL = %q, want env override", cfg.Notifications.WebhookURL)
	}
}

func TestEnvOverrideQueueMaxConcurrent(t *testing.T) {
	t.Setenv("AIMUX_QUEUE_MAX_CONCURRENT", "8")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if cfg.Queue.MaxConcurrent != 8 {
		t.Errorf("MaxConcurrent = %d, want 8 (env override)", cfg.Queue.MaxConcurrent)
	}
}

func TestEnvOverrideInvalidNumber(t *testing.T) {
	t.Setenv("AIMUX_POLL_INTERVAL", "not-a-number")

	cfg, err := Load("/nonexistent/config.toml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	// Should keep default since env var is not a valid number
	if cfg.General.PollInterval != 10 {
		t.Errorf("PollInterval = %d, want 10 (invalid env should keep default)", cfg.General.PollInterval)
	}
}

func TestApplyDefaultsFillsZeroValues(t *testing.T) {
	cfg := &Config{}
	applyDefaults(cfg)

	if cfg.General.PollInterval != 10 {
		t.Errorf("applyDefaults PollInterval = %d, want 10", cfg.General.PollInterval)
	}
	if cfg.General.DefaultProvider != "claude" {
		t.Errorf("applyDefaults DefaultProvider = %q, want %q", cfg.General.DefaultProvider, "claude")
	}
	if cfg.Queue.MaxConcurrent != 3 {
		t.Errorf("applyDefaults MaxConcurrent = %d, want 3", cfg.Queue.MaxConcurrent)
	}
}

func TestAimuxHomeEnvVar(t *testing.T) {
	t.Setenv("AIMUX_HOME", "/custom/aimux/home")

	got := aimuxHome()
	if got != "/custom/aimux/home" {
		t.Errorf("aimuxHome() = %q, want %q", got, "/custom/aimux/home")
	}
}

func TestDefaultConfigPath(t *testing.T) {
	t.Setenv("AIMUX_HOME", "/test/home/.aimux")

	got := DefaultConfigPath()
	want := "/test/home/.aimux/config.toml"
	if got != want {
		t.Errorf("DefaultConfigPath() = %q, want %q", got, want)
	}
}
