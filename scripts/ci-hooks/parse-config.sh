#!/usr/bin/env bash
# parse-config.sh — Parse the per-device CI config.
# Pure bash YAML parser for our simple config format (no external deps).
#
# Usage:
#   source parse-config.sh
#   ci_config_load                    # Load config
#   ci_config_watch_paths             # Print watch paths
#   ci_config_repo_commands <path>    # Print CI commands for a repo
#   ci_config_default_commands <stack> # Print default commands for a stack
#   ci_config_setting <key>           # Print a setting value

set -euo pipefail

CI_CONFIG_FILE="${CI_CONFIG_FILE:-$HOME/.config/claude-ci/config.yml}"
_CI_CONFIG_LOADED=false
_CI_CONFIG_CONTENT=""

ci_config_load() {
    if [[ ! -f "$CI_CONFIG_FILE" ]]; then
        _CI_CONFIG_LOADED=false
        return 1
    fi
    _CI_CONFIG_CONTENT="$(cat "$CI_CONFIG_FILE")"
    _CI_CONFIG_LOADED=true
    return 0
}

_expand_path() {
    local p="$1"
    echo "${p/#\~/$HOME}"
}

_is_top_level() {
    local line="$1"
    # Top-level key: starts with a letter, no leading whitespace
    [[ "$line" =~ ^[a-zA-Z] ]]
}

_is_indented() {
    local line="$1"
    [[ "$line" =~ ^[[:space:]] ]]
}

_is_list_item() {
    local line="$1"
    [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]
}

ci_config_watch_paths() {
    if [[ "$_CI_CONFIG_LOADED" != "true" ]]; then
        echo "$HOME/work"
        return
    fi
    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^watch_paths: ]]; then
            in_section=true
            continue
        fi
        if $in_section; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
                _expand_path "${BASH_REMATCH[1]}"
            elif _is_top_level "$line"; then
                break
            fi
        fi
    done <<<"$_CI_CONFIG_CONTENT"
}

ci_config_repo_commands() {
    local repo_path="$1"
    if [[ "$_CI_CONFIG_LOADED" != "true" ]]; then
        return 1
    fi

    local in_repos=false
    local in_target=false
    local in_ci=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^repos: ]]; then
            in_repos=true
            continue
        fi
        if ! $in_repos; then continue; fi

        # Top-level key ends repos section
        if _is_top_level "$line"; then break; fi

        # Repo path key: 2-space indent, path ending with :
        # Match lines like "  ~/work/api:" (indented path with colon)
        if [[ "$line" =~ ^[[:space:]][[:space:]]([^[:space:]][^:]*):$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local expanded_key
            expanded_key="$(_expand_path "$key")"
            if [[ "$expanded_key" == "$repo_path" ]]; then
                in_target=true
                in_ci=false
                continue
            elif $in_target; then
                break
            fi
            continue
        fi

        if ! $in_target; then continue; fi

        # ci: subsection
        if [[ "$line" =~ ^[[:space:]]+ci: ]]; then
            in_ci=true
            continue
        fi
        # stack: line (skip)
        if [[ "$line" =~ ^[[:space:]]+stack: ]]; then
            continue
        fi
        # ci command items
        if $in_ci && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done <<<"$_CI_CONFIG_CONTENT"
}

ci_config_default_commands() {
    local stack="$1"
    if [[ "$_CI_CONFIG_LOADED" != "true" ]]; then
        return 1
    fi

    local in_defaults=false
    local in_stack=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^defaults: ]]; then
            in_defaults=true
            continue
        fi
        if ! $in_defaults; then continue; fi

        if _is_top_level "$line"; then break; fi

        # Stack key (e.g., "  python:")
        if [[ "$line" =~ ^[[:space:]]+([a-z]+):$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$stack" ]]; then
                in_stack=true
            elif $in_stack; then
                break
            fi
            continue
        fi
        if $in_stack && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done <<<"$_CI_CONFIG_CONTENT"
}

ci_config_setting() {
    local key="$1"
    local default="${2:-}"
    if [[ "$_CI_CONFIG_LOADED" != "true" ]]; then
        echo "$default"
        return
    fi

    local in_settings=false
    local pattern="^[[:space:]]+${key}:[[:space:]]+(.*)"
    while IFS= read -r line; do
        if [[ "$line" =~ ^settings: ]]; then
            in_settings=true
            continue
        fi
        if ! $in_settings; then continue; fi

        if _is_top_level "$line"; then break; fi

        if [[ "$line" =~ $pattern ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    done <<<"$_CI_CONFIG_CONTENT"
    echo "$default"
}
