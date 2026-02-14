# Environment variables that need to be set early
# This file is loaded before other config files in conf.d

# Fix z plugin path truncation (override bad inherited environment variable)
# This MUST be set before z.fish loads in conf.d/
set -gx Z_DATA_DIR "$HOME/.local/share/z"
set -gx Z_DATA "$Z_DATA_DIR/data"

# Disable zoxide doctor warnings
set -x _ZO_DOCTOR 0

# PERF: Prevent Homebrew's vendor_conf.d/mise.fish from running `mise activate fish | source`
# on every shell startup (~112ms). We use __cache_tool_init in config.fish instead.
set -gx MISE_FISH_AUTO_ACTIVATE 0
