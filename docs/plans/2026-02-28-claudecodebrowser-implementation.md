# ClaudeCodeBrowser Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate ClaudeCodeBrowser into the dotfiles so Claude Code can automate Firefox with CORS hardening applied.

**Architecture:** Clone repo to `~/.claudecodebrowser/`, patch CORS wildcard, register native messaging host for macOS, configure MCP in both Claude Code CLI and Claude Desktop, create Fish management function.

**Tech Stack:** Bash (setup.sh), Fish (ccb.fish), JSON (native messaging manifest, Claude Desktop config), Python (MCP server)

---

### Task 1: Add websockets dependency to setup.sh Phase 3

**Files:**
- Modify: `scripts/setup.sh:393` (after last pipx install)

**Step 1: Add pip3 install websockets**

Add the websockets dependency after the existing pipx installs in the `phase_3_development` function. Insert after line 393 (`pipx install hookify`):

```bash
        pip3 install websockets >/dev/null 2>&1 || print_warning "Failed to install websockets (optional for ClaudeCodeBrowser WebSocket mode)"
```

This goes inside the existing `if command_exists pipx` block, before `print_success "Python MCP servers installation complete"`.

**Step 2: Verify the edit**

Run: `grep -n 'websockets' scripts/setup.sh`
Expected: One match showing the new line.

**Step 3: Commit**

```bash
git add scripts/setup.sh
git commit -m "feat: add websockets dependency for ClaudeCodeBrowser"
```

---

### Task 2: Add ClaudeCodeBrowser setup block to setup.sh Phase 4

**Files:**
- Modify: `scripts/setup.sh:590` (after MCP server configuration block)

**Step 1: Add the ClaudeCodeBrowser section**

Insert after line 590 (`claude mcp add --scope user --transport sse deepwiki ...`) and before `print_success "Claude Code MCP configuration complete"` (line 592). This entire block goes inside the existing `if command_exists claude` block:

```bash

        # ClaudeCodeBrowser - Firefox browser automation for Claude Code
        # See docs/claudecodebrowser-security-assessment.md for security details
        CCB_DIR="$HOME/.claudecodebrowser"
        if [ ! -d "$CCB_DIR" ]; then
            print_step "Installing ClaudeCodeBrowser..."
            git clone https://github.com/nanogenomic/ClaudeCodeBrowser.git "$CCB_DIR" >/dev/null 2>&1 || print_warning "Failed to clone ClaudeCodeBrowser"
        else
            print_step "Updating ClaudeCodeBrowser..."
            (cd "$CCB_DIR" && git pull >/dev/null 2>&1) || print_warning "Failed to update ClaudeCodeBrowser"
        fi

        if [ -d "$CCB_DIR" ]; then
            # CORS hardening - replace wildcard origin with null (prevents drive-by browser control)
            if [ -f "$CCB_DIR/mcp-server/server.py" ]; then
                sed -i '' "s/Access-Control-Allow-Origin', '\\*'/Access-Control-Allow-Origin', 'null'/" \
                    "$CCB_DIR/mcp-server/server.py" 2>/dev/null || true
            fi

            # Make scripts executable
            chmod +x "$CCB_DIR"/native-host/*.py "$CCB_DIR"/mcp-server/*.py 2>/dev/null || true

            # Register native messaging host (macOS)
            NMH_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
            mkdir -p "$NMH_DIR"
            cat > "$NMH_DIR/claudecodebrowser.json" << NMHEOF
{
  "name": "claudecodebrowser",
  "description": "ClaudeCodeBrowser Native Messaging Host",
  "path": "$CCB_DIR/native-host/claudecodebrowser_host.py",
  "type": "stdio",
  "allowed_extensions": ["claudecodebrowser@ligandal.com"]
}
NMHEOF

            # Register MCP server with Claude Code CLI
            claude mcp add --scope user claudecodebrowser \
                --transport stdio \
                -- python3 "$CCB_DIR/mcp-server/stdio_wrapper.py" >/dev/null 2>&1 || true

            print_success "ClaudeCodeBrowser installed with CORS hardening"
            echo "  Install Firefox extension from:"
            echo "  https://addons.mozilla.org/en-US/firefox/addon/claudecodebrowser/"
        fi
```

**Step 2: Verify the edit**

Run: `grep -n 'ClaudeCodeBrowser\|CCB_DIR\|claudecodebrowser' scripts/setup.sh`
Expected: Multiple matches showing the new block.

**Step 3: Commit**

```bash
git add scripts/setup.sh
git commit -m "feat: add ClaudeCodeBrowser setup to Phase 4 with CORS hardening"
```

---

### Task 3: Update Claude Desktop config with MCP server entry

**Files:**
- Modify: `Library/Application Support/Claude/claude_desktop_config.json`

**Step 1: Add claudecodebrowser MCP server entry**

Add after the `drawio` entry (line 30), before the closing `}` of `mcpServers`:

```json
    "claudecodebrowser": {
      "command": "python3",
      "args": [
        "/Users/shahe/.claudecodebrowser/mcp-server/stdio_wrapper.py"
      ]
    }
```

