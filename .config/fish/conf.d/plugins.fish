# Fish Shell Plugins and Completions Configuration
# Replaces Oh My Zsh plugins functionality

# PERF: Abbreviations don't need type -q guards — they're just text expansions.
# Removing type -q saves ~25-45ms per call at startup. If the tool isn't installed,
# the expanded command simply shows "command not found" when used.

# Git abbreviations are provided by jhillyerd/plugin-git (conf.d/git.fish)
# which creates ~170 abbreviations. Do NOT duplicate them here.

# Kubectl abbreviations
abbr -a kgp 'kubectl get pods'
abbr -a kgs 'kubectl get services'
abbr -a kgd 'kubectl get deployments'
abbr -a kaf 'kubectl apply -f'
abbr -a kdel 'kubectl delete'
abbr -a klog 'kubectl logs'
abbr -a kexec 'kubectl exec -it'

# Enable Fish's built-in autosuggestions (replaces zsh-autosuggestions)
set -g fish_autosuggestion_enabled 1

# Enable Fish's built-in syntax highlighting (replaces zsh-syntax-highlighting)
set -g fish_color_command blue
set -g fish_color_param cyan
set -g fish_color_redirection yellow
set -g fish_color_comment brblack
set -g fish_color_error red
set -g fish_color_escape bryellow
set -g fish_color_operator green
set -g fish_color_quote yellow
set -g fish_color_autosuggestion brblack
set -g fish_color_valid_path --underline

# History substring search (Fish has this built-in with up/down arrows)
# Configure history search
set -g fish_history_search_case_sensitive 0

# FZF integration for better tab completion (replaces fzf-tab)
# PERF: FZF env vars are cheap to set unconditionally. Only the function definition
# and bind call need interactive mode, avoiding type -q fzf (~25-45ms savings).
set -g FZF_CTRL_T_OPTS "--preview 'bat --color=always --line-range=:50 {}'"
set -g FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"

if status is-interactive
    function fzf_select_history
        history | fzf --query=(commandline) | read -l result
        and commandline $result
    end

    # Bind to Ctrl+R for history search
    bind \cr fzf_select_history
end
