# Fish completions for SonarQube CLI (sonar)
# https://github.com/SonarSource/sonarqube-cli

# Disable file completions by default
complete -c sonar -f

# Top-level commands
complete -c sonar -n __fish_use_subcommand -a auth -d 'Manage authentication tokens and credentials'
complete -c sonar -n __fish_use_subcommand -a install -d 'Install Sonar tools'
complete -c sonar -n __fish_use_subcommand -a integrate -d 'Setup SonarQube integration for AI coding agents and git'
complete -c sonar -n __fish_use_subcommand -a list -d 'List Sonar resources'
complete -c sonar -n __fish_use_subcommand -a analyze -d 'Analyze code for security issues'
complete -c sonar -n __fish_use_subcommand -a config -d 'Configure CLI settings'

# auth subcommands
complete -c sonar -n '__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout purge status' -a login -d 'Save authentication token to keychain'
complete -c sonar -n '__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout purge status' -a logout -d 'Remove authentication token from keychain'
complete -c sonar -n '__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout purge status' -a purge -d 'Remove all authentication tokens from keychain'
complete -c sonar -n '__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout purge status' -a status -d 'Show active authentication connection'

# auth login options
complete -c sonar -n '__fish_seen_subcommand_from login' -s s -l server -d 'SonarQube URL'
complete -c sonar -n '__fish_seen_subcommand_from login' -s o -l org -d 'SonarQube Cloud organization key'
complete -c sonar -n '__fish_seen_subcommand_from login' -s t -l with-token -d 'Token value (non-interactive)'

# auth logout options
complete -c sonar -n '__fish_seen_subcommand_from logout' -s s -l server -d 'SonarQube server URL'
complete -c sonar -n '__fish_seen_subcommand_from logout' -s o -l org -d 'SonarQube Cloud organization key'

# install subcommands
complete -c sonar -n '__fish_seen_subcommand_from install; and not __fish_seen_subcommand_from secrets' -a secrets -d 'Install sonar-secrets binary'

# install secrets options
complete -c sonar -n '__fish_seen_subcommand_from secrets' -l force -d 'Force reinstall'
complete -c sonar -n '__fish_seen_subcommand_from secrets' -l status -d 'Check installation status'

# integrate subcommands
complete -c sonar -n '__fish_seen_subcommand_from integrate; and not __fish_seen_subcommand_from claude' -a claude -d 'Setup SonarQube integration for Claude Code'

# integrate claude options
complete -c sonar -n '__fish_seen_subcommand_from claude' -s s -l server -d 'SonarQube server URL'
complete -c sonar -n '__fish_seen_subcommand_from claude' -s p -l project -d 'Project key'
complete -c sonar -n '__fish_seen_subcommand_from claude' -s t -l token -d 'Authentication token'
complete -c sonar -n '__fish_seen_subcommand_from claude' -s o -l org -d 'Organization key'
complete -c sonar -n '__fish_seen_subcommand_from claude' -s g -l global -d 'Install globally to ~/.claude'
complete -c sonar -n '__fish_seen_subcommand_from claude' -l non-interactive -d 'Non-interactive mode'

# list subcommands
complete -c sonar -n '__fish_seen_subcommand_from list; and not __fish_seen_subcommand_from issues projects' -a issues -d 'Search for issues in SonarQube'
complete -c sonar -n '__fish_seen_subcommand_from list; and not __fish_seen_subcommand_from issues projects' -a projects -d 'Search for projects in SonarQube'

# list issues options
complete -c sonar -n '__fish_seen_subcommand_from issues' -s p -l project -d 'Project key'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l severity -d 'Filter by severity'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l format -d 'Output format' -a 'json toon'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l branch -d 'Branch name'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l pull-request -d 'Pull request ID'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l page-size -d 'Page size (1-500)'
complete -c sonar -n '__fish_seen_subcommand_from issues' -l page -d 'Page number'

# list projects options
complete -c sonar -n '__fish_seen_subcommand_from projects' -s q -l query -d 'Search query'
complete -c sonar -n '__fish_seen_subcommand_from projects' -l page -d 'Page number'
complete -c sonar -n '__fish_seen_subcommand_from projects' -l page-size -d 'Page size (1-500)'

# analyze subcommands
complete -c sonar -n '__fish_seen_subcommand_from analyze; and not __fish_seen_subcommand_from secrets' -a secrets -d 'Scan for hardcoded secrets'

# analyze secrets options
complete -c sonar -n '__fish_seen_subcommand_from analyze; and __fish_seen_subcommand_from secrets' -l file -d 'File path to scan' -F
complete -c sonar -n '__fish_seen_subcommand_from analyze; and __fish_seen_subcommand_from secrets' -l stdin -d 'Read from standard input'

# config subcommands
complete -c sonar -n '__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from telemetry' -a telemetry -d 'Configure telemetry settings'

# config telemetry options
complete -c sonar -n '__fish_seen_subcommand_from telemetry' -l enabled -d 'Enable anonymous usage statistics'
complete -c sonar -n '__fish_seen_subcommand_from telemetry' -l disabled -d 'Disable anonymous usage statistics'
