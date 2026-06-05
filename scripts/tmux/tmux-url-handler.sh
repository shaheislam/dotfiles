#!/usr/bin/env bash

# tmux target handler - opens URLs and file references from tmux pane content.
# Smart capture: tries visible pane first, falls back to full scrollback if no
# targets are found. Multiple targets always keep the existing selection menu.

set -euo pipefail

name="tmux-open-target"
buffer_file_name="tmux-open-target-buffer-$$"
temp_file="/tmp/$buffer_file_name"

cleanup() {
    rm -f "$temp_file"
}
trap cleanup EXIT

pane_cwd=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd)
pane_cwd=$(cd "$pane_cwd" && pwd -P)
source_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)

capture_pane() {
    local capture_mode="$1"

    if [ "$capture_mode" = "full" ]; then
        tmux capture-pane -J -S - -p >"$temp_file"
    else
        tmux capture-pane -J -p >"$temp_file"
    fi
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

strip_wrapping() {
    local value
    value=$(trim "$1")
    value="${value#file://}"
    value="${value#<}"
    value="${value%>}"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    value="${value#(}"
    value="${value%)}"

    while [ -n "$value" ]; do
        case "${value: -1}" in
        . | , | ';' | ':' | '!' | '?' | ']' | '}') value="${value%?}" ;;
        *) break ;;
        esac
    done

    printf '%s\n' "$value"
}

normalize_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        printf '%s\n' "$url"
    else
        printf 'https://%s\n' "$url"
    fi
}

add_target() {
    local type="$1"
    local value="$2"
    local label="$3"
    local line="${4:-}"

    [ -n "$value" ] || return 0
    printf '%s\t%s\t%s\t%s\n' "$type" "$value" "$label" "$line"
}

extract_urls() {
    grep -Eoi '(https?://[a-zA-Z0-9./?=_:%+#&~@!*(),;_%-]+|[a-zA-Z0-9][a-zA-Z0-9.-]*\.(com|org|net|io|dev|co\.uk|gov\.uk|edu|info|me|app)\b[/a-zA-Z0-9./?=_:%+#&~@!*(),;_%-]*)' "$temp_file" |
        while IFS= read -r raw_url; do
            local url clean_url
            url=$(strip_wrapping "$raw_url")
            [ -n "$url" ] || continue
            clean_url="${url#*://}"
            add_target "url" "$(normalize_url "$url")" "$clean_url"
        done || true
}

looks_like_file_name() {
    local value="$1"
    [[ "$value" =~ \.(md|markdown|txt|log|json|jsonc|ya?ml|toml|xml|csv|tsv|sh|bash|zsh|fish|js|jsx|ts|tsx|mjs|cjs|py|rb|go|rs|lua|vim|java|kt|kts|c|cc|cpp|h|hpp|cs|php|swift|sql|tf|tfvars|nix|conf|ini|env|pdf|png|jpe?g|gif|webp|svg|heic|mp4|mov|m4v|mp3|wav|zip|tar|tgz|gz|bz2|xz|7z|rar)$ ]]
}

resolve_path() {
    local raw value line candidate
    raw="$1"
    value=$(strip_wrapping "$raw")

    [ -n "$value" ] || return 1
    [[ "$value" =~ ^https?:// ]] && return 1
    [[ "$value" =~ ^mailto: ]] && return 1

    # Drop markdown anchors/query strings for local files: docs/a.md#heading.
    value="${value%%\?*}"
    value="${value%%#*}"

    line=""
    if [[ "$value" =~ ^(.+):([0-9]+):[0-9]+$ ]]; then
        line="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^(.+):([0-9]+)$ ]]; then
        line="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[1]}"
    fi

    case "$value" in
    ~/*) candidate="$HOME/${value#~/}" ;;
    /*) candidate="$value" ;;
    ./* | ../*) candidate="$pane_cwd/$value" ;;
    *)
        if [[ "$value" == */* ]] || looks_like_file_name "$value"; then
            candidate="$pane_cwd/$value"
        else
            return 1
        fi
        ;;
    esac

    if [ -e "$candidate" ]; then
        local resolved
        resolved=$(cd "$(dirname "$candidate")" && pwd -P)/$(basename "$candidate")
        printf '%s\t%s\n' "$resolved" "$line"
        return 0
    fi

    return 1
}

