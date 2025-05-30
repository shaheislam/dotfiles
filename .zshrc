KEYTIMEOUT=500

# Enable Powerlevel10k instant prompt (should stay at the top of ~/.zshrc).
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

eval "$(starship init zsh)"
# Path to Oh My Zsh and theme.
export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="powerlevel10k/powerlevel10k"
KEYTIMEOUT=500
# typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Load Oh My Zsh framework and plugins.
plugins=(
  git 
  zsh-completions 
  fzf-tab 
  zsh-kubectl-prompt 
  docker-zsh-completion
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# Paths.
export PATH="/opt/homebrew/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Add VSCode bin to PATH
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# VS Code function (fallback to 'open' command if needed)
code() {
  if command -v code &> /dev/null; then
    command code "$@"
  elif [ -d "/Applications/Visual Studio Code.app" ]; then
    open -a "Visual Studio Code" "$@"
  else
    echo "VSCode is not installed or not found in the expected location."
  fi
}

# Aliases for colorls (only if installed).
if command -v colorls > /dev/null 2>&1; then
  alias ls="colorls"
  alias la="colorls -al"
fi

# ---- Kubernetes Aliases ----
alias k="kubectl"
alias kpf="kubectl port-forward"
alias kaf="kubectl apply -f"
alias kdf="kubectl delete -f"
kdesc() { kubectl describe "$1" "$2"; }
kget() { kubectl get "$1" "$2"; }

# ---- FZF -----

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- setup fzf theme ---
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

source ~/fzf-git.sh/fzf-git.sh

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# fzf history and recent files selection.
fsel() { 
  case "$1" in
    "history") eval $(history | fzf --preview "echo {}" | sed "s/^[ ]*[0-9]*[ ]*//") ;;
    "recent") code $(cat ~/.viminfo | grep "^>" | cut -c3- | fzf | sed "s|^~|$HOME|" | xargs -r realpath 2>/dev/null) ;;
    *) echo "Usage: fsel {history|recent}" ;;
  esac
}

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# ---- Miscellaneous Aliases ----
alias python=python3
alias upload='curl -F "file=@-" https://hardfiles.org/'

# thefuck (only if installed).
if command -v thefuck > /dev/null 2>&1; then
  eval $(thefuck --alias)
fi

# ----- Bat (better cat) -----
export BAT_THEME=tokyonight_night

# asdf version manager.
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# Enable Powerlevel10k prompt customization.
# [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# direnv integration
eval "$(direnv hook zsh)"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

alias awsume=". awsume"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

function aws-sso() {
    local profile=${1:-petlab}
    aws sso login --profile "$profile"
    eval "$(aws configure export-credentials --profile "$profile" --format env)"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_PROFILE="$profile"
    aws sts get-caller-identity >/dev/null 2>&1 || echo "Failed to get credentials"
}

# Added by Windsurf
export PATH="/Users/shahe/.codeium/windsurf/bin:$PATH"

alias code='code --reuse-window'
export VSCODE_CLI_USE_REUSE_WINDOW=1
export FZF_DEFAULT_COMMAND='fd'
