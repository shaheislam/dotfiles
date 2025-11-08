#!/usr/bin/env bash
# Generate dynamic window color based on index
# Usage: tmux-window-color.sh <window_index> <window_name> <zoomed_flag>

WIN_IDX="$1"
WIN_NAME="$2"
ZOOMED="$3"

# Calculate modulo 5 for color selection
MOD=$((WIN_IDX % 5))

# Assign color based on modulo result
case $MOD in
  0) COLOR="#f38ba8" ;;  # pink
  1) COLOR="#89dceb" ;;  # blue
  2) COLOR="#a6e3a1" ;;  # green
  3) COLOR="#f9e2af" ;;  # yellow
  4) COLOR="#cba6f7" ;;  # mauve
esac

# Generate zoom indicator if needed
ZOOM_INDICATOR=""
if [ "$ZOOMED" = "1" ]; then
  ZOOM_INDICATOR=" 󰊓"
fi

# Output format string with proper powerline separators
echo -n "#[fg=${COLOR},bg=#1e1e2e]#[fg=#1e1e2e,bg=${COLOR},bold] ${WIN_IDX} #[fg=${COLOR},bg=#1e1e2e]#[bold] ${WIN_NAME}${ZOOM_INDICATOR} "
