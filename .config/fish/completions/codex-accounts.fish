# Completions for codex-accounts
complete -c codex-accounts -f

# Subcommands
complete -c codex-accounts -n __fish_use_subcommand -a add -d "Enroll a new account"
complete -c codex-accounts -n __fish_use_subcommand -a remove -d "Remove an enrolled account"
complete -c codex-accounts -n __fish_use_subcommand -a rm -d "Remove an enrolled account"
complete -c codex-accounts -n __fish_use_subcommand -a list -d "Show all enrolled accounts"
complete -c codex-accounts -n __fish_use_subcommand -a ls -d "Show all enrolled accounts"
complete -c codex-accounts -n __fish_use_subcommand -a status -d "Show rotation state"
complete -c codex-accounts -n __fish_use_subcommand -a 1p-push -d "Push account to 1Password"
complete -c codex-accounts -n __fish_use_subcommand -a 1p-pull -d "Pull account(s) from 1Password"
complete -c codex-accounts -n __fish_use_subcommand -a 1p-list -d "List accounts in 1Password"
complete -c codex-accounts -n __fish_use_subcommand -a 1p-sync -d "Local-first sync (push local, pull remote-only)"

# For remove: complete with enrolled account names
complete -c codex-accounts -n "__fish_seen_subcommand_from remove rm" -a "(cat ~/.codex/accounts/.accounts 2>/dev/null)"

# For 1p-push: complete with enrolled account names
complete -c codex-accounts -n "__fish_seen_subcommand_from 1p-push" -a "(cat ~/.codex/accounts/.accounts 2>/dev/null)"

# For 1p-pull: complete with enrolled account names (for pulling specific ones)
complete -c codex-accounts -n "__fish_seen_subcommand_from 1p-pull" -a "(cat ~/.codex/accounts/.accounts 2>/dev/null)"

# --vault option for 1Password commands
complete -c codex-accounts -n "__fish_seen_subcommand_from 1p-push 1p-pull 1p-list 1p-sync" -l vault -d "1Password vault" -xa "(op vault list --format=json 2>/dev/null | python3 -c 'import json,sys;[print(v[\"name\"]) for v in json.load(sys.stdin)]' 2>/dev/null)"

# --force option for 1Password commands with conflict detection
complete -c codex-accounts -n "__fish_seen_subcommand_from 1p-push 1p-pull 1p-sync" -l force -d "Overwrite on conflict"
