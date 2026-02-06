#!/bin/bash

# Tmux Session Manager with Tmuxinator Integration
# Provides unified interface for sessions, tmuxinator templates, directories, and path completion
# Includes Claude/Opencode idle indicators (🟢/🔵) per session

# Setup PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Indicators matching tmux-claude-watcher.sh
CLAUDE_INDICATOR="*"
OPENCODE_INDICATOR="+"

# Check a session's windows for Claude/Opencode idle indicators
# Returns indicator string like "🟢", "🔵", or "🟢🔵"
get_session_indicators() {
  local session="$1"
  local has_claude=false
  local has_opencode=false

  # Check each window name for indicator prefixes added by the watcher
  # Indicators: "*" for Claude, "+" for Opencode, "*+" for both
  while IFS= read -r win_name; do
    # Check for combined "*+ " prefix
    if [[ "$win_name" == \*+\ * ]]; then
      has_claude=true
      has_opencode=true
    # Check for Claude "* " prefix
    elif [[ "$win_name" == \*\ * ]]; then
      has_claude=true
    # Check for Opencode "+ " prefix
    elif [[ "$win_name" == +\ * ]]; then
      has_opencode=true
    fi
  done < <(tmux list-windows -t "$session" -F "#{window_name}" 2>/dev/null)

  local indicators=""
  $has_claude && indicators+="🟢"
  $has_opencode && indicators+="🔵"
  echo "$indicators"
}

# Initial list of sessions, tmuxinator templates, and zoxide directories
initial_list() {
  # Existing sessions with Claude/Opencode indicators
  while IFS= read -r line; do
    local session_name
    session_name=$(echo "$line" | cut -d: -f1)
    local indicators
    indicators=$(get_session_indicators "$session_name")
    if [[ -n "$indicators" ]]; then
      echo "[S] ${line} ${indicators}"
    else
      echo "[S] ${line}"
    fi
  done < <(tmux list-sessions -F '#{session_name}: #{session_windows}w#{?session_attached, *,}' 2>/dev/null) || true
  
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

# Existing sessions with Claude/Opencode indicators
while IFS= read -r line; do
  sess=$(echo "$line" | cut -d: -f1)
  indicators=""
  while IFS= read -r wname; do
    if [[ "$wname" == \*+\ * ]]; then
      indicators="🟢🔵"; break
    elif [[ "$wname" == \*\ * ]]; then
      [[ "$indicators" != *🟢* ]] && indicators+="🟢"
    elif [[ "$wname" == +\ * ]]; then
      [[ "$indicators" != *🔵* ]] && indicators+="🔵"
    fi
  done < <(tmux list-windows -t "$sess" -F "#{window_name}" 2>/dev/null)
  if [ -n "$indicators" ]; then
    echo "[S] ${line} ${indicators}"
  else
    echo "[S] ${line}"
  fi
done < <(tmux list-sessions -F "#{session_name}: #{session_windows}w#{?session_attached, *,}" 2>/dev/null) || true

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

# Tokyo Night color theme for fzf
FZF_COLORS="--color=fg:#c0caf5,bg:#1a1b26,hl:#7aa2f7,fg+:#c0caf5,bg+:#283457,hl+:#bb9af7,info:#e0af68,prompt:#7dcfff,pointer:#7aa2f7,marker:#9ece6a,spinner:#7dcfff,header:#9d7cd8"

# Use fzf for session/path selection
RESULT=$(
  initial_list | fzf \
  --reverse \
  --ansi \
  --header "Sessions [S] | Tmuxinator [T] | Zoxide [Z] | 🟢 Claude idle | 🔵 Opencode idle | Tab to complete" \
  --height=100% \
  --print-query \
  --bind "tab:reload(bash -c '$reload_cmd')" \
  $FZF_COLORS \
  | tail -n 1
)

[ -z "$RESULT" ] && exit 0

# Handle selection based on prefix or as typed input
PREFIX=$(echo "$RESULT" | cut -d' ' -f1)
CONTENT=$(echo "$RESULT" | cut -d' ' -f2-)

case "$PREFIX" in
  "[S]")
    # Switch to existing session (strip trailing indicator emojis)
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