function cc-rc --description "Manage Claude Code Remote Control sessions"
    set -l cmd $argv[1]

    switch "$cmd"
        case start ''
            # Start a new remote control session in the current directory
            set -l rc_args
            if contains -- --verbose $argv
                set -a rc_args --verbose
            end
            if contains -- --sandbox $argv
                set -a rc_args --sandbox
            end

            echo "Starting Remote Control session..."
            echo "  Directory: "(pwd)
            echo "  Press spacebar to show QR code"
            echo "  Open claude.ai/code or Claude mobile app to connect"
            echo ""
            claude remote-control $rc_args

        case status
            # Show remote control configuration status
            echo "Claude Code Remote Control Status"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Check claude command
            if command -q claude
                set -l ver (claude --version 2>/dev/null | head -1)
                echo "✓ claude CLI: $ver"
            else
                echo "✗ claude CLI not found"
                return 1
            end

            # Check if enableRemoteControl is set in ~/.claude.json
            if test -f ~/.claude.json
                if command -q jq
                    set -l rc_enabled (jq -r '.enableRemoteControl // "not set"' ~/.claude.json 2>/dev/null)
                    if test "$rc_enabled" = true
                        echo "✓ Remote Control: enabled for all sessions"
                    else if test "$rc_enabled" = false
                        echo "⚠ Remote Control: disabled (enable via /config or cc-rc enable)"
                    else
                        echo "⚠ Remote Control: not configured (enable via /config or cc-rc enable)"
                    end
                else
                    echo "⚠ jq not installed (cannot check config)"
                end
            else
                echo "⚠ ~/.claude.json not found"
            end

            # Check auth status
            set -l auth_out (CLAUDECODE= claude auth status --text 2>&1; or true)
            if string match -q "*logged in*" "$auth_out"
                echo "✓ Authentication: logged in"
            else
                echo "✗ Authentication: not logged in (run: claude auth login)"
            end

            echo ""
            echo "Remote Control allows continuing local sessions from:"
            echo "  - claude.ai/code (browser)"
            echo "  - Claude iOS/Android app"

        case enable
            # Enable remote control for all sessions
            if test -f ~/.claude.json; and command -q jq
                jq '.enableRemoteControl = true' ~/.claude.json >~/.claude.json.tmp
                and mv ~/.claude.json.tmp ~/.claude.json
                and echo "✓ Remote Control enabled for all sessions"
                or echo "✗ Failed to update ~/.claude.json"
            else
                echo "✗ ~/.claude.json not found or jq not installed"
                return 1
            end

        case disable
            # Disable remote control for all sessions
            if test -f ~/.claude.json; and command -q jq
                jq '.enableRemoteControl = false' ~/.claude.json >~/.claude.json.tmp
                and mv ~/.claude.json.tmp ~/.claude.json
                and echo "✓ Remote Control disabled"
                or echo "✗ Failed to update ~/.claude.json"
            else
                echo "✗ ~/.claude.json not found or jq not installed"
                return 1
            end

        case tmux
            # Start remote control in a new tmux window
            set -l session_name (tmux display-message -p '#S' 2>/dev/null)
            if test -z "$session_name"
                echo "✗ Not in a tmux session"
                return 1
            end

            set -l window_name "rc-"(basename (pwd))
            tmux new-window -n "$window_name" "claude remote-control --verbose"
            echo "✓ Remote Control started in tmux window: $window_name"

        case help '*'
            echo "Usage: cc-rc <command> [options]"
            echo ""
            echo "Commands:"
            echo "  start    Start Remote Control session (default)"
            echo "  status   Show Remote Control configuration"
            echo "  enable   Enable Remote Control for all sessions"
            echo "  disable  Disable Remote Control for all sessions"
            echo "  tmux     Start Remote Control in a new tmux window"
            echo "  help     Show this help"
            echo ""
            echo "Options (for start):"
            echo "  --verbose   Show detailed connection logs"
            echo "  --sandbox   Enable filesystem/network sandboxing"
            echo ""
            echo "Remote Control connects claude.ai/code or the Claude mobile app"
            echo "to a local Claude Code session. Your session runs locally; the"
            echo "remote interface is just a window into it."
            echo ""
            echo "Quick start:"
            echo "  cc-rc              # Start session, get URL/QR code"
            echo "  cc-rc tmux         # Start in tmux window"
            echo "  cc-rc enable       # Auto-enable for all sessions"
            echo ""
            echo "See: https://code.claude.com/docs/en/remote-control"
    end
end
