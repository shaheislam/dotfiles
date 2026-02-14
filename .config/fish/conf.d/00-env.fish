# Environment variables that need to be set early
# This file is loaded before other config files in conf.d

# PERF: z plugin's PWD hook (__z_add) is disabled in z.fish — zoxide handles
# directory tracking. These vars are kept so `z` queries still work against
# the existing frecency database (read-only after this change).
set -gx Z_DATA_DIR "$HOME/.local/share/z"
set -gx Z_DATA "$Z_DATA_DIR/data"

# Disable zoxide doctor warnings
set -x _ZO_DOCTOR 0

# PERF: Prevent Homebrew's vendor_conf.d/mise.fish from running `mise activate fish | source`
# on every shell startup (~112ms). We use __cache_tool_init in config.fish instead.
set -gx MISE_FISH_AUTO_ACTIVATE 0
