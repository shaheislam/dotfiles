# Docker FZF Tab Completion Integration
# Provides context-aware FZF completion for Docker commands
# Works alongside native Docker completions

# Enable FZF completion for docker commands when TAB is pressed
complete -c docker -f -n '__fish_seen_subcommand_from ps start stop restart kill pause unpause exec attach logs inspect stats top rm images rmi run pull push tag volume network compose container image' -a '(_docker_fzf_tab_complete)'
