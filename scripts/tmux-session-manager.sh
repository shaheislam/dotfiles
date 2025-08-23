#!/bin/bash

# Simple tmux session manager with tmuxinator support
# Setup proper environment

# Setup PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Build list
build_list() {
  tmux list-sessions -F '[S] #{session_name}: #{session_windows}w#{?session_attached, *,}' 2>/dev/null || echo ""
  
  if tmux list-sessions 2>/dev/null | grep -q .; then
    echo ""
  fi
  
  if command -v tmuxinator &>/dev/null; then
    tmuxinator list -n 2>/dev/null | grep -v "^tmuxinator" | grep -v "^$" | sed 's/^/[T] /' || true
    echo ""
  fi
  
  if command -v zoxide &>/dev/null; then
    zoxide query -l | head -10 | sed "s|^$HOME|~|" | sed 's/^/[Z] /' || true
  fi
}

# Use fzf for selection
RESULT=$(build_list | fzf --reverse --ansi --header "Sessions [S] | Tmuxinator [T] | Zoxide [Z]" --height=100%)

[ -z "$RESULT" ] && exit 0

# Handle selection
PREFIX=$(echo "$RESULT" | cut -d' ' -f1)
CONTENT=$(echo "$RESULT" | cut -d' ' -f2-)

case "$PREFIX" in
  "[S]")
    SESSION=$(echo "$CONTENT" | cut -d: -f1)
    tmux switch-client -t "$SESSION" || tmux attach -t "$SESSION"
    ;;
  "[T]")
    tmuxinator start "$CONTENT"
    ;;
  "[Z]")
    DIR=$(echo "$CONTENT" | sed "s|^~|$HOME|")
    NAME=$(basename "$DIR" | tr '.' '_')
    if tmux has-session -t "$NAME" 2>/dev/null; then
      tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
    else
      tmux new-session -d -s "$NAME" -c "$DIR"
      tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
    fi
    ;;
esac