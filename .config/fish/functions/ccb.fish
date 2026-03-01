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
            # Check if already running via PID file
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                echo "MCP server already running (PID: "(cat "$pid_file")")"
                return 0
            end

            # Kill orphaned processes blocking our ports
            for port in 8765 8766
                set -l stale_pid (lsof -ti :$port 2>/dev/null)
                if test -n "$stale_pid"
                    echo "Killing orphaned process on port $port (PID: $stale_pid)"
                    kill $stale_pid 2>/dev/null
                    sleep 0.5
                end
            end
            rm -f "$pid_file"

            mkdir -p "$log_dir"
            echo "Starting MCP server..."
            python3 "$ccb_dir/mcp-server/server.py" >"$log_dir/server.log" 2>&1 &
            set -l server_pid $last_pid
            echo $server_pid >"$pid_file"
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
            set -l killed false
            if test -f "$pid_file"
                set -l pid (cat "$pid_file")
                if kill -0 $pid 2>/dev/null
                    kill $pid
                    echo "MCP server stopped (PID: $pid)"
                    set killed true
                end
                rm -f "$pid_file"
            end

            # Also kill any orphaned processes on our ports
            for port in 8765 8766
                set -l stale_pid (lsof -ti :$port 2>/dev/null)
                if test -n "$stale_pid"
                    kill $stale_pid 2>/dev/null
                    echo "Killed orphaned process on port $port (PID: $stale_pid)"
                    set killed true
                end
            end

            if test "$killed" = false
                echo "MCP server not running"
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
                else if grep -q _get_cors_origin "$ccb_dir/mcp-server/server.py"
                    echo "CORS: patched (moz-extension:// allowlist)"
                else if grep -q "Allow-Origin', 'null'" "$ccb_dir/mcp-server/server.py"
                    echo "CORS: partially patched (null origin - upgrade recommended)"
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

            # Re-apply CORS hardening (moz-extension:// allowlist)
            if test -f "$ccb_dir/mcp-server/server.py"
                if grep -q "Allow-Origin', '\\*'" "$ccb_dir/mcp-server/server.py"
                    # Run the same Python patcher as setup.sh
                    python3 -c '
import sys, re
path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()
helper = """
    def _get_cors_origin(self):
        origin = self.headers.get("Origin", "")
        if origin.startswith("moz-extension://"):
            return origin
        return ""
"""
content = re.sub(
    r"(    def log_message\(self, format, \*args\):\n        logger\.info\(f\"HTTP: \{format % args\}\"\)\n)",
    r"\1" + helper,
    content
)
content = content.replace(
    "self.send_header('"'"'Access-Control-Allow-Origin'"'"', '"'"'*'"'"')",
    "self.send_header('"'"'Access-Control-Allow-Origin'"'"', self._get_cors_origin())"
)
with open(path, "w") as f:
    f.write(content)
print("CORS patched: moz-extension:// allowlist")
' "$ccb_dir/mcp-server/server.py" 2>/dev/null; or true
                else
                    echo "CORS already patched"
                end
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
