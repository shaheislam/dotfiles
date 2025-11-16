KEYTIMEOUT=500

# Enable Powerlevel10k instant prompt (or starship)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Choose between powerlevel10k and starship (uncomment one)
eval "$(starship init zsh)"
# export ZSH_THEME="powerlevel10k/powerlevel10k"

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

# Paths
export PATH="/opt/homebrew/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/dotfiles/scripts/bin:$PATH"

# VSCode and Cursor PATH entries removed

# Initialize tools
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
eval "$(atuin init zsh)"

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

# FZF theme - Tokyo Night
fg="#c0caf5"
bg="#1a1b26"
bg_highlight="#283457"
purple="#9d7cd8"
blue="#7aa2f7"
cyan="#7dcfff"
magenta="#bb9af7"
green="#9ece6a"
yellow="#e0af68"
red="#f7768e"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${blue},fg+:${fg},bg+:${bg_highlight},hl+:${magenta},info:${yellow},prompt:${cyan},pointer:${blue},marker:${green},spinner:${cyan},header:${purple}"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Advanced FZF completion functions for Zsh

# Custom path completion generator (used by ** trigger)
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Custom directory completion generator (used by cd ** etc.)
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# Command-specific completion preview behavior
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --icons --level=2 --color=always {} 2>/dev/null || tree -C {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}" "$@" ;;
    ssh)          fzf --preview 'dig {}' "$@" ;;
    kubectl)      fzf --preview 'kubectl get {} -o yaml 2>/dev/null | bat --language=yaml --color=always' "$@" ;;
    docker)       fzf --preview 'docker inspect {} 2>/dev/null | bat --language=json --color=always' "$@" ;;
    git)          fzf --preview 'git show --color=always {} 2>/dev/null || bat --color=always {}' "$@" ;;
    *)            fzf --preview 'bat --color=always --line-range=:500 {} 2>/dev/null || cat {}' "$@" ;;
  esac
}

# Custom Git command completion with fzf
_fzf_complete_git() {
  _fzf_complete --multi --reverse --prompt="Git> " -- "$@" < <(
    git --help -a 2>/dev/null | grep -E '^\s+' | awk '{print $1}' | sort -u
  )
}

# Custom kubectl completion with fzf (context-aware)
_fzf_complete_kubectl() {
  _fzf_complete --multi --reverse --prompt="Kubectl> " -- "$@" < <(
    kubectl api-resources --verbs=list -o name 2>/dev/null | sort
  )
}

# Custom docker completion with fzf
_fzf_complete_docker() {
  _fzf_complete --multi --reverse --prompt="Docker> " -- "$@" < <(
    docker ps --format '{{.Names}}' 2>/dev/null
  )
}

# Aliases
alias python=python3
alias cd="z"
alias ls="eza"
alias la="eza -al"
alias cat="bat"
alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"

# thefuck
if command -v thefuck > /dev/null 2>&1; then
  eval $(thefuck --alias)
fi

# VSCode and Cursor functions removed

# AWS SSO function
function aws-sso() {
    local profile=${1:-petlab}
    aws sso login --profile "$profile"
    eval "$(aws configure export-credentials --profile "$profile" --format env)"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_PROFILE="$profile"
    aws sts get-caller-identity >/dev/null 2>&1 || echo "Failed to get credentials"
}

# Granted AWS credential management alias and completions
# Granted needs an alias to export environment variables
alias assume="source assume"

# Enable Granted completions for Zsh shell
if command -v granted &> /dev/null 2>&1; then
    eval "$(granted completion --shell zsh)" 2>/dev/null || true
fi

# Source powerlevel10k config if using it
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
