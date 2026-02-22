#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# Theme: Tokyo Night Custom
# Variant: Storm-based with personalised session/window colors
# Base: https://github.com/folke/tokyonight.nvim (storm palette)
#
# Edit these colors to customise your tmux status bar appearance.
# After editing, reload tmux config: prefix + r (or tmux source ~/.tmux.conf)
#
# Color reference (Tokyo Night palette):
#   Blue:    #7aa2f7   Purple: #bb9af7   Cyan:   #7dcfff
#   Green:   #9ece6a   Yellow: #e0af68   Orange: #ff9e64
#   Red:     #f7768e   Teal:   #73daca   Pink:   #ff007c
#   Fg:      #c0caf5   Dim:    #565f89   Bg:     #24283b
# =============================================================================

declare -gA THEME_COLORS

THEME_COLORS[statusbar-bg]="#292e42"
THEME_COLORS[statusbar-fg]="#c0caf5"

# Session (left pill)
THEME_COLORS[session-bg]="#9ece6a"
THEME_COLORS[session-fg]="#1a1b26"
THEME_COLORS[session-prefix-bg]="#e0af68"
THEME_COLORS[session-copy-bg]="#7dcfff"

# Windows (centre pills)
# Active window: #bb9af7 (purple) is storm default
# Try: #7aa2f7 (blue), #73daca (teal), #9ece6a (green), #ff9e64 (orange)
THEME_COLORS[window-active-base]="#7aa2f7"
# Inactive window: #3b4261 is storm default
THEME_COLORS[window-inactive-base]="#3b4261"

# Pane borders
THEME_COLORS[pane-border-active]="#7aa2f7"
THEME_COLORS[pane-border-inactive]="#3b4261"

# Health states (variants auto-generated)
THEME_COLORS[ok-base]="#394b70"
THEME_COLORS[good-base]="#9ece6a"
THEME_COLORS[info-base]="#7dcfff"
THEME_COLORS[warning-base]="#e0af68"
THEME_COLORS[error-base]="#f7768e"
THEME_COLORS[disabled-base]="#565f89"

# Messages
THEME_COLORS[message-bg]="#292e42"
THEME_COLORS[message-fg]="#c0caf5"

# Popup and menu
THEME_COLORS[popup-bg]="#292e42"
THEME_COLORS[popup-fg]="#c0caf5"
THEME_COLORS[popup-border]="#7aa2f7"
THEME_COLORS[menu-bg]="#292e42"
THEME_COLORS[menu-fg]="#c0caf5"
THEME_COLORS[menu-selected-bg]="#9ece6a"
THEME_COLORS[menu-selected-fg]="#24283b"
THEME_COLORS[menu-border]="#7aa2f7"
