#!/usr/bin/env bash
set -euo pipefail

readonly status_right='#[fg=#d7d5cd,bg=default] %H:%M '

tmux set-option -gq status-right "$status_right"
"$HOME/dotfiles/scripts/tmux/tmux-continuum-autosave.sh" >/dev/null 2>&1 || true

# TPM plugins can mutate status-right shortly after source-file returns.
# Reapply once after plugin startup settles so reloads converge deterministically.
(
    sleep 1
    tmux set-option -gq status-right "$status_right"
) >/dev/null 2>&1 &
