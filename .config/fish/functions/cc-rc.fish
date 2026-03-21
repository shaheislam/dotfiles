function cc-rc --description "Manage Claude Code Remote Control sessions"
    set -l cmd $argv[1]

    switch "$cmd"
        case start ''
            # Start a dedicated remote control server in the current directory
            set -l rc_args
            if contains -- --verbose $argv
                set -a rc_args --verbose
            end
            if contains -- --sandbox $argv
                set -a rc_args --sandbox
            end
            if contains -- --name $argv
                set -l name_idx (contains -i -- --name $argv)
                set -l name_val_idx (math $name_idx + 1)
                if test $name_val_idx -le (count $argv)
                    set -a rc_args --name $argv[$name_val_idx]
                end
            end

            echo "Starting Remote Control server..."
            echo "  Directory: "(pwd)
            echo "  Press spacebar to show QR code"
            echo "  Open claude.ai/code or Claude mobile app to connect"
            echo ""
            claude remote-control $rc_args

        case interactive
            # Start an interactive session with remote control enabled via --remote-control flag
            set -l rc_args --remote-control
            set -l remaining_args
            for i in (seq 2 (count $argv))
                set -l arg $argv[$i]
                switch $arg
                    case --verbose --sandbox --no-sandbox --dangerously-skip-permissions
                        set -a rc_args $arg
                    case --effort --name --add-dir --model
                        set -a rc_args $arg
                        set -l next_i (math $i + 1)
                        if test $next_i -le (count $argv)
                            set -a rc_args $argv[$next_i]
                        end
                    case '*'
                        set -a remaining_args $arg
                end
            end

            echo "Starting interactive session with Remote Control..."
            echo "  Directory: "(pwd)
            echo "  Session is locally interactive AND remotely accessible"
            echo ""
            claude $rc_args $remaining_args

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
                        echo "✓ Remote Control: enabled for all sessions (config)"
                    else if test "$rc_enabled" = false
                        echo "⚠ Remote Control: disabled in config (use --remote-control flag or cc-rc enable)"
                    else
                        echo "⚠ Remote Control: not configured (use --remote-control flag or cc-rc enable)"
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
            echo "Launch methods:"
            echo "  Flag:   claude --remote-control        (deterministic, per-session)"
            echo "  Config: enableRemoteControl in ~/.claude.json (all sessions)"
            echo "  Server: claude remote-control           (dedicated server mode)"
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
            echo "  start         Start Remote Control server (default)"
            echo "  interactive   Start interactive session with --remote-control flag"
            echo "  status        Show Remote Control configuration"
            echo "  enable        Enable Remote Control for all sessions (config)"
            echo "  disable       Disable Remote Control for all sessions (config)"
            echo "  tmux          Start Remote Control server in a new tmux window"
            echo "  help          Show this help"
            echo ""
            echo "Options (for start/interactive):"
            echo "  --verbose   Show detailed connection logs"
            echo "  --sandbox   Enable filesystem/network sandboxing"
            echo "  --name      Set session name"
            echo ""
            echo "Modes:"
            echo "  Server mode (cc-rc start / claude remote-control):"
            echo "    Dedicated server waiting for remote connections."
            echo "    No local interactive terminal."
            echo ""
            echo "  Interactive mode (cc-rc interactive / claude --remote-control):"
            echo "    Full local terminal + remote access. Deterministic."
            echo "    Used by gwt-ticket, gwt-parallel for automated workflows."
            echo ""
            echo "  Config mode (cc-rc enable / enableRemoteControl in ~/.claude.json):"
            echo "    All sessions auto-enable remote control."
            echo ""
            echo "Quick start:"
            echo "  cc-rc                    # Start server, get URL/QR code"
            echo "  cc-rc interactive        # Interactive + remote control"
            echo "  cc-rc enable             # Auto-enable for all sessions"
            echo ""
            echo "See: https://code.claude.com/docs/en/remote-control"
    end
end
