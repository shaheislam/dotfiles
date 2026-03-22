# Fish completions for gwt-ticket / gwtt
# FZF multiselect picker for --skill is handled by _gwt_ticket_fzf_tab_complete

# Disable file completions by default
complete -c gwt-ticket -f
complete -c gwtt -f

# Subcommands
complete -c gwt-ticket -n __fish_is_first_token -a --plan -d 'Orchestrate multiple gwtt runs as a convoy'
complete -c gwt-ticket -n __fish_is_first_token -a --status -d 'Show worktree/agent status'
complete -c gwt-ticket -n __fish_is_first_token -a --queue -d 'Manage ticket queue'

# Options
complete -c gwt-ticket -l help -s h -d 'Show help'
complete -c gwt-ticket -l max -x -d 'Max iterations (default: 20)'
complete -c gwt-ticket -l max-turns -x -d 'Max agentic turns per Claude session (budget cap)'
complete -c gwt-ticket -l max-budget -x -d 'Max API spend in USD (e.g., 5.00)'
complete -c gwt-ticket -l command -x -d 'Slash command (default: /ralph-wiggum:ralph-loop)'
complete -c gwt-ticket -l prompt-template -r -d 'Custom prompt template file'
complete -c gwt-ticket -l prompt-prefix -x -d 'Text to prepend to prompt'
complete -c gwt-ticket -l prompt-suffix -x -d 'Text to append to prompt'
complete -c gwt-ticket -l skill -x -d 'Invoke skill(s) at start of prompt'
complete -c gwt-ticket -l sub -x -d 'Claude subscription profile'
complete -c gwt-ticket -l provider -x -a 'bedrock vertex foundry gateway' -d 'API provider profile'
complete -c gwt-ticket -l local -d 'Use local Ollama model'
complete -c gwt-ticket -l model -x -d 'Use specific Ollama model'
complete -c gwt-ticket -l mount -s m -r -d 'Add directory mount (repeatable)'
complete -c gwt-ticket -l session -x -d 'Tmux session name'
complete -c gwt-ticket -l devcon -d 'Use devcontainer for isolation'
complete -c gwt-ticket -l system -x -a 'linear jira' -d 'Ticketing system'
complete -c gwt-ticket -l template -s t -x -a 'implement bugfix refactor test' -d 'Workflow template'
complete -c gwt-ticket -l bridge -d 'Enable cross-provider reasoning bridge'
complete -c gwt-ticket -l bridge-providers -x -d 'Comma-separated provider order'
complete -c gwt-ticket -l bridge-mode -x -a 'review redteam steelman assumptions' -d 'Bridge review mode'
complete -c gwt-ticket -l bridge-verbose -d 'Verbose bridge logging'
complete -c gwt-ticket -l bridge-model -x -d 'Model override for first provider'
complete -c gwt-ticket -l bridge-models -x -d 'Per-provider model map'
complete -c gwt-ticket -l bridge-timeout -x -d 'Per-provider timeout in seconds'
complete -c gwt-ticket -l bridge-log -r -d 'Log bridge reviews to file'
complete -c gwt-ticket -l bridge-dry-run -d 'Show bridge config without calling providers'
complete -c gwt-ticket -l bridge-cooldown -x -d 'Cooldown seconds after rate limit'
complete -c gwt-ticket -l bridge-profiles -x -d 'Claude subscription profiles for rotation'
complete -c gwt-ticket -l bridge-codex-profiles -x -d 'Codex profiles for rotation'
complete -c gwt-ticket -l codex -d 'Use Codex CLI as primary agent'
complete -c gwt-ticket -l codex-model -x -a 'o3 gpt-5.4 gpt-5.3-codex gpt-4.1' -d 'Codex model override'
complete -c gwt-ticket -l codex-profile -x -a 'auto safe fast local' -d 'Codex config.toml profile'
complete -c gwt-ticket -l rebase -d 'Rebase onto main before merging'
complete -c gwt-ticket -l auto-cleanup -d 'Auto-remove worktree after merge'
complete -c gwt-ticket -l no-auto-cleanup -d 'Keep worktree after merge'
complete -c gwt-ticket -l convoy -x -d 'Associate with a convoy'
complete -c gwt-ticket -l molecule -x -d 'Create/attach molecule workflow'
complete -c gwt-ticket -l town -d 'Enable town-level bead sync'
complete -c gwt-ticket -l no-town -d 'Disable town-level bead sync'
complete -c gwt-ticket -l mayor -d 'Register with mayor for tracking'
complete -c gwt-ticket -l no-mayor -d 'Disable mayor registration'
complete -c gwt-ticket -l gate -x -a 'ci-pipeline pr-review human-input dependency bd-bead' -d 'Create phase gate'
complete -c gwt-ticket -l gate-dep -r -d 'Dependency worktree for --gate dependency'
complete -c gwt-ticket -l no-checkpoints -d 'Disable checkpoint integration'
complete -c gwt-ticket -l ckpt-agent -x -a 'claude-code gemini opencode' -d 'Checkpoint agent type'
complete -c gwt-ticket -l swarm-epic -x -d 'Create bd swarm from epic bead ID'
complete -c gwt-ticket -l quiet -s q -d 'Suppress verbose output'
complete -c gwt-ticket -l verbose -s v -d 'Show full verbose output'

# Copy all completions to gwtt alias
complete -c gwtt -w gwt-ticket
