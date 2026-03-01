# Fish completions for claude CLI
# FZF pickers for --resume and --agent are handled by _fifc_or_fzf.fish

# Disable file completions by default
complete -c claude -f

# --- Subcommands ---
complete -c claude -n __fish_is_first_token -a agents -d 'List configured agents'
complete -c claude -n __fish_is_first_token -a auth -d 'Manage authentication'
complete -c claude -n __fish_is_first_token -a doctor -d 'Check auto-updater health'
complete -c claude -n __fish_is_first_token -a install -d 'Install native build'
complete -c claude -n __fish_is_first_token -a mcp -d 'Configure MCP servers'
complete -c claude -n __fish_is_first_token -a plugin -d 'Manage plugins'
complete -c claude -n __fish_is_first_token -a setup-token -d 'Set up auth token'
complete -c claude -n __fish_is_first_token -a update -d 'Check for updates'
complete -c claude -n __fish_is_first_token -a upgrade -d 'Check for updates'

# --- Options ---

# Session management
complete -c claude -s r -l resume -x -d 'Resume conversation (session ID or picker)'
complete -c claude -s c -l continue -d 'Continue most recent conversation'
complete -c claude -l from-pr -x -d 'Resume session linked to PR'
complete -c claude -l session-id -x -d 'Use specific session UUID'
complete -c claude -l fork-session -d 'Create new session ID when resuming'
complete -c claude -l no-session-persistence -d 'Disable session persistence'

# Model and effort
complete -c claude -l model -x -a 'sonnet opus haiku' -d 'Model for session'
complete -c claude -l effort -x -a 'low medium high' -d 'Effort level'
complete -c claude -l fallback-model -x -a 'sonnet opus haiku' -d 'Fallback model when overloaded'

# Agent and tools
complete -c claude -l agent -x -d 'Agent for session'
complete -c claude -l agents -x -d 'JSON custom agent definitions'
complete -c claude -l allowedTools -l allowed-tools -x -d 'Tools to allow'
complete -c claude -l disallowedTools -l disallowed-tools -x -d 'Tools to deny'
complete -c claude -l tools -x -d 'Built-in tool list'

# Permissions
complete -c claude -l permission-mode -x -a 'acceptEdits bypassPermissions default dontAsk plan' -d 'Permission mode'
complete -c claude -l dangerously-skip-permissions -d 'Bypass all permission checks'
complete -c claude -l allow-dangerously-skip-permissions -d 'Enable skip-permissions option'

# I/O modes
complete -c claude -s p -l print -d 'Print response and exit'
complete -c claude -l output-format -x -a 'text json stream-json' -d 'Output format (with --print)'
complete -c claude -l input-format -x -a 'text stream-json' -d 'Input format (with --print)'
complete -c claude -l include-partial-messages -d 'Include partial message chunks'
complete -c claude -l replay-user-messages -d 'Re-emit user messages on stdout'
complete -c claude -l json-schema -x -d 'JSON Schema for structured output'

# System prompt
complete -c claude -l system-prompt -x -d 'System prompt for session'
complete -c claude -l append-system-prompt -x -d 'Append to default system prompt'

# MCP configuration
complete -c claude -l mcp-config -r -d 'MCP server config files'
complete -c claude -l strict-mcp-config -d 'Only use MCP from --mcp-config'
complete -c claude -l mcp-debug -d 'MCP debug mode (deprecated, use --debug)'

# Settings and plugins
complete -c claude -l settings -r -d 'Settings JSON file or string'
complete -c claude -l setting-sources -x -a 'user project local' -d 'Setting sources to load'
complete -c claude -l plugin-dir -r -d 'Load plugins from directory'
complete -c claude -l disable-slash-commands -d 'Disable all skills'

# Directories and files
complete -c claude -l add-dir -r -d 'Additional directories for tool access'
complete -c claude -l file -x -d 'File resources (file_id:path)'

# Debugging
complete -c claude -s d -l debug -d 'Enable debug mode'
complete -c claude -l debug-file -r -d 'Write debug logs to file'
complete -c claude -l verbose -d 'Override verbose mode'

# Budget
complete -c claude -l max-budget-usd -x -d 'Max dollar spend (with --print)'

# API
complete -c claude -l betas -x -d 'Beta headers for API requests'

# Worktree and tmux
complete -c claude -s w -l worktree -d 'Create git worktree for session'
complete -c claude -l tmux -d 'Create tmux session for worktree'

# Chrome
complete -c claude -l chrome -d 'Enable Chrome integration'
complete -c claude -l no-chrome -d 'Disable Chrome integration'

# IDE
complete -c claude -l ide -d 'Connect to IDE on startup'

# General
complete -c claude -s h -l help -d 'Show help'
complete -c claude -s v -l version -d 'Show version'
