#!/bin/bash

# Tmux Session Manager with Tmuxinator Integration
# Provides unified interface for sessions, tmuxinator templates, directories, and path completion

# Setup PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Initial list of sessions, tmuxinator templates, and zoxide directories
initial_list() {
  # Existing sessions
  tmux list-sessions -F '[S] #{session_name}: #{session_windows}w#{?session_attached, *,}' 2>/dev/null || true
  
  # Tmuxinator projects
  if command -v tmuxinator &>/dev/null; then
    tmuxinator list -n 2>/dev/null | grep -v "^tmuxinator" | grep -v "^$" | sed 's/^/[T] /' || true
  fi
  
  # Recent directories from zoxide
  if command -v zoxide &>/dev/null; then
    zoxide query -l | head -20 | sed "s|^$HOME|~|" | sed 's/^/[Z] /' || true
  fi
}

# Self-contained reload command for tab completion (executed in fzf subshell)
reload_cmd='
query="{q}"

# Existing sessions
tmux list-sessions -F "[S] #{session_name}: #{session_windows}w#{?session_attached, *,}" 2>/dev/null || true

# Tmuxinator projects
if command -v tmuxinator &>/dev/null; then
  tmuxinator list -n 2>/dev/null | grep -v "^tmuxinator" | grep -v "^$" | sed "s/^/[T] /" || true
fi

# Recent directories from zoxide
if command -v zoxide &>/dev/null; then
  zoxide query -l | head -20 | sed "s|^$HOME|~|" | sed "s/^/[Z] /" || true
fi

# Add path completions if typing a path
if [[ -n "$query" ]] && ([[ "$query" == /* ]] || [[ "$query" == ~* ]]); then
  expanded_query=$(echo "$query" | sed "s|^~|$HOME|")
  
  if [[ "$expanded_query" == */ ]]; then
    dir="$expanded_query"
    base=""
  else
    dir=$(dirname "$expanded_query")
    base=$(basename "$expanded_query")
  fi
  
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type d 2>/dev/null | while read -r item; do
      name=$(basename "$item")
      if [[ "$name" != .* ]] || [[ "$base" == .* ]]; then
        if [[ -z "$base" ]] || [[ "$name" == "$base"* ]]; then
          display_path="$item/"
          display_path=$(echo "$display_path" | sed "s|^$HOME|~|")
          echo "[P] $display_path"
        fi
      fi
    done
  fi
fi
'

# Use fzf for session/path selection
RESULT=$(
  initial_list | fzf \
  --reverse \
  --ansi \
  --header "Sessions [S] | Tmuxinator [T] | Zoxide [Z] | Type path to browse | Tab to complete" \
  --height=100% \
  --print-query \
  --bind "tab:reload(bash -c '$reload_cmd')" \
  | tail -n 1
)

[ -z "$RESULT" ] && exit 0

# Handle selection based on prefix or as typed input
PREFIX=$(echo "$RESULT" | cut -d' ' -f1)
CONTENT=$(echo "$RESULT" | cut -d' ' -f2-)

case "$PREFIX" in
  "[S]")
    # Switch to existing session
    SESSION=$(echo "$CONTENT" | cut -d: -f1)
    tmux switch-client -t "$SESSION" || tmux attach -t "$SESSION"
    ;;
    
  "[T]")
    # Start tmuxinator project
    tmuxinator start "$CONTENT"
    ;;
    
  "[Z]"|"[D]"|"[P]")
    # Create/switch session from directory
    DIR=$(echo "$CONTENT" | sed "s|^~|$HOME|" | sed 's|/$||')
    NAME=$(basename "$DIR" | tr '.' '_' | tr ' ' '_' | tr '/' '_')
    
    # Clean up the session name
    NAME=$(echo "$NAME" | sed 's/^_*//' | sed 's/_*$//')
    [ -z "$NAME" ] && NAME="session"
    
    if tmux has-session -t "$NAME" 2>/dev/null; then
      tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
    else
      tmux new-session -d -s "$NAME" -c "$DIR"
      tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
    fi
    ;;
    
  *)
    # Handle typed input - could be a path or session name
    INPUT="$RESULT"
    
    # Expand tilde if present
    INPUT=$(echo "$INPUT" | sed "s|^~|$HOME|")
    
    # Check if it's a directory path
    if [ -d "$INPUT" ]; then
      # It's a directory - create session from path
      DIR="$INPUT"
      NAME=$(basename "$DIR" | tr '.' '_' | tr ' ' '_' | tr '/' '_')
      
      # Clean up the session name
      NAME=$(echo "$NAME" | sed 's/^_*//' | sed 's/_*$//')
      [ -z "$NAME" ] && NAME="session"
      
      if tmux has-session -t "$NAME" 2>/dev/null; then
        tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
      else
        tmux new-session -d -s "$NAME" -c "$DIR"
        tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
      fi
    else
      # Check if it looks like a path that doesn't exist yet
      if [[ "$INPUT" == *"/"* ]] || [[ "$INPUT" == "~"* ]]; then
        # Looks like a path but doesn't exist
        echo "Directory does not exist: $INPUT"
        echo "Press Enter to exit"
        read
        exit 1
      else
        # Treat as a new session name
        NAME=$(echo "$INPUT" | tr '.' '_' | tr ' ' '_' | tr '/' '_')
        
        if tmux has-session -t "$NAME" 2>/dev/null; then
          tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
        else
          # Create new session in current directory or home
          tmux new-session -d -s "$NAME"
          tmux switch-client -t "$NAME" || tmux attach -t "$NAME"
        fi
      fi
    fi
    ;;
esac