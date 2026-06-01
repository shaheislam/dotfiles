#!/usr/bin/env bash
set -euo pipefail

interval_minutes="$(tmux show-option -gqv @dotfiles-continuum-save-interval)"
if [[ -z "$interval_minutes" || ! "$interval_minutes" =~ ^[0-9]+$ || "$interval_minutes" -le 0 ]]; then
    exit 0
fi

existing_pid="$(tmux show-option -gqv @dotfiles-continuum-autosave-pid)"
if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    exit 0
fi

(
    while tmux has-session 2>/dev/null; do
        sleep "$((interval_minutes * 60))"

        save_script="$(tmux show-option -gqv @resurrect-save-script-path)"
        if [[ -z "$save_script" ]]; then
            save_script="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
        fi

        if [[ -x "$save_script" ]]; then
            "$save_script" quiet >/dev/null 2>&1 || true
            tmux set-option -gq @continuum-save-last-timestamp "$(date +%s)" || true
        fi
    done
) >/dev/null 2>&1 &

tmux set-option -gq @dotfiles-continuum-autosave-pid "$!"
