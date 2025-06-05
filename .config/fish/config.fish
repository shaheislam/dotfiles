# Fish Shell Configuration
# Translated from .zshrc setup

# Set key timeout (equivalent to KEYTIMEOUT in zsh)
set -g fish_key_bindings fish_default_key_bindings
set -g fish_escape_delay_ms 500

# Initialize Starship prompt
if command -v starship >/dev/null
    starship init fish | source
end

# Environment Variables
set -x BAT_THEME tokyonight_night
set -x STARSHIP_CONFIG $HOME/.config/starship.toml

# Path configuration
set -gx PATH /opt/homebrew/bin $HOME/bin $HOME/.local/bin /usr/local/bin $PATH
set -gx PATH $HOME/Library/Python/3.9/bin $PATH

# Add VSCode bin to PATH if it exists
if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    set -gx PATH $PATH "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
end

# Initialize tools
if command -v zoxide >/dev/null
    zoxide init fish | source
end

if command -v direnv >/dev/null
    direnv hook fish | source
end

if command -v atuin >/dev/null
    atuin init fish | source
end

# Source asdf
if test -f "/opt/homebrew/opt/asdf/libexec/asdf.fish"
    source /opt/homebrew/opt/asdf/libexec/asdf.fish
end

# Note: fzf-git.sh is bash/zsh specific and not compatible with Fish
# Fish-native git+fzf functionality is provided in conf.d/plugins.fish

# FZF configuration
if command -v fzf >/dev/null
    fzf --fish | source
end

if test -f ~/.fzf.fish
    source ~/.fzf.fish
end

# FZF theme colors
set -l fg "#CBE0F0"
set -l bg "#011628"
set -l bg_highlight "#143652"
set -l purple "#B388FF"
set -l blue "#06BCE4"
set -l cyan "#2CF9ED"

set -gx FZF_DEFAULT_OPTS "--color=fg:$fg,bg:$bg,hl:$purple,fg+:$fg,bg+:$bg_highlight,hl+:$purple,info:$blue,prompt:$cyan,pointer:$cyan,marker:$cyan,spinner:$cyan,header:$cyan"
set -gx FZF_DEFAULT_COMMAND "fd --hidden --strip-cwd-prefix --exclude .git"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Aliases
alias python=python3
alias cd="z"
alias ls="eza"
alias la="eza -al"
alias cat="bat"
alias k="kubectl"

# thefuck initialization
if command -v thefuck >/dev/null
    thefuck --alias | source
end

# AWS SSO function
function aws-sso
    set -l profile $argv[1]
    if test -z "$profile"
        set profile "petlab"
    end

    aws sso login --profile "$profile"
    eval (aws configure export-credentials --profile "$profile" --format env)
    set -gx AWS_DEFAULT_PROFILE "$profile"
    set -gx AWS_PROFILE "$profile"

    if not aws sts get-caller-identity >/dev/null 2>&1
        echo "Failed to get credentials"
    end
end
