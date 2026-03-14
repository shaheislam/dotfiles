// Package config handles TOML configuration for aimuxd.
//
// Config file location: ~/.aimux/config.toml
// Environment variables with the AIMUX_ prefix override config values.
// Default configuration is applied for any missing values.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
)

// Config is the top-level aimuxd configuration.
type Config struct {
	General       GeneralConfig             `toml:"general"`
	Notifications NotificationConfig        `toml:"notifications"`
	Queue         QueueConfig               `toml:"queue"`
	Providers     map[string]ProviderConfig `toml:"providers"`
}

// GeneralConfig holds daemon-wide settings.
type GeneralConfig struct {
	PollInterval    int    `toml:"poll_interval"`    // seconds between poll cycles (default 10)
	StuckTimeout    int    `toml:"stuck_timeout"`    // seconds of no output change before marking stuck (default 300)
	DefaultProvider string `toml:"default_provider"` // default provider name (default "claude")
	LogFile         string `toml:"log_file"`         // log file path (default ~/.aimux/aimuxd.log)
}

// NotificationConfig controls how completion notifications are delivered.
type NotificationConfig struct {
	Channels   []string `toml:"channels"`    // notification channels: "bell", "osc", "native", "webhook"
	WebhookURL string   `toml:"webhook_url"` // optional webhook URL for Slack/Discord
}

// QueueConfig controls ticket queue dispatch behavior.
type QueueConfig struct {
	MaxConcurrent int `toml:"max_concurrent"` // max concurrent dispatches (default 3)
	Cooldown      int `toml:"cooldown"`       // seconds between dispatches (default 60)
}

// ProviderConfig defines how to detect and launch an AI agent provider.
type ProviderConfig struct {
	Command        string   `toml:"command"`
	Args           []string `toml:"args"`
	DetectPatterns []string `toml:"detect_patterns"`
	WorkingPattern string   `toml:"working_pattern"`
	DonePatterns   []string `toml:"done_patterns"`
}

// aimuxHome returns the resolved AIMUX_HOME directory.
func aimuxHome() string {
	if h := os.Getenv("AIMUX_HOME"); h != "" {
		return h
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(".", ".aimux")
	}
	return filepath.Join(home, ".aimux")
}

// DefaultConfigPath returns the default config file path.
func DefaultConfigPath() string {
	return filepath.Join(aimuxHome(), "config.toml")
}

// Default returns a Config populated with sane defaults.
func Default() *Config {
	home := aimuxHome()
	return &Config{
		General: GeneralConfig{
			PollInterval:    10,
			StuckTimeout:    300,
			DefaultProvider: "claude",
			LogFile:         filepath.Join(home, "aimuxd.log"),
		},
		Notifications: NotificationConfig{
			Channels: []string{"bell", "osc", "native"},
		},
		Queue: QueueConfig{
			MaxConcurrent: 3,
			Cooldown:      60,
		},
		Providers: map[string]ProviderConfig{
			"claude": {
				Command:        "claude",
				Args:           []string{"--effort", "max"},
				DetectPatterns: []string{"claude"},
				WorkingPattern: `… \(`,
				DonePatterns:   []string{"COMPLETE", "_DONE", "TICKET_TASK_COMPLETE"},
			},
			"codex": {
				Command:        "codex",
				Args:           []string{"--full-auto"},
				DetectPatterns: []string{"codex"},
				WorkingPattern: "",
				DonePatterns:   []string{"COMPLETE"},
			},
			"ollama": {
				Command:        "ollama",
				Args:           []string{"run"},
				DetectPatterns: []string{"ollama"},
				WorkingPattern: "",
				DonePatterns:   []string{">>>"},
			},
		},
	}
}

// Load reads configuration from the given path (or default path if empty),
// applies defaults for missing values, then applies environment variable overrides.
func Load(path string) (*Config, error) {
	cfg := Default()

	if path == "" {
		path = DefaultConfigPath()
	}

	if _, err := os.Stat(path); err == nil {
		if _, err := toml.DecodeFile(path, cfg); err != nil {
			return nil, fmt.Errorf("parsing config %s: %w", path, err)
		}
	}
	// If the file does not exist, we proceed with defaults.

	applyEnvOverrides(cfg)
	applyDefaults(cfg)

	return cfg, nil
}

// applyDefaults fills in zero-value fields with defaults.
func applyDefaults(cfg *Config) {
	def := Default()
	if cfg.General.PollInterval <= 0 {
		cfg.General.PollInterval = def.General.PollInterval
	}
	if cfg.General.StuckTimeout <= 0 {
		cfg.General.StuckTimeout = def.General.StuckTimeout
	}
	if cfg.General.DefaultProvider == "" {
		cfg.General.DefaultProvider = def.General.DefaultProvider
	}
	if cfg.General.LogFile == "" {
		cfg.General.LogFile = def.General.LogFile
	}
	if len(cfg.Notifications.Channels) == 0 {
		cfg.Notifications.Channels = def.Notifications.Channels
	}
	if cfg.Queue.MaxConcurrent <= 0 {
		cfg.Queue.MaxConcurrent = def.Queue.MaxConcurrent
	}
	if cfg.Queue.Cooldown < 0 {
		cfg.Queue.Cooldown = def.Queue.Cooldown
	}
	if cfg.Providers == nil {
		cfg.Providers = def.Providers
	}
}

// applyEnvOverrides checks AIMUX_* environment variables and overrides config values.
func applyEnvOverrides(cfg *Config) {
	if v := os.Getenv("AIMUX_POLL_INTERVAL"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.General.PollInterval = n
		}
	}
	if v := os.Getenv("AIMUX_STUCK_TIMEOUT"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.General.StuckTimeout = n
		}
	}
	if v := os.Getenv("AIMUX_DEFAULT_PROVIDER"); v != "" {
		cfg.General.DefaultProvider = v
	}
	if v := os.Getenv("AIMUX_LOG_FILE"); v != "" {
		cfg.General.LogFile = v
	}
	if v := os.Getenv("AIMUX_NOTIFICATION_CHANNELS"); v != "" {
		cfg.Notifications.Channels = strings.Split(v, ",")
	}
	if v := os.Getenv("AIMUX_WEBHOOK_URL"); v != "" {
		cfg.Notifications.WebhookURL = v
	}
	if v := os.Getenv("AIMUX_QUEUE_MAX_CONCURRENT"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.Queue.MaxConcurrent = n
		}
	}
	if v := os.Getenv("AIMUX_QUEUE_COOLDOWN"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			cfg.Queue.Cooldown = n
		}
	}
}
