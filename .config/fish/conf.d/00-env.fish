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

# Shared script-facing environment. Keep Fish-only interactive UX elsewhere, but
# set exported state here so non-interactive Fish, Bash, and Zsh converge.
set -q DOTFILES_HOME; or set -gx DOTFILES_HOME "$HOME/dotfiles"
set -q EDITOR; or set -gx EDITOR nvim
set -q VISUAL; or set -gx VISUAL nvim
set -q PAGER; or set -gx PAGER less
set -q MANPAGER; or set -gx MANPAGER "less -R"
set -q STARSHIP_CONFIG; or set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
set -q LANG; or set -gx LANG en_US.UTF-8
set -q BAT_THEME; or set -gx BAT_THEME miniautumn
set -q BAT_PAGING; or set -gx BAT_PAGING never
set -q HOMEBREW_AUTO_UPDATE_SECS; or set -gx HOMEBREW_AUTO_UPDATE_SECS 86400
set -q FORCE_AUTOUPDATE_PLUGINS; or set -gx FORCE_AUTOUPDATE_PLUGINS 1
set -q CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD; or set -gx CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD 1
set -q CLAUDE_CODE_EFFORT_LEVEL; or set -gx CLAUDE_CODE_EFFORT_LEVEL medium
set -q CLAUDE_CODE_NO_FLICKER; or set -gx CLAUDE_CODE_NO_FLICKER 0
set -q CLAUDE_CODE_ENABLE_TELEMETRY; or set -gx CLAUDE_CODE_ENABLE_TELEMETRY 1
set -q OTEL_EXPORTER_OTLP_ENDPOINT; or set -gx OTEL_EXPORTER_OTLP_ENDPOINT "http://localhost:4318"
set -q OPENCODE_DISABLE_LSP_DOWNLOAD; or set -gx OPENCODE_DISABLE_LSP_DOWNLOAD true

# Package manager cache dirs — explicit paths enable devcontainer bind mounts
# and ensure all shells agree on the canonical location.
set -q BUN_INSTALL; or set -gx BUN_INSTALL "$HOME/.bun"
set -q UV_CACHE_DIR; or set -gx UV_CACHE_DIR "$HOME/.cache/uv"
set -q UV_LINK_MODE; or set -gx UV_LINK_MODE hardlink
set -q GOPATH; or set -gx GOPATH "$HOME/go"
set -q GOMODCACHE; or set -gx GOMODCACHE "$HOME/go/pkg/mod"
set -q CARGO_HOME; or set -gx CARGO_HOME "$HOME/.cargo"

# Ensure cache dirs exist so devcontainer bind mounts always have a source.
for _cache_dir in "$HOME/.bun/install/cache" "$HOME/.cache/uv" "$HOME/.cargo/registry" "$HOME/go/pkg/mod"
    test -d "$_cache_dir"; or mkdir -p "$_cache_dir" 2>/dev/null
end
set -e _cache_dir
