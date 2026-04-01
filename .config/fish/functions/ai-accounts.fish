function ai-accounts --description "Unified view of Codex + OpenCode account profiles"
    set -l subcmd $argv[1]

    switch "$subcmd"
        case sync
            echo "Syncing accounts between Codex and OpenCode..."
            _ai_accounts_sync all

        case list ls
            echo "=== Codex CLI Accounts ==="
            codex-accounts list 2>/dev/null; or echo "  (none)"
            echo ""
            echo "=== OpenCode Accounts ==="
            opencode-accounts list 2>/dev/null; or echo "  (none)"

        case status
            echo "=== Codex CLI ==="
            codex-accounts status 2>/dev/null; or echo "  (no accounts)"
            echo ""
            echo "=== OpenCode ==="
            opencode-accounts status 2>/dev/null; or echo "  (no accounts)"

        case help --help -h ''
            echo "Usage: ai-accounts <command>"
            echo ""
            echo "Commands:"
            echo "  sync      Bidirectional sync between Codex and OpenCode profiles"
            echo "  list      Show all accounts from both systems"
            echo "  status    Show rotation state for both systems"
            echo ""
            echo "Per-system management:"
            echo "  codex-accounts <command>      Codex CLI accounts"
            echo "  opencode-accounts <command>   OpenCode accounts"
            echo ""
            echo "Cross-sync happens automatically on add/capture/remove."
            echo "Set AI_ACCOUNTS_NO_SYNC=1 to disable."

        case '*'
            echo "Unknown command: $subcmd (try 'ai-accounts help')" >&2
            return 1
    end
end