target_type_for_path() {
    local path="$1"
    local lower
    lower=$(printf '%s\n' "$path" | tr '[:upper:]' '[:lower:]')

    if [ -d "$path" ]; then
        printf 'dir\n'
    elif [[ "$lower" =~ \.(md|markdown)$ ]]; then
        printf 'md\n'
    elif [[ "$lower" =~ \.(txt|log|json|jsonc|ya?ml|toml|xml|csv|tsv|sh|bash|zsh|fish|js|jsx|ts|tsx|mjs|cjs|py|rb|go|rs|lua|vim|java|kt|kts|c|cc|cpp|h|hpp|cs|php|swift|sql|tf|tfvars|nix|conf|ini|env)$ ]]; then
        printf 'text\n'
    elif [[ "$lower" =~ \.pdf$ ]]; then
        printf 'pdf\n'
    elif [[ "$lower" =~ \.(png|jpe?g|gif|webp|svg|heic|mp4|mov|m4v|mp3|wav)$ ]]; then
        printf 'media\n'
    else
        printf 'file\n'
    fi
}

add_file_target_from_raw() {
    local raw resolved path line type label
    raw="$1"
    resolved=$(resolve_path "$raw") || return 0
    path="${resolved%%$'\t'*}"
    line="${resolved#*$'\t'}"
    [ "$line" != "$resolved" ] || line=""
    type=$(target_type_for_path "$path")
    label="${path#"$pane_cwd"/}"
    [ "$label" != "$path" ] || label="$path"
    [ -z "$line" ] || label="$label:$line"
    add_target "$type" "$path" "$label" "$line"
}

extract_markdown_targets() {
    perl -nle 'while (/!?\[[^\]]*\]\(([^)]+)\)/g) { print $1 }' "$temp_file" |
        while IFS= read -r raw_path; do
            add_file_target_from_raw "$raw_path"
        done || true
}

extract_patch_targets() {
    grep -E '^\*\*\* (Add|Update) File: |^\*\*\* Move to: ' "$temp_file" |
        sed -E 's/^\*\*\* (Add|Update) File: //; s/^\*\*\* Move to: //' |
        while IFS= read -r raw_path; do
            add_file_target_from_raw "$raw_path"
        done || true
}

extract_plain_path_targets() {
    {
        grep -Eo '(^|[[:space:]"'"'"'`(<])(~|/|\.\.?/|[A-Za-z0-9_.-]+/)[^[:space:]"'"'"'`<>|]+' "$temp_file" |
            sed -E 's/^[[:space:]"'"'"'`(<]+//'
        grep -Eo '\b[A-Za-z0-9_.-]+\.(md|markdown|txt|log|json|jsonc|ya?ml|toml|xml|csv|tsv|sh|bash|zsh|fish|js|jsx|ts|tsx|mjs|cjs|py|rb|go|rs|lua|vim|java|kt|kts|c|cc|cpp|h|hpp|cs|php|swift|sql|tf|tfvars|nix|conf|ini|env|pdf|png|jpe?g|gif|webp|svg|heic|mp4|mov|m4v|mp3|wav|zip|tar|tgz|gz|bz2|xz|7z|rar)(:[0-9]+(:[0-9]+)?)?' "$temp_file"
    } |
        while IFS= read -r raw_path; do
            add_file_target_from_raw "$raw_path"
        done || true
}

extract_targets() {
    {
        extract_urls
        extract_markdown_targets
        extract_patch_targets
        extract_plain_path_targets
    } | awk -F '\t' '!seen[$1 FS $2 FS $4]++'
}

