#!/usr/bin/env sh
# Shared Bash/Zsh environment for dotfiles-managed shells.
# Keep this file POSIX-compatible: it is sourced by both Bash and Zsh.

export DOTFILES_HOME="${DOTFILES_HOME:-$HOME/dotfiles}"

dotfiles_prepend_path_once() {
    case ":$DOTFILES_MANAGED_PATH:" in
    *":$1:"*) return 0 ;;
    esac
    DOTFILES_MANAGED_PATH="${DOTFILES_MANAGED_PATH:+$DOTFILES_MANAGED_PATH:}$1"
}

dotfiles_path_exists_in() {
    case ":$2:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
    esac
}

dotfiles_load_managed_path() {
    DOTFILES_MANAGED_PATH=""
    dotfiles_paths_file="${DOTFILES_PATHS_FILE:-$DOTFILES_HOME/.config/shell/paths.list}"
    if [ ! -f "$dotfiles_paths_file" ]; then
        dotfiles_paths_file="$HOME/.config/shell/paths.list"
    fi

    if [ -f "$dotfiles_paths_file" ]; then
        while IFS= read -r dotfiles_path_entry || [ -n "$dotfiles_path_entry" ]; do
            case "$dotfiles_path_entry" in
            '' | '#'*) continue ;;
            esac

            dotfiles_expanded_path=""
            # paths.list is trusted repo-owned config; expansion keeps one source of truth
            # while preserving spaces in entries such as Visual Studio Code.app.
            eval "dotfiles_expanded_path=\"$dotfiles_path_entry\""

            case "$dotfiles_expanded_path" in
            '' | /home/node/*) continue ;;
            esac

            if [ -d "$dotfiles_expanded_path" ]; then
                dotfiles_prepend_path_once "$dotfiles_expanded_path"
            fi
        done <"$dotfiles_paths_file"
    fi

    dotfiles_clean_existing_path=""
    dotfiles_remaining_path="${PATH:-}"
    while [ -n "$dotfiles_remaining_path" ]; do
        case "$dotfiles_remaining_path" in
        *:*)
            dotfiles_path_entry=${dotfiles_remaining_path%%:*}
            dotfiles_remaining_path=${dotfiles_remaining_path#*:}
            ;;
        *)
            dotfiles_path_entry=$dotfiles_remaining_path
            dotfiles_remaining_path=""
            ;;
        esac

        case "$dotfiles_path_entry" in
        '' | /home/node/*) ;;
        *)
            if [ -d "$dotfiles_path_entry" ] && ! dotfiles_path_exists_in "$dotfiles_path_entry" "$DOTFILES_MANAGED_PATH" && ! dotfiles_path_exists_in "$dotfiles_path_entry" "$dotfiles_clean_existing_path"; then
                dotfiles_clean_existing_path="${dotfiles_clean_existing_path:+$dotfiles_clean_existing_path:}$dotfiles_path_entry"
            fi
            ;;
        esac
    done

    PATH="$DOTFILES_MANAGED_PATH${dotfiles_clean_existing_path:+:$dotfiles_clean_existing_path}"
    export PATH

    unset DOTFILES_MANAGED_PATH dotfiles_paths_file dotfiles_path_entry dotfiles_expanded_path dotfiles_clean_existing_path dotfiles_remaining_path
}

dotfiles_load_managed_path

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export PAGER="${PAGER:-less}"
export MANPAGER="${MANPAGER:-less -R}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"
export LANG="${LANG:-en_US.UTF-8}"
export BAT_THEME="${BAT_THEME:-miniautumn}"
export BAT_PAGING="${BAT_PAGING:-never}"
export HOMEBREW_AUTO_UPDATE_SECS="${HOMEBREW_AUTO_UPDATE_SECS:-86400}"
export FORCE_AUTOUPDATE_PLUGINS="${FORCE_AUTOUPDATE_PLUGINS:-1}"
export CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD="${CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD:-1}"
export CLAUDE_CODE_EFFORT_LEVEL="${CLAUDE_CODE_EFFORT_LEVEL:-medium}"
export CLAUDE_CODE_NO_FLICKER="${CLAUDE_CODE_NO_FLICKER:-0}"
export CLAUDE_CODE_ENABLE_TELEMETRY="${CLAUDE_CODE_ENABLE_TELEMETRY:-1}"
export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
export OPENCODE_DISABLE_LSP_DOWNLOAD="${OPENCODE_DISABLE_LSP_DOWNLOAD:-true}"

case "$(uname -s 2>/dev/null)" in
Darwin)
    export PYTHONPATH="${PYTHONPATH:-/opt/homebrew/lib/python3.11/site-packages}"
    if [ -S "$HOME/.colima/default/docker.sock" ]; then
        export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/default/docker.sock}"
    fi
    ;;
Linux)
    export PYTHONPATH="${PYTHONPATH:-/usr/lib/python3/dist-packages}"
    ;;
esac

unset -f dotfiles_prepend_path_once dotfiles_path_exists_in dotfiles_load_managed_path
