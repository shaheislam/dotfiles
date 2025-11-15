# Source fzf-git.sh integration for Fish shell
# Provides CTRL-G keybindings for git object selection

# Only load in interactive mode
if status is-interactive
    # Source the fzf-git Fish integration
    source ~/.config/fish/functions/fzf-git.fish
end