open_target_command() {
    local type="$1"
    local value="$2"
    local label="$3"
    local line="${4:-}"
    local quoted_value quoted_line quoted_pane

    quoted_value=$(printf '%q' "$value")
    quoted_line=$(printf '%q' "$line")
    quoted_pane=$(printf '%q' "$source_pane")

    case "$type" in
    url)
        printf 'run-shell '\''/usr/bin/open -a Firefox %s >/dev/null 2>&1 & tmux display-message "#[fg=green,bold]%s: Opened %s"'\''' "$quoted_value" "$name" "$label"
        ;;
    md | text)
        if [ -n "$line" ]; then
            printf 'run-shell '\''%s/scripts/nvim-open-file.sh %s --line %s --target %s >/dev/null 2>&1 & tmux display-message "#[fg=green,bold]%s: Opened %s"'\''' "$HOME/dotfiles" "$quoted_value" "$quoted_line" "$quoted_pane" "$name" "$label"
        else
            printf 'run-shell '\''%s/scripts/nvim-open-file.sh %s --target %s >/dev/null 2>&1 & tmux display-message "#[fg=green,bold]%s: Opened %s"'\''' "$HOME/dotfiles" "$quoted_value" "$quoted_pane" "$name" "$label"
        fi
        ;;
    dir)
        printf 'display-popup -E -h 85%% -w 85%% -d %s '\''yazi %s'\''' "$quoted_value" "$quoted_value"
        ;;
    *)
        printf 'run-shell '\''/usr/bin/open %s >/dev/null 2>&1 & tmux display-message "#[fg=green,bold]%s: Opened %s"'\''' "$quoted_value" "$name" "$label"
        ;;
    esac
}

execute_target() {
    local type="$1"
    local value="$2"
    local label="$3"
    local line="${4:-}"
    local nvim_args=()

    case "$type" in
    url)
        /usr/bin/open -a Firefox "$value" >/dev/null 2>&1 &
        ;;
    md | text)
        nvim_args=("$HOME/dotfiles/scripts/nvim-open-file.sh" "$value")
        [ -z "$line" ] || nvim_args+=(--line "$line")
        [ -z "$source_pane" ] || nvim_args+=(--target "$source_pane")
        "${nvim_args[@]}" >/dev/null 2>&1
        ;;
    dir)
        tmux display-popup -E -h 85% -w 85% -d "$value" "yazi $(printf '%q' "$value")"
        return 0
        ;;
    *)
        /usr/bin/open "$value" >/dev/null 2>&1 &
        ;;
    esac

    tmux display-message "#[fg=green,bold]$name: Opened $label"
}

type_label() {
    case "$1" in
    url) printf 'URL' ;;
    md) printf 'MD ' ;;
    text) printf 'TXT' ;;
    pdf) printf 'PDF' ;;
    media) printf 'MED' ;;
    dir) printf 'DIR' ;;
    *) printf 'FILE' ;;
    esac
}

targets=""
for mode in visible full; do
    capture_pane "$mode"
    targets=$(extract_targets)
    [ -n "$targets" ] && break
done

if [ -z "$targets" ]; then
    tmux display-message "#[fg=yellow]$name: No URLs or files found in pane"
    exit 0
fi

target_count=$(printf '%s\n' "$targets" | wc -l | tr -d ' ')

if [ "$target_count" -eq 1 ]; then
    IFS=$'\t' read -r type value label line <<<"$targets"
    execute_target "$type" "$value" "$label" "$line"
    exit 0
fi

menu_items=()
index=1

while IFS=$'\t' read -r type value label line; do
    menu_label="$(type_label "$type")  $label"
    command=$(open_target_command "$type" "$value" "$label" "$line")
    menu_items+=("$menu_label" "$index" "$command")

    index=$((index + 1))
    if [ "$index" -gt 9 ]; then
        break
    fi
done <<<"$targets"

menu_items+=("" "" "Cancel" "q" "")

tmux display-menu -t 1 -T "#[fg=cyan,bold]Select Target" "${menu_items[@]}"
