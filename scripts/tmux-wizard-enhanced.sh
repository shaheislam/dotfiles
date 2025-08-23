#!/bin/bash

# Enhanced tmux session wizard with tmuxinator support
# Ensures proper environment for tmux popup

# Setup PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Build the list of options
build_list() {
  # Existing sessions
  tmux list-sessions -F '[SESSION] #{session_name}: #{session_windows} windows#{?session_attached, (attached),}' 2>/dev/null || echo ""
  
  # Separator if we had sessions
  if tmux list-sessions 2>/dev/null | grep -q .; then
    echo ""
  fi
  
  # Tmuxinator projects
  if command -v tmuxinator &>/dev/null; then
    tmuxinator list -n 2>/dev/null | grep -v "^tmuxinator" | grep -v "^$" | sed 's/^/[TMUXINATOR] /' || true
  fi
  
  # Separator
  echo ""
  
  # Recent directories from zoxide
  if command -v zoxide &>/dev/null; then
    zoxide query -l | head -15 | sed "s|^$HOME|~|" | sed 's/^/[ZOXIDE] /' || true
  fi
}

# Use fzf for selection
RESULT=$(build_list | fzf --reverse --ansi --height=100%)

# Exit if nothing selected
[ -z "$RESULT" ] && exit 0

# Process the selection
case "$RESULT" in
  "[SESSION] "*)
    # Switch to existing session
    SESSION=$(echo "$RESULT" | sed 's/\[SESSION\] //' | cut -d: -f1)
    tmux switch-client -t "$SESSION" 2>/dev/null || tmux attach-session -t "$SESSION"
    ;;
    
  "[TMUXINATOR] "*)
    # Start tmuxinator project
    PROJECT=$(echo "$RESULT" | sed 's/\[TMUXINATOR\] //')
    tmuxinator start "$PROJECT"
    ;;
    
  "[ZOXIDE] "*)
    # Create/switch to session from directory
    DIR=$(echo "$RESULT" | sed 's/\[ZOXIDE\] //' | sed "s|^~|$HOME|")
    NAME=$(basename "$DIR" | tr '.' '_' | tr ' ' '_')
    
    if tmux has-session -t "$NAME" 2>/dev/null; then
      tmux switch-client -t "$NAME" 2>/dev/null || tmux attach-session -t "$NAME"
    else
      tmux new-session -d -s "$NAME" -c "$DIR" 2>/dev/null
      tmux switch-client -t "$NAME" 2>/dev/null || tmux attach-session -t "$NAME"
    fi
    ;;
    
  *)
    # Create new session with typed name
    NAME=$(echo "$RESULT" | tr ' ' '_' | tr '.' '_')
    if tmux has-session -t "$NAME" 2>/dev/null; then
      tmux switch-client -t "$NAME" 2>/dev/null || tmux attach-session -t "$NAME"
    else
      tmux new-session -d -s "$NAME" 2>/dev/null
      tmux switch-client -t "$NAME" 2>/dev/null || tmux attach-session -t "$NAME"
    fi
    ;;
esac