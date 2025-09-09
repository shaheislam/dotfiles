#!/usr/bin/env bash
# Fix tmux-urlview plugin to use dynamic temp paths instead of hardcoded ones

PLUGIN_FILE="$HOME/.tmux/plugins/tmux-urlview/urlview.tmux"

if [ ! -f "$PLUGIN_FILE" ]; then
    echo "tmux-urlview plugin not found at $PLUGIN_FILE"
    exit 1
fi

echo "Fixing tmux-urlview plugin to use dynamic temp paths..."

cat > "$PLUGIN_FILE" << 'EOF'
#!/usr/bin/env bash

get_tmux_option() {
  local option=$1
  local default_value=$2
  local option_value=$(tmux show-option -gqv "$option")
  if [ -z $option_value ]; then
    echo $default_value
  else
    echo $option_value
  fi
}

find_executable() {
  if type urlview >/dev/null 2>&1; then
    echo "urlview"
  elif type extract_url >/dev/null 2>&1; then
    echo "extract_url"
  fi
}

readonly key="$(get_tmux_option "@urlview-key" "u")"
readonly cmd="$(find_executable)"

if [ -z "$cmd" ]; then
  tmux display-message "Failed to load tmux-urlview: neither urlview nor extract_url were found on the PATH"
else
  # Create a wrapper script that handles temp files properly
  tmux bind-key "$key" run-shell "
    tmpfile=\$(mktemp -t tmux-urlview.XXXXXX) && 
    tmux capture-pane -J -p > \"\$tmpfile\" && 
    tmux split-window -l 10 \"$cmd '\$tmpfile'; rm -f '\$tmpfile'\"
  "
fi
EOF

chmod +x "$PLUGIN_FILE"

echo "Fixed! Now reload tmux configuration..."
tmux source-file ~/.tmux.conf 2>/dev/null || echo "Please run: tmux source-file ~/.tmux.conf"

echo "✅ tmux-urlview plugin fixed to use dynamic temp paths"