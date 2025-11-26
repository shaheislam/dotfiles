# Fish Shell Plugins and Completions Configuration
# Replaces Oh My Zsh plugins functionality

# Git abbreviations (replaces git plugin from Oh My Zsh)
if command -v git >/dev/null
    # Common git abbreviations
    abbr -a g git
    abbr -a ga 'git add'
    abbr -a gaa 'git add --all'
    abbr -a gb 'git branch'
    abbr -a gba 'git branch -a'
    abbr -a gc 'git commit -v'
    abbr -a gca 'git commit -v -a'
    abbr -a gcam 'git commit -a -m'
    abbr -a gcm 'git commit -m'
    abbr -a gco 'git checkout'
    abbr -a gcb 'git checkout -b'
    abbr -a gd 'git diff'
    abbr -a gf 'git fetch'
    abbr -a gl 'git pull'
    abbr -a glog 'git log --oneline --decorate --graph'
    abbr -a gp 'git push'
    abbr -a gst 'git status'
    abbr -a gsta 'git stash'
    abbr -a gstp 'git stash pop'
end

# Docker completions (Fish has built-in docker completions)
# Kubectl completions (replaces zsh-kubectl-prompt)
# NOTE: Using custom FZF completions from kubectl-simple.fish + kubectl_fzf_native.fish
# which leverage native __fish_kubectl_* functions. DO NOT source kubectl's Go-based
# completions here as they conflict with the FZF integration.
if command -v kubectl >/dev/null
    # kubectl completion fish | source  # Disabled - conflicts with FZF completions

    # Kubectl abbreviations
    abbr -a kgp 'kubectl get pods'
    abbr -a kgs 'kubectl get services'
    abbr -a kgd 'kubectl get deployments'
    abbr -a kaf 'kubectl apply -f'
    abbr -a kdel 'kubectl delete'
    abbr -a klog 'kubectl logs'
    abbr -a kexec 'kubectl exec -it'
end

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
if command -v fzf >/dev/null
    # Set up fzf key bindings
    set -g FZF_CTRL_T_OPTS "--preview 'bat --color=always --line-range=:50 {}'"
    set -g FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"

    # Custom fzf functions
    function fzf_select_history
        history | fzf --query=(commandline) | read -l result
        and commandline $result
    end

    # Bind to Ctrl+R for history search
    bind \cr fzf_select_history

    # =============================================================================
    # Git+FZF Integration
    # =============================================================================
    # Git functionality is now provided by fzf-git.sh (loaded via conf.d/fzf-git.fish)
    # Use CTRL-G keybindings:
    #   CTRL-G CTRL-F - Files
    #   CTRL-G CTRL-B - Branches
    #   CTRL-G CTRL-T - Tags
    #   CTRL-G CTRL-R - Remotes
    #   CTRL-G CTRL-H - Commit Hashes
    #   CTRL-G CTRL-S - Stashes
    #   CTRL-G CTRL-L - Reflogs
    #   CTRL-G CTRL-W - Worktrees
    #
    # Tab completion is also available for git commands:
    #   git add <TAB>, git checkout <TAB>, git merge <TAB>, etc.
    # =============================================================================
end
