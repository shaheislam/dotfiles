# Source fzf-docker.sh integration for Fish shell
# This file auto-loads Docker FZF functionality at shell startup

# Only load if fzf and docker are available
if command -v fzf >/dev/null 2>&1 && command -v docker >/dev/null 2>&1
    # Source the fzf-docker Fish integration
    source ~/.config/fish/functions/fzf-docker.fish
end
