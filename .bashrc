# ~/.bashrc - Bash configuration managed by dotfiles
# Symlinked via GNU Stow

# PATH Configuration (mirrors Fish and Zsh)
export PATH="/opt/homebrew/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="$HOME/dotfiles/scripts/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"
export PATH="$HOME/.claude/local/node_modules/.bin:$PATH"

# Prompt - Starship (consistent with Fish and Zsh)
if command -v starship &> /dev/null; then
  eval "$(starship init bash)"
fi

# Tool Integrations (mirrors Zsh setup)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

if command -v direnv &> /dev/null; then
  eval "$(direnv hook bash)"
fi

if command -v atuin &> /dev/null; then
  eval "$(atuin init bash)"
fi

# Source asdf version manager
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

# Source fzf-git.sh for enhanced git workflows
if [ -f "$HOME/fzf-git.sh/fzf-git.sh" ]; then
  source "$HOME/fzf-git.sh/fzf-git.sh"
fi

# Bash Completion (for Bash 4.2+)
if [ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]; then
  . "/opt/homebrew/etc/profile.d/bash_completion.sh"
fi

# Bash Git Prompt (alternative to Starship for pure bash environments)
# Note: Starship is already configured above (line 14-17)
# Uncomment below to use bash-git-prompt instead of Starship:
# if [ -f "/opt/homebrew/opt/bash-git-prompt/share/gitprompt.sh" ]; then
#   __GIT_PROMPT_DIR="/opt/homebrew/opt/bash-git-prompt/share"
#   GIT_PROMPT_ONLY_IN_REPO=1
#   source "/opt/homebrew/opt/bash-git-prompt/share/gitprompt.sh"
# fi

# Advanced Syntax Highlighting (optional):
# For Fish-like features (auto-suggestions, syntax highlighting), consider:
# https://github.com/akinomyoga/ble.sh

# FZF Configuration
if command -v fzf &> /dev/null; then
  eval "$(fzf --bash)"
fi

# BAT_PAGING fix (prevents FZF preview errors)
export BAT_PAGING="auto"

# Editor Configuration
export EDITOR="nvim"
export VISUAL="nvim"

# Basic Aliases (add more as needed)
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'

# History Configuration
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Added by sonarqube-cli installer
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"