The `drawio` entry on line 30 needs a trailing comma added after its closing `}`.

The full result should look like:

```json
    "drawio": {
      "command": "bunx",
      "args": [
        "drawio-mcp-server"
      ]
    },
    "claudecodebrowser": {
      "command": "python3",
      "args": [
        "/Users/shahe/.claudecodebrowser/mcp-server/stdio_wrapper.py"
      ]
    }
```

**Note on portability**: The path uses `$HOME` expansion at runtime. For the stow-managed JSON file, we hardcode the current user's home path since this is a personal dotfiles repo. On a new device, setup.sh can regenerate the Claude Desktop config or the user updates the path.

**Step 2: Validate JSON**

Run: `python3 -m json.tool "Library/Application Support/Claude/claude_desktop_config.json" > /dev/null && echo "Valid JSON"`
Expected: `Valid JSON`

**Step 3: Commit**

```bash
git add "Library/Application Support/Claude/claude_desktop_config.json"
git commit -m "feat: add ClaudeCodeBrowser MCP server to Claude Desktop config"
```

---

### Task 4: Create the ccb.fish management function

**Files:**
- Create: `.config/fish/functions/ccb.fish`

**Step 1: Write the Fish function**

```fish
# ClaudeCodeBrowser management wrapper
# Firefox browser automation for Claude Code via MCP
#
# Usage:
#   ccb start      - Launch MCP server in background
#   ccb stop       - Stop MCP server
#   ccb status     - Show server running state and port availability
#   ccb logs       - Tail server logs
#   ccb update     - git pull + re-apply CORS patch + restart if running
#
# See: docs/claudecodebrowser-security-assessment.md

function ccb --description "Manage ClaudeCodeBrowser Firefox automation"
    set -l ccb_dir "$HOME/.claudecodebrowser"
    set -l pid_file "$ccb_dir/logs/server.pid"
    set -l log_dir "$ccb_dir/logs"

    if not test -d "$ccb_dir"
        echo "ClaudeCodeBrowser not installed. Run scripts/setup.sh or:"
        echo "  git clone https://github.com/nanogenomic/ClaudeCodeBrowser.git $ccb_dir"
        return 1
    end

    set -l cmd $argv[1]
    if test -z "$cmd"
        set cmd status
    end

    switch $cmd
        case start
            # Check if already running
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                echo "MCP server already running (PID: "(cat "$pid_file")")"
                return 0
            end

            mkdir -p "$log_dir"
            echo "Starting MCP server..."
            python3 "$ccb_dir/mcp-server/server.py" > "$log_dir/server.log" 2>&1 &
            set -l server_pid $last_pid
            echo $server_pid > "$pid_file"
            sleep 1

            if kill -0 $server_pid 2>/dev/null
                echo "MCP server started (PID: $server_pid)"
                echo "  HTTP: http://127.0.0.1:8765"
                echo "  WebSocket: ws://127.0.0.1:8766"
            else
                echo "MCP server failed to start. Check: $log_dir/server.log"
                rm -f "$pid_file"
                return 1
            end

        case stop
            if test -f "$pid_file"
                set -l pid (cat "$pid_file")
                if kill -0 $pid 2>/dev/null
                    kill $pid
                    echo "MCP server stopped (PID: $pid)"
                else
                    echo "MCP server not running (stale PID file)"
                end
                rm -f "$pid_file"
            else
                echo "MCP server not running (no PID file)"
            end

        case status
            echo "ClaudeCodeBrowser Status"
            echo "========================"
            echo "Install dir: $ccb_dir"

            # Server status
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                echo "MCP server: running (PID: "(cat "$pid_file")")"
            else
                echo "MCP server: stopped"
            end

            # Port check
            if lsof -i :8765 >/dev/null 2>&1
                echo "HTTP port 8765: in use"
            else
                echo "HTTP port 8765: available"
            end

            if lsof -i :8766 >/dev/null 2>&1
                echo "WS port 8766: in use"
            else
                echo "WS port 8766: available"
            end

            # CORS check
            if test -f "$ccb_dir/mcp-server/server.py"
                if grep -q "Allow-Origin', '\\*'" "$ccb_dir/mcp-server/server.py"
                    echo "CORS: UNPATCHED (wildcard - vulnerable)"
                else
                    echo "CORS: patched (hardened)"
                end
            end

            # Extension install reminder
            echo ""
            echo "Firefox extension: https://addons.mozilla.org/en-US/firefox/addon/claudecodebrowser/"

        case logs
            if test -f "$log_dir/server.log"
                tail -f "$log_dir/server.log"
            else
                echo "No log file found at $log_dir/server.log"
            end

        case update
            echo "Updating ClaudeCodeBrowser..."

            # Check if running
            set -l was_running false
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                set was_running true
                ccb stop
            end

            # Pull latest
            cd "$ccb_dir"
            git pull
            cd -

            # Re-apply CORS hardening
            if test -f "$ccb_dir/mcp-server/server.py"
                sed -i '' "s/Access-Control-Allow-Origin', '\\*'/Access-Control-Allow-Origin', 'null'/" \
                    "$ccb_dir/mcp-server/server.py" 2>/dev/null; or true
                echo "CORS hardening re-applied"
            end

            # Make scripts executable
            chmod +x "$ccb_dir"/native-host/*.py "$ccb_dir"/mcp-server/*.py 2>/dev/null; or true

            # Restart if was running
            if test "$was_running" = true
                ccb start
            end

            echo "Update complete"

        case '*'
            echo "Usage: ccb [start|stop|status|logs|update]"
            return 1
    end
end
```

