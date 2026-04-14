# ~/.bash_profile - Bash login shell configuration
# Symlinked via GNU Stow

# Source .bashrc for interactive shells
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
. "$HOME/.cargo/env"
