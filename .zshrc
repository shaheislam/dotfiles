KEYTIMEOUT=500

# Initialize Starship prompt
eval "$(starship init zsh)"

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set plugins
plugins=(
  git
  zsh-completions
  fzf-tab
  zsh-kubectl-prompt
  docker-zsh-completion
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-history-substring-search
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Environment Variables
export BAT_THEME=tokyonight_night
export STARSHIP_CONFIG=$HOME/.config/starship.toml
export PYTHONPATH=/opt/homebrew/lib/python3.12/site-packages
export EDITOR=nvim
export VISUAL=nvim
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Paths
export PATH="/opt/homebrew/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PATH="$HOME/.cargo/env:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

# Add VSCode bin to PATH
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# Initialize tools
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# Atuin with custom FZF integration
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"

# Source custom FZF-Atuin integration
if [[ -f "$HOME/.config/zsh/atuin-fzf.zsh" ]]; then
    source "$HOME/.config/zsh/atuin-fzf.zsh"
fi

# Source asdf
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

# Source fzf-git.sh
if [ -f "$HOME/fzf-git.sh/fzf-git.sh" ]; then
  source "$HOME/fzf-git.sh/fzf-git.sh"
fi

# FZF configuration
source <(fzf --zsh)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Enhanced FZF configuration (prefer rg over fd)
if command -v rg > /dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files'
    export FZF_DEFAULT_OPTS='-m --height 50% --border'
else
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# FZF theme
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# Aliases
alias python=python3
alias mkdir="mkdir -p"
# Use z for zoxide navigation (cd is kept as default)
alias ls="eza"
alias la="eza -al"
alias l="eza -hal"
alias cat="bat"
alias k="kubectl"
alias kubectl=kubecolor
alias vi=nvim
alias vim=nvim
alias n=nvim
alias lg=lazygit
alias ld=lazydocker
alias fixterm="stty sane"

# Obsidian Aliases
alias obs="cd '/Users/shaheislam/Library/Mobile Documents/iCloud~md~obsidian/Documents/Engineering'"

# Kubernetes aliases
alias kctx="kubie ctx"
alias kns="kubie ns"

# GitHub Gist aliases
alias gispub="gis"
alias gispriv="gh gist create"
alias gisls="gh gist list"
alias gisdel="gh gist delete"

# Utility aliases
alias wea="curl --silent wttr.in/Didsbury_uk | grep -v Follow"
alias save="~/sesh.sh save"
alias rest="~/sesh.sh restore"
alias tr="clear; tmux new -A -s main \; run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
alias ts="tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/save.sh"
alias tk="tmux kill-server"

# Git worktree aliases
alias gwta="git worktree add"
alias gwtab="git worktree add -b"
alias gwtl="git worktree list"
alias gwtr="git worktree remove"
alias gwtp="git worktree prune"
alias gwtm="git worktree move"

# thefuck
if command -v thefuck > /dev/null 2>&1; then
  eval $(thefuck --alias)
fi

# VSCode is available via PATH (see line 35-38)

# Functions from Fish config
function gis() {
    if [ -n "$1" ]; then
        gh gist create -p "$1" | grep https | tee >(pbcopy)
    else
        gisls
    fi
}

function ssmc() {
    local profile=${1:-petlab}
    echo "Fetching instances from AWS..."
    
    # Get instances with their names and IDs, only running instances
    local instances=$(aws ec2 describe-instances \
        --profile "$profile" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,LaunchTime]' \
        --output text 2>/dev/null)
    
    if [ -z "$instances" ]; then
        echo "No running instances found or AWS CLI error"
        return 1
    fi
    
    # Format for fzf: "Name (InstanceType) - InstanceId"
    local formatted_instances=""
    while IFS=$'\t' read -r name instance_id instance_type launch_time; do
        # Handle instances without Name tag
        if [ "$name" = "None" ] || [ -z "$name" ]; then
            name="Unnamed"
        fi
        formatted_instances+="$name ($instance_type) - $instance_id"$'\n'
    done <<< "$instances"
    
    # Use fzf to select instance
    local selection=$(echo "$formatted_instances" | fzf --prompt="Select EC2 instance: " --height=40% --border)
    
    if [ -n "$selection" ]; then
        # Extract instance ID from selection (everything after the last " - ")
        local instance_id=$(echo "$selection" | grep -o 'i-[a-f0-9]*$')
        
        if [ -n "$instance_id" ]; then
            echo "Connecting to instance: $instance_id with profile: $profile"
            aws ssm start-session --target "$instance_id" --profile "$profile"
        else
            echo "Failed to extract instance ID from selection"
            return 1
        fi
    else
        echo "No instance selected"
        return 1
    fi
}

function f() {
    vim "$(fzf)"
}

function gx() {
    git branch --list | grep -v "^[ *]*main$" | xargs git branch -d
}

function e() {
    ls -hal | nms -as
}

function tb() {
    nc termbin.com 9999 | pbcopy
}

# Tmux function with correct TERM
function tmux() {
    env TERM=xterm-256color /opt/homebrew/bin/tmux "$@"
}

# AWS SSO function (enhanced version)
function aws-sso() {
    local profile=${1:-petlab}
    aws sso login --profile "$profile"
    eval "$(aws configure export-credentials --profile "$profile" --format env)"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_PROFILE="$profile"
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "Failed to get credentials"
    fi
}

# Git worktree functions
function gwtaf() {
    # Add worktree in ../repo-name-branch format
    local branch=$1
    local repo=$(basename $(git rev-parse --show-toplevel))
    git worktree add ../$repo-$branch $branch
}

function gwtabf() {
    # Create branch + worktree in ../repo-name-branch format
    local branch=$1
    local repo=$(basename $(git rev-parse --show-toplevel))
    git worktree add -b $branch ../$repo-$branch
}