**Step 2: Verify the file exists and is valid Fish syntax**

Run: `fish -n .config/fish/functions/ccb.fish && echo "Valid Fish syntax"`
Expected: `Valid Fish syntax`

**Step 3: Commit**

```bash
git add .config/fish/functions/ccb.fish
git commit -m "feat: add ccb Fish function for ClaudeCodeBrowser management"
```

---

### Task 5: Verify end-to-end locally

This task validates the integration works on the current machine.

**Step 1: Run the ClaudeCodeBrowser section of setup.sh**

Run the relevant setup.sh section manually (don't run the full script):

```bash
# Clone if needed
CCB_DIR="$HOME/.claudecodebrowser"
if [ ! -d "$CCB_DIR" ]; then
    git clone https://github.com/nanogenomic/ClaudeCodeBrowser.git "$CCB_DIR"
fi

# CORS hardening
sed -i '' "s/Access-Control-Allow-Origin', '\\*'/Access-Control-Allow-Origin', 'null'/" \
    "$CCB_DIR/mcp-server/server.py" 2>/dev/null || true

# Make executable
chmod +x "$CCB_DIR"/native-host/*.py "$CCB_DIR"/mcp-server/*.py 2>/dev/null || true
```

Expected: Repository cloned to `~/.claudecodebrowser/`, CORS patched.

**Step 2: Verify CORS patch applied**

Run: `grep "Allow-Origin" ~/.claudecodebrowser/mcp-server/server.py | head -3`
Expected: Lines showing `'null'` instead of `'*'`.

**Step 3: Register native messaging host**

```bash
NMH_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
mkdir -p "$NMH_DIR"
cat > "$NMH_DIR/claudecodebrowser.json" << EOF
{
  "name": "claudecodebrowser",
  "description": "ClaudeCodeBrowser Native Messaging Host",
  "path": "$HOME/.claudecodebrowser/native-host/claudecodebrowser_host.py",
  "type": "stdio",
  "allowed_extensions": ["claudecodebrowser@ligandal.com"]
}
EOF
```

Expected: File created at the native messaging host path.

**Step 4: Verify native messaging manifest**

Run: `cat "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/claudecodebrowser.json" | python3 -m json.tool`
Expected: Valid JSON with correct path.

**Step 5: Register MCP server with Claude Code CLI**

Run: `claude mcp add --scope user claudecodebrowser --transport stdio -- python3 "$HOME/.claudecodebrowser/mcp-server/stdio_wrapper.py"`
Expected: Success (or already exists).

**Step 6: Verify MCP registration**

Run: `claude mcp list | grep claudecodebrowser`
Expected: `claudecodebrowser` appears in the list.

**Step 7: Test ccb Fish function**

Run: `source .config/fish/functions/ccb.fish && ccb status`
Expected: Status output showing install dir, server stopped, ports available, CORS patched.

**Step 8: Test ccb start/stop cycle**

Run: `ccb start && sleep 2 && ccb status && ccb stop`
Expected: Server starts on ports 8765/8766, status shows running, then stops cleanly.

**Step 9: Print manual step reminder**

The Firefox extension must be installed manually from AMO:
`https://addons.mozilla.org/en-US/firefox/addon/claudecodebrowser/`

Firefox doesn't allow programmatic extension installation.

**Step 10: Commit verification results**

No code changes needed. If all steps pass, the integration is complete.

---

### Task 6: Resolve CLAUDE.md merge conflict markers

**Files:**
- Modify: `CLAUDE.md` (root level, if merge conflict markers exist)

**Step 1: Check for merge conflict markers**

Run: `grep -n '<<<<<<\|======\|>>>>>>' CLAUDE.md | head -10`

If markers exist, resolve them by keeping the most recent version (the `HEAD` side for merged content).

**Step 2: Commit if changes made**

```bash
git add CLAUDE.md
git commit -m "fix: resolve merge conflict markers in CLAUDE.md"
```

---

## Summary

| Task | Files | What |
|------|-------|------|
| 1 | `scripts/setup.sh` | Add `pip3 install websockets` to Phase 3 |
| 2 | `scripts/setup.sh` | Add ClaudeCodeBrowser setup block to Phase 4 |
| 3 | `Library/.../claude_desktop_config.json` | Add MCP server entry |
| 4 | `.config/fish/functions/ccb.fish` | Create Fish management function |
| 5 | (no files) | End-to-end verification |
| 6 | `CLAUDE.md` | Resolve any merge conflict markers |
