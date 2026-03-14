# Fish completions for aimux
complete -c aimux -f

# Subcommands
complete -c aimux -n __fish_use_subcommand -a new -d "Create workspace"
complete -c aimux -n __fish_use_subcommand -a status -d "Show workspaces"
complete -c aimux -n __fish_use_subcommand -a run -d "Execute ticket"
complete -c aimux -n __fish_use_subcommand -a attach -d "Attach to workspace"
complete -c aimux -n __fish_use_subcommand -a kill -d "Kill workspace"
complete -c aimux -n __fish_use_subcommand -a doctor -d "Health check"
complete -c aimux -n __fish_use_subcommand -a queue -d "Queue management"
complete -c aimux -n __fish_use_subcommand -a notify -d "Send notification"
complete -c aimux -n __fish_use_subcommand -a daemon -d "Agent daemon"
complete -c aimux -n __fish_use_subcommand -a version -d "Show version"
complete -c aimux -n __fish_use_subcommand -a help -d "Show help"

# new subcommand
complete -c aimux -n "__fish_seen_subcommand_from new" -s n -l new -d "Create new branch"
complete -c aimux -n "__fish_seen_subcommand_from new" -s e -l exec -d "Enter container shell"
complete -c aimux -n "__fish_seen_subcommand_from new" -l no-devcon -d "Skip devcontainer"
complete -c aimux -n "__fish_seen_subcommand_from new" -s m -l mount -d "Additional mount" -rF
complete -c aimux -n "__fish_seen_subcommand_from new" -s r -l rebuild -d "Rebuild devcontainer"
complete -c aimux -n "__fish_seen_subcommand_from new" -s f -l fast -d "Skip lifecycle hooks"
complete -c aimux -n "__fish_seen_subcommand_from new" -s F -l features -d "Devcontainer features" -r

# kill subcommand
complete -c aimux -n "__fish_seen_subcommand_from kill" -s f -l force -d "Force kill"

# run subcommand
complete -c aimux -n "__fish_seen_subcommand_from run" -l max -d "Max iterations" -r
complete -c aimux -n "__fish_seen_subcommand_from run" -l provider -d "AI provider" -ra "claude codex"
complete -c aimux -n "__fish_seen_subcommand_from run" -l command -d "Slash command" -r
complete -c aimux -n "__fish_seen_subcommand_from run" -l no-devcon -d "Skip devcontainer"
complete -c aimux -n "__fish_seen_subcommand_from run" -s m -l mount -d "Additional mount" -rF

# daemon subcommand
complete -c aimux -n "__fish_seen_subcommand_from daemon" -a "start stop status poll"

# notify subcommand
complete -c aimux -n "__fish_seen_subcommand_from notify" -l bell -d "Terminal bell"
complete -c aimux -n "__fish_seen_subcommand_from notify" -l osc -d "OSC escape sequences"
complete -c aimux -n "__fish_seen_subcommand_from notify" -l native -d "OS notifications"
complete -c aimux -n "__fish_seen_subcommand_from notify" -l webhook -d "Webhook notification"
complete -c aimux -n "__fish_seen_subcommand_from notify" -l all -d "All channels"
complete -c aimux -n "__fish_seen_subcommand_from notify" -s t -l title -d "Notification title" -r

# queue subcommand
complete -c aimux -n "__fish_seen_subcommand_from queue" -a "add list start stop status help"
