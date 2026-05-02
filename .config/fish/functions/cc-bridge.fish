function cc-bridge --description "Manage Neovim agent bridge"
    set -l cmd $argv[1]
    set -l bridge_dir /tmp/nvim-claude-bridge

    switch "$cmd"
        case status ''
            echo "Neovim Agent Bridge Status"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            if not test -d $bridge_dir
                echo "No bridge directory found. Is Neovim running?"
                return 0
            end

            set -l now (date +%s)
            set -l found 0

            for dir in $bridge_dir/*/
                test -d "$dir"; or continue
                set -l state "$dir/state.json"
                test -f "$state"; or continue
                set found (math $found + 1)

                set -l project (jq -r '.project // "unknown"' "$state" 2>/dev/null)
                set -l pid (jq -r '.nvim_pid // "?"' "$state" 2>/dev/null)

                # Check if PID is alive
                set -l alive dead
                if test "$pid" != "?"; and kill -0 $pid 2>/dev/null
                    set alive alive
                end

                echo ""
                printf "Project: %s (PID %s, %s)\n" "$project" "$pid" "$alive"

                # Per-section freshness
                for section in diagnostics focus git_hunks tests
                    set -l ts (jq -r ".$section.timestamp // 0" "$state" 2>/dev/null)
                    if test "$ts" -gt 0
                        set -l age (math $now - $ts)
                        if test $age -lt 60
                            printf "  %-15s \033[32m%ds ago\033[0m\n" "$section" $age
                        else if test $age -lt 300
                            printf "  %-15s \033[33m%dm ago\033[0m\n" "$section" (math "floor($age / 60)")
                        else
                            printf "  %-15s \033[31mstale (%dm)\033[0m\n" "$section" (math "floor($age / 60)")
                        end
                    else
                        printf "  %-15s \033[90m—\033[0m\n" "$section"
                    end
                end
            end

            if test $found -eq 0
                echo "No active bridges found."
            end

        case cat
            if not test -d $bridge_dir
                echo "No bridge directory found."
                return 1
            end

            for dir in $bridge_dir/*/
                set -l state "$dir/state.json"
                if test -f "$state"
                    echo "--- $state ---"
                    jq . "$state" 2>/dev/null; or cat "$state"
                    echo ""
                end
            end

        case clean
            if not test -d $bridge_dir
                echo "Nothing to clean."
                return 0
            end

            set -l cleaned 0
            for dir in $bridge_dir/*/
                test -d "$dir"; or continue
                set -l state "$dir/state.json"
                test -f "$state"; or continue

                set -l pid (jq -r '.nvim_pid // empty' "$state" 2>/dev/null)
                if test -z "$pid"; or not kill -0 $pid 2>/dev/null
                    echo "Removing stale: $dir"
                    rm -rf "$dir"
                    set cleaned (math $cleaned + 1)
                end
            end

            echo "Cleaned $cleaned stale bridge(s)."

        case help '*'
            echo "Usage: cc-bridge <command>"
            echo ""
            echo "Commands:"
            echo "  status   Show bridge state and per-section freshness (default)"
            echo "  cat      Pretty-print current state.json"
            echo "  clean    Remove stale bridge dirs (dead Neovim PIDs)"
            echo "  help     Show this help"
            echo ""
            echo "The bridge connects Neovim editor state to agent harnesses."
            echo "Neovim writes diagnostics, focus, git hunks, and test results"
            echo "to /tmp/nvim-claude-bridge/<hash>/state.json."
            echo "Claude Code reads it via UserPromptSubmit; OpenCode reads it via claude-compat.ts."
            echo ""
            echo "See: docs/nvim-claude-bridge.md"
    end
end
