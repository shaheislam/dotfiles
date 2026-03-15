# Fish completions for aimux
complete -c aimux -f

# Subcommands
complete -c aimux -n __fish_use_subcommand -a new -d "Create workspace"
complete -c aimux -n __fish_use_subcommand -a status -d "Show workspaces"
complete -c aimux -n __fish_use_subcommand -a run -d "Execute ticket"
complete -c aimux -n __fish_use_subcommand -a attach -d "Attach to workspace"
complete -c aimux -n __fish_use_subcommand -a kill -d "Kill workspace"
complete -c aimux -n __fish_use_subcommand -a merge -d "Merge workspace to main"
complete -c aimux -n __fish_use_subcommand -a pr -d "Create GitHub PR"
complete -c aimux -n __fish_use_subcommand -a init -d "Interactive setup"
complete -c aimux -n __fish_use_subcommand -a doctor -d "Health check"
complete -c aimux -n __fish_use_subcommand -a queue -d "Queue management"
complete -c aimux -n __fish_use_subcommand -a notify -d "Send notification"
complete -c aimux -n __fish_use_subcommand -a log -d "View agent logs"
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
complete -c aimux -n "__fish_seen_subcommand_from run" -l provider -d "AI provider" -ra "claude codex ollama aider gemini opencode cline amp cursor copilot"
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

# log subcommand
complete -c aimux -n "__fish_seen_subcommand_from log" -s f -l follow -d "Follow log output"
complete -c aimux -n "__fish_seen_subcommand_from log" -s a -l all -d "Show all workspace logs"
complete -c aimux -n "__fish_seen_subcommand_from log" -l clear -d "Clear log files"

# merge subcommand
complete -c aimux -n "__fish_seen_subcommand_from merge" -l pr -d "Create PR instead of local merge"
complete -c aimux -n "__fish_seen_subcommand_from merge" -l squash -d "Squash commits"
complete -c aimux -n "__fish_seen_subcommand_from merge" -l message -d "Custom commit message" -r
complete -c aimux -n "__fish_seen_subcommand_from merge" -l delete -d "Delete workspace after merge"
complete -c aimux -n "__fish_seen_subcommand_from merge" -l no-delete -d "Keep workspace after merge"
complete -c aimux -n "__fish_seen_subcommand_from merge" -l dry-run -d "Preview without executing"

# pr subcommand
complete -c aimux -n "__fish_seen_subcommand_from pr" -s t -l title -d "PR title" -r
complete -c aimux -n "__fish_seen_subcommand_from pr" -s b -l body -d "PR body" -r
complete -c aimux -n "__fish_seen_subcommand_from pr" -s d -l draft -d "Create as draft PR"
complete -c aimux -n "__fish_seen_subcommand_from pr" -l base -d "Base branch" -r
complete -c aimux -n "__fish_seen_subcommand_from pr" -s r -l reviewer -d "Add reviewer" -r
complete -c aimux -n "__fish_seen_subcommand_from pr" -s l -l label -d "Add label" -r
complete -c aimux -n "__fish_seen_subcommand_from pr" -l delete -d "Delete workspace after PR"
complete -c aimux -n "__fish_seen_subcommand_from pr" -s o -l open -d "Open PR in browser"

# init subcommand
complete -c aimux -n "__fish_seen_subcommand_from init" -l force -d "Overwrite existing config"

# queue subcommand
complete -c aimux -n "__fish_seen_subcommand_from queue" -a "add list start stop status help"
