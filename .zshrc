KEYTIMEOUT=500

# Enable Powerlevel10k instant prompt (or starship)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==================== Cached Tool Initialization (Performance Optimization) ====================
# Cache tool init scripts to reduce startup time by ~50-100ms
# Cache invalidates automatically when tool version changes

ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init"
mkdir -p "$ZSH_CACHE_DIR"

_cache_tool_init() {
    local tool=$1
    local init_cmd=$2
    local cache_file="$ZSH_CACHE_DIR/${tool}.zsh"
    local version_file="$ZSH_CACHE_DIR/${tool}.version"

    local current_version=$($tool --version 2>/dev/null | head -1)
    local cached_version=""
    [[ -f "$version_file" ]] && cached_version=$(cat "$version_file")

    if [[ "$current_version" != "$cached_version" ]] || [[ ! -f "$cache_file" ]]; then
        eval "$init_cmd" > "$cache_file" 2>/dev/null
        echo "$current_version" > "$version_file"
    fi

    source "$cache_file"
}

# Choose between powerlevel10k and starship (uncomment one)
command -v starship >/dev/null && _cache_tool_init starship "starship init zsh"
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

# Source Oh My Zsh when it is installed.
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# Paths
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Homebrew auto-update: run `brew update` at most once per day when using any brew command
export HOMEBREW_AUTO_UPDATE_SECS=86400
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"
export PATH="$HOME/dotfiles/scripts/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# PinchTab - Multi-instance Chrome orchestrator for AI agents
export PINCHTAB_PORT=9867
export PINCHTAB_CONFIG="$HOME/.config/pinchtab/config.json"

# VSCode and Cursor PATH entries removed

# Initialize tools (using cached initialization for performance)
command -v zoxide >/dev/null && _cache_tool_init zoxide "zoxide init zsh"
# Suppress direnv log messages (loading/unloading/using) for cleaner cd output
export DIRENV_LOG_FORMAT=""
command -v direnv >/dev/null && _cache_tool_init direnv "direnv hook zsh"
command -v atuin >/dev/null && _cache_tool_init atuin "atuin init zsh"
command -v glab >/dev/null && _cache_tool_init glab "glab completion --shell=zsh"
command -v glab >/dev/null && export GITLAB_TOKEN=$(glab auth token --hostname gitlab.com 2>&1)

# Override Atuin preexec to handle invalid UTF-8 gracefully (prevents panics)
_atuin_preexec() {
    local id
    # Sanitize command: strip invalid UTF-8 bytes
    local sanitized_cmd
    sanitized_cmd=$(printf '%s' "$1" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
    if [[ -n "$sanitized_cmd" ]]; then
        id=$(atuin history start -- "$sanitized_cmd" 2>/dev/null)
        export ATUIN_HISTORY_ID="$id"
    fi
    __atuin_preexec_time=${EPOCHREALTIME-}
}

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

# Homebrew shortcuts
alias bu="brew update"
alias bup="brew upgrade"
alias buc="brew cleanup"
alias bud="brew doctor"
alias bui="brew install"
alias bus="brew search"
alias buo="brew outdated"
alias bubu="brew update && brew upgrade"

# Aliases
alias python=python3
alias cd="z"
alias ls="eza"
alias la="eza -al"
alias cat="bat"
alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"

# bat theme
export BAT_THEME="Catppuccin Mocha"

# thefuck
command -v thefuck >/dev/null && _cache_tool_init thefuck "thefuck --alias"

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

# Added by sonarqube-cli installer
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"

# Clean stale PATH entries inherited from launchers or optional tools. This only
# removes entries that do not currently exist and preserves first-seen order.
typeset -a _clean_path_entries _seen_path_entries
for _path_entry in $path; do
  if [[ -z "$_path_entry" || "$_path_entry" == /home/node/* || ! -d "$_path_entry" ]]; then
    continue
  fi
  if (( ${_seen_path_entries[(Ie)$_path_entry]} == 0 )); then
    _clean_path_entries+=("$_path_entry")
    _seen_path_entries+=("$_path_entry")
  fi
done
path=("${_clean_path_entries[@]}")
export PATH
unset _clean_path_entries _seen_path_entries _path_entry

# OpenTelemetry observability (harness engineering)
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"

# Claude Code fullscreen rendering (research preview)
export CLAUDE_CODE_NO_FLICKER=1
