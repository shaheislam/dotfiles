#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# Theme: Tokyo Night Custom
# Variant: Storm-based with rectangular, muted status colors
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

THEME_COLORS["statusbar-bg"]="#16161e"
THEME_COLORS["statusbar-fg"]="#a9b1d6"

# Session (left segment)
THEME_COLORS["session-bg"]="#24283b"
THEME_COLORS["session-fg"]="#a9b1d6"
THEME_COLORS["session-prefix-bg"]="#3b4261"
THEME_COLORS["session-copy-bg"]="#29394f"

# Windows (centre segments)
# Active window uses a muted blue-grey so it is visible without popping.
# Try: #7aa2f7 (blue), #73daca (teal), #9ece6a (green), #ff9e64 (orange)
THEME_COLORS["window-active-base"]="#2f3549"
# Inactive window: #3b4261 is storm default
THEME_COLORS["window-inactive-base"]="#1f2335"

# Pane borders
THEME_COLORS["pane-border-active"]="#3b4261"
THEME_COLORS["pane-border-inactive"]="#1f2335"

# Health states (variants auto-generated)
THEME_COLORS["ok-base"]="#24283b"
THEME_COLORS["good-base"]="#31483f"
THEME_COLORS["info-base"]="#29394f"
THEME_COLORS["warning-base"]="#4a3f2d"
THEME_COLORS["error-base"]="#4a2f36"
THEME_COLORS["disabled-base"]="#3b4261"

# Messages
THEME_COLORS["message-bg"]="#1f2335"
THEME_COLORS["message-fg"]="#a9b1d6"

# Popup and menu
THEME_COLORS["popup-bg"]="#1f2335"
THEME_COLORS["popup-fg"]="#a9b1d6"
THEME_COLORS["popup-border"]="#3b4261"
THEME_COLORS["menu-bg"]="#1f2335"
THEME_COLORS["menu-fg"]="#a9b1d6"
THEME_COLORS["menu-selected-bg"]="#2f3549"
THEME_COLORS["menu-selected-fg"]="#c0caf5"
THEME_COLORS["menu-border"]="#3b4261"
