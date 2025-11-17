# Environment variables that need to be set early
# This file is loaded before other config files in conf.d

# Fix z plugin path truncation (override bad inherited environment variable)
# This MUST be set before z.fish loads in conf.d/
set -gx Z_DATA_DIR "$HOME/.local/share/z"
set -gx Z_DATA "$Z_DATA_DIR/data"

# Disable zoxide doctor warnings
set -x _ZO_DOCTOR 0