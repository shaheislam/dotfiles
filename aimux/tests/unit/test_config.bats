#!/usr/bin/env bats
# Unit tests for lib/aimux/_config.sh

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
  export AIMUX_HOME="$AIMUX_TEST_DIR/.aimux"
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export AIMUX_LIB="$AIMUX_DIR/lib/aimux"

  # Create a minimal AIMUX_HOME for config loading
  mkdir -p "$AIMUX_HOME"

  # Source shared utils first, then config
  source "$AIMUX_LIB/_common.sh"

  # Unset env vars that might interfere with tests
  unset AIMUX_POLL_INTERVAL
  unset AIMUX_STUCK_TIMEOUT
  unset AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT
  unset AIMUX_QUEUE_COOLDOWN
  unset AIMUX_WEBHOOK_URL

  # Set default config path (AIMUX_CFG_DEFAULT points to default.toml in repo)
  export AIMUX_CFG_DEFAULT="$AIMUX_DIR/config/default.toml"
  export AIMUX_CFG_FILE="$AIMUX_HOME/config.toml"

  source "$AIMUX_LIB/_config.sh"
}

teardown() {
  rm -rf "$AIMUX_TEST_DIR"
}

# === cfg_load ===

@test "cfg_load reads default config" {
  cfg_load
  local val
  val="$(cfg_get "general.poll_interval")"
  [[ "$val" == "10" ]]
}

@test "cfg_load reads user config overriding defaults" {
  cat > "$AIMUX_CFG_FILE" <<'EOF'
[general]
poll_interval = 30
EOF
  # Unset exported vars from auto-load so they don't override the new config
  unset AIMUX_POLL_INTERVAL AIMUX_STUCK_TIMEOUT AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT AIMUX_QUEUE_COOLDOWN AIMUX_WEBHOOK_URL
  cfg_load
  local val
  val="$(cfg_get "general.poll_interval")"
  [[ "$val" == "30" ]]
}

# === cfg_get ===

@test "cfg_get returns value from config" {
  cfg_load
  local val
  val="$(cfg_get "general.default_provider")"
  [[ "$val" == "claude" ]]
}

@test "cfg_get returns default when key missing" {
  cfg_load
  local val
  val="$(cfg_get "nonexistent.key" "fallback")"
  [[ "$val" == "fallback" ]]
}

@test "cfg_get returns empty string when key missing and no default" {
  cfg_load
  local val
  val="$(cfg_get "nonexistent.key")"
  [[ -z "$val" ]]
}

# === Environment variable overrides ===

@test "env var overrides config value for poll_interval" {
  export AIMUX_POLL_INTERVAL=99
  cfg_load
  local val
  val="$(cfg_get "general.poll_interval")"
  [[ "$val" == "99" ]]
}

@test "env var overrides config value for default_provider" {
  export AIMUX_DEFAULT_PROVIDER=codex
  cfg_load
  local val
  val="$(cfg_get "general.default_provider")"
  [[ "$val" == "codex" ]]
}

@test "env var overrides config value for stuck_timeout" {
  export AIMUX_STUCK_TIMEOUT=600
  cfg_load
  local val
  val="$(cfg_get "general.stuck_timeout")"
  [[ "$val" == "600" ]]
}

# === Default values ===

@test "default config values are sane" {
  cfg_load
  local poll stuck provider max_conc cooldown
  poll="$(cfg_get "general.poll_interval")"
  stuck="$(cfg_get "general.stuck_timeout")"
  provider="$(cfg_get "general.default_provider")"
  max_conc="$(cfg_get "queue.max_concurrent")"
  cooldown="$(cfg_get "queue.cooldown")"

  [[ "$poll" == "10" ]]
  [[ "$stuck" == "300" ]]
  [[ "$provider" == "claude" ]]
  [[ "$max_conc" == "3" ]]
  [[ "$cooldown" == "60" ]]
}

# === cfg_set ===

@test "cfg_set updates internal config" {
  cfg_load
  cfg_set "general.poll_interval" "42"
  local val
  val="${_AIMUX_CFG[general.poll_interval]}"
  [[ "$val" == "42" ]]
}

# === TOML parsing ===

@test "TOML parser handles quoted strings" {
  cat > "$AIMUX_CFG_FILE" <<'EOF'
[notifications]
webhook_url = "https://example.com/hook"
EOF
  unset AIMUX_POLL_INTERVAL AIMUX_STUCK_TIMEOUT AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT AIMUX_QUEUE_COOLDOWN AIMUX_WEBHOOK_URL
  cfg_load
  local val
  val="$(cfg_get "notifications.webhook_url")"
  [[ "$val" == "https://example.com/hook" ]]
}

@test "TOML parser handles single-quoted strings" {
  cat > "$AIMUX_CFG_FILE" <<'EOF'
[general]
default_provider = 'ollama'
EOF
  unset AIMUX_POLL_INTERVAL AIMUX_STUCK_TIMEOUT AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT AIMUX_QUEUE_COOLDOWN AIMUX_WEBHOOK_URL
  cfg_load
  local val
  val="$(cfg_get "general.default_provider")"
  [[ "$val" == "ollama" ]]
}

@test "TOML parser ignores comments" {
  cat > "$AIMUX_CFG_FILE" <<'EOF'
# This is a comment
[general]
poll_interval = 15 # inline comment
EOF
  unset AIMUX_POLL_INTERVAL AIMUX_STUCK_TIMEOUT AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT AIMUX_QUEUE_COOLDOWN AIMUX_WEBHOOK_URL
  cfg_load
  local val
  val="$(cfg_get "general.poll_interval")"
  [[ "$val" == "15" ]]
}

@test "TOML parser handles nested sections" {
  cat > "$AIMUX_CFG_FILE" <<'EOF'
[providers.claude]
command = "my-claude"
EOF
  unset AIMUX_POLL_INTERVAL AIMUX_STUCK_TIMEOUT AIMUX_DEFAULT_PROVIDER
  unset AIMUX_QUEUE_MAX_CONCURRENT AIMUX_QUEUE_COOLDOWN AIMUX_WEBHOOK_URL
  cfg_load
  local val
  val="$(cfg_get "providers.claude.command")"
  [[ "$val" == "my-claude" ]]
}

# === _cfg_export ===

@test "cfg_load exports well-known env vars" {
  cfg_load
  [[ "$AIMUX_POLL_INTERVAL" == "10" ]]
  [[ "$AIMUX_STUCK_TIMEOUT" == "300" ]]
  [[ "$AIMUX_DEFAULT_PROVIDER" == "claude" ]]
  [[ "$AIMUX_QUEUE_MAX_CONCURRENT" == "3" ]]
  [[ "$AIMUX_QUEUE_COOLDOWN" == "60" ]]
}
