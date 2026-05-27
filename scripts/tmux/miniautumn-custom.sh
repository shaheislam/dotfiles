#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# Theme: Miniautumn Custom
# Base: mini.nvim bundled miniautumn colorscheme
#
# Edit these colors to customise your tmux status bar appearance.
# After editing, reload tmux config: prefix + r (or tmux source ~/.tmux.conf)
# =============================================================================

declare -gA THEME_COLORS

THEME_COLORS["statusbar-bg"]="#1a141d"
THEME_COLORS["statusbar-fg"]="#d7d5cd"

# Session (left segment)
THEME_COLORS["session-bg"]="#262029"
THEME_COLORS["session-fg"]="#d7d5cd"
THEME_COLORS["session-prefix-bg"]="#3a0f2f"
THEME_COLORS["session-copy-bg"]="#261844"

# Windows (centre segments)
THEME_COLORS["window-active-base"]="#423b45"
THEME_COLORS["window-inactive-base"]="#1a141d"

# Pane borders
THEME_COLORS["pane-border-active"]="#e4caf1"
THEME_COLORS["pane-border-inactive"]="#423b45"

# Health states (variants auto-generated)
THEME_COLORS["ok-base"]="#262029"
THEME_COLORS["good-base"]="#323700"
THEME_COLORS["info-base"]="#00284a"
THEME_COLORS["warning-base"]="#492c00"
THEME_COLORS["error-base"]="#3a0f2f"
THEME_COLORS["disabled-base"]="#423b45"

# Messages
THEME_COLORS["message-bg"]="#1a141d"
THEME_COLORS["message-fg"]="#d7d5cd"

# Popup and menu
THEME_COLORS["popup-bg"]="#1a141d"
THEME_COLORS["popup-fg"]="#d7d5cd"
THEME_COLORS["popup-border"]="#423b45"
THEME_COLORS["menu-bg"]="#1a141d"
THEME_COLORS["menu-fg"]="#d7d5cd"
THEME_COLORS["menu-selected-bg"]="#423b45"
THEME_COLORS["menu-selected-fg"]="#f3f1e9"
THEME_COLORS["menu-border"]="#423b45"
