# Completions for opencode-accounts
complete -c opencode-accounts -f

# Subcommands
complete -c opencode-accounts -n __fish_use_subcommand -a add -d "Enroll a new OpenAI account"
complete -c opencode-accounts -n __fish_use_subcommand -a capture -d "Capture current live auth"
complete -c opencode-accounts -n __fish_use_subcommand -a refresh -d "Alias for capture"
complete -c opencode-accounts -n __fish_use_subcommand -a remove -d "Remove an enrolled account"
complete -c opencode-accounts -n __fish_use_subcommand -a rm -d "Remove an enrolled account"
complete -c opencode-accounts -n __fish_use_subcommand -a list -d "Show all enrolled accounts"
complete -c opencode-accounts -n __fish_use_subcommand -a ls -d "Show all enrolled accounts"
complete -c opencode-accounts -n __fish_use_subcommand -a status -d "Show rotation state"
complete -c opencode-accounts -n __fish_use_subcommand -a switch -d "Activate a specific account"
complete -c opencode-accounts -n __fish_use_subcommand -a sw -d "Activate a specific account"
complete -c opencode-accounts -n __fish_use_subcommand -a check -d "Probe an account's availability"
complete -c opencode-accounts -n __fish_use_subcommand -a check-and-rotate -d "Auto-rotate to first available"
complete -c opencode-accounts -n __fish_use_subcommand -a login -d "Open OpenAI OAuth login"
complete -c opencode-accounts -n __fish_use_subcommand -a sync-codex -d "Sync profiles to Codex"
complete -c opencode-accounts -n __fish_use_subcommand -a help -d "Show help"

# Account name completions for subcommands that operate on existing accounts
complete -c opencode-accounts -n "__fish_seen_subcommand_from switch sw" -a "(cat ~/.opencode/accounts/.accounts 2>/dev/null)"
complete -c opencode-accounts -n "__fish_seen_subcommand_from remove rm" -a "(cat ~/.opencode/accounts/.accounts 2>/dev/null)"
complete -c opencode-accounts -n "__fish_seen_subcommand_from check" -a "(cat ~/.opencode/accounts/.accounts 2>/dev/null)"
complete -c opencode-accounts -n "__fish_seen_subcommand_from capture refresh" -a "(cat ~/.opencode/accounts/.accounts 2>/dev/null)"
