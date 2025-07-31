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
export PATH="$HOME/.cargo/bin:$PATH"
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

# S3grep wrapper to ensure AWS profile is used
function s3grep() {
    if [[ -z "$AWS_PROFILE" ]]; then
        echo "No AWS profile set. Run 'aws-sso <profile>' first."
        return 1
    fi
    command s3grep "$@"
}

# AWS Log Analysis Functions (Generic)

# Pretty print s3grep output for JSON logs
function s3-logs() {
    local bucket="$1"
    local pattern="$2"
    local prefix="$3"
    
    if [[ -z "$bucket" || -z "$pattern" ]]; then
        echo "Usage: s3-logs <bucket> <pattern> [prefix]"
        echo "Example: s3-logs my-log-bucket '\"eventName\":\"AssumeRole\"' logs/2024/01/"
        return 1
    fi
    
    local grep_args="--bucket $bucket --pattern $pattern"
    [[ -n "$prefix" ]] && grep_args="$grep_args --prefix $prefix"
    
    s3grep $grep_args 2>/dev/null | while IFS= read -r line; do
        # Split on .gz: to properly separate filepath from JSON
        if [[ "$line" =~ ^(.*)\.gz:(.*)$ ]]; then
            local filepath="${BASH_REMATCH[1]}.gz"
            local json="${BASH_REMATCH[2]}"
            local filename=$(basename "$filepath")
            
            echo "📄 File: $filename"
            echo "$json" | jq '.' 2>/dev/null || {
                echo "Raw content (jq failed):"
                echo "$json" | head -c 500
                echo "..."
            }
            echo "═══════════════════════════════════════════════════════════════"
        else
            echo "Unparsed line: $line"
        fi
    done
}

# Generic GuardDuty log viewer
function gd-view() {
    local bucket="$1"
    local pattern="${2:-\"severity\":}"
    local prefix="$3"
    
    if [[ -z "$bucket" ]]; then
        echo "Usage: gd-view <bucket> [pattern] [prefix]"
        echo "Example: gd-view my-guardduty-bucket '\"severity\":[5-9]' AWSLogs/123456/GuardDuty/"
        return 1
    fi
    
    s3-logs "$bucket" "$pattern" "$prefix" | while read -r line; do
        if [[ "$line" == "📄 File:"* ]]; then
            echo "$line"
        elif [[ "$line" == "═"* ]]; then
            echo "$line"
        else
            echo "$line" | jq -r 'select(.type != null) | 
                "🔍 \(.type)
                📊 Severity: \(.severity) | \(.title // "No title")
                👤 Resource: \(.resource.resourceType // "Unknown")
                🌍 Region: \(.region // "Unknown")
                🕐 Time: \(.createdAt // .updatedAt // "Unknown")
                📝 \(.description // "No description")"' 2>/dev/null || echo "$line"
        fi
    done
}

# Generic CloudTrail log viewer
function ct-view() {
    local bucket="$1"
    local pattern="${2:-.}"
    local prefix="$3"
    
    if [[ -z "$bucket" ]]; then
        echo "Usage: ct-view <bucket> [pattern] [prefix]"
        echo "Example: ct-view my-cloudtrail-bucket AssumeRole AWSLogs/"
        return 1
    fi
    
    local grep_args="--bucket $bucket --pattern $pattern"
    [[ -n "$prefix" ]] && grep_args="$grep_args --prefix $prefix"
    
    s3grep $grep_args 2>/dev/null | while IFS= read -r line; do
        # Split on .gz: to properly separate filepath from JSON
        if [[ "$line" =~ ^(.*)\.gz:(.*)$ ]]; then
            local filepath="${BASH_REMATCH[1]}.gz"
            local json="${BASH_REMATCH[2]}"
            local filename=$(basename "$filepath")
            
            echo "📄 File: $filename"
            echo "$json" | jq -r '
                if .Records then 
                    .Records[] | "🔐 \(.eventName // "Unknown") | \(.eventSource // "Unknown")
👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")
🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")  
🕐 Time: \(.eventTime // "Unknown")
───────────────────────────────────────────────────────────────"
                else 
                    "🔐 Event: \(.eventName // "Unknown") | Source: \(.eventSource // "Unknown")
👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")  
🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")
🕐 Time: \(.eventTime // "Unknown")
───────────────────────────────────────────────────────────────"
                end' 2>/dev/null || {
                    echo "Raw JSON (jq failed):"
                    echo "$json" | head -c 500
                    echo "..."
                }
            echo ""
        else
            echo "$line"
        fi
    done
}

# List S3 bucket contents with date filtering
function s3-dates() {
    local bucket="$1"
    local prefix="$2"
    local days="${3:-20}"
    
    if [[ -z "$bucket" ]]; then
        echo "Usage: s3-dates <bucket> [prefix] [days-to-show]"
        echo "Example: s3-dates my-log-bucket AWSLogs/ 10"
        return 1
    fi
    
    echo "📅 Available dates in s3://$bucket/$prefix:"
    aws s3 ls "s3://$bucket/$prefix" --recursive 2>/dev/null \
        | grep -E '20[0-9]{2}/[0-9]{2}/[0-9]{2}/' \
        | awk '{print $4}' \
        | grep -oE '20[0-9]{2}/[0-9]{2}/[0-9]{2}' \
        | sort | uniq | tail -"$days"
}

# Quick log analysis
function logs() {
    local pattern="$1"
    local bucket="$2"
    
    if [[ -z "$pattern" ]]; then
        echo "Usage: logs <pattern> [bucket]"
        echo "Examples:"
        echo "  logs AssumeRole                    # Search in default buckets"
        echo "  logs '\"severity\":[5-9]' my-bucket  # Search specific bucket"
        echo ""
        echo "Common patterns:"
        echo "  AssumeRole           - Role assumptions"
        echo "  CreateBucket         - Bucket creation events"
        echo "  UnauthorizedAccess   - GuardDuty unauthorized access"
        echo "  '\"severity\":[5-9]'  - GuardDuty medium+ severity"
        echo "  root                 - Root account usage"
        return 1
    fi
    
    if [[ -n "$bucket" ]]; then
        s3-logs "$bucket" "$pattern"
    else
        echo "Searching common log buckets..."
        
        if aws s3 ls s3://petlab-centralize-logging/ >/dev/null 2>&1; then
            echo "🔍 Searching CloudTrail logs..."
            s3-logs petlab-centralize-logging "$pattern" "AWSLogs/" | head -10
        fi
        
        if aws s3 ls s3://petlab-guardduty-logging/ >/dev/null 2>&1; then
            echo "🔍 Searching GuardDuty logs..."
            s3-logs petlab-guardduty-logging "$pattern" "AWSLogs/" | head -10
        fi
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

