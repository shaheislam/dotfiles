# Completions for codex-accounts
complete -c codex-accounts -f

# Subcommands
complete -c codex-accounts -n __fish_use_subcommand -a add -d "Enroll a new account"
complete -c codex-accounts -n __fish_use_subcommand -a remove -d "Remove an enrolled account"
complete -c codex-accounts -n __fish_use_subcommand -a rm -d "Remove an enrolled account"
complete -c codex-accounts -n __fish_use_subcommand -a list -d "Show all enrolled accounts"
complete -c codex-accounts -n __fish_use_subcommand -a ls -d "Show all enrolled accounts"
complete -c codex-accounts -n __fish_use_subcommand -a status -d "Show rotation state"

# For remove: complete with enrolled account names
complete -c codex-accounts -n "__fish_seen_subcommand_from remove rm" -a "(cat ~/.codex/accounts/.accounts 2>/dev/null)"
