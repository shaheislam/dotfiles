#!/usr/bin/env bash
# Materialize personal/global slash commands from canonical .claude/commands/
# into every harness's expected command directory via symlinks.
#
# Canonical source : ~/dotfiles/.claude/commands/*.md
# Targets          : ~/dotfiles/.config/opencode/command/
#                    (extend TARGETS below when adding Codex/Pi support)
#
# Symlinks point at the canonical Claude file using a relative path so a single
# edit propagates to every harness with no copy-on-sync drift.
#
# Usage:
#   scripts/sync-agent-commands-personal.sh           # apply
#   scripts/sync-agent-commands-personal.sh --check   # drift report (CI)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_ROOT/.claude/commands"

# Target directories where each harness expects slash commands.
# Add new harnesses here — that is the single point of extension.
TARGETS=(
    ".config/opencode/command"
)

CHECK_ONLY=false
case "${1:-}" in
--check) CHECK_ONLY=true ;;
--help | -h)
    sed -n '2,15p' "$0"
    exit 0
    ;;
"") ;;
*)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac

[[ -d "$SOURCE_DIR" ]] || {
    echo "Missing canonical source: $SOURCE_DIR" >&2
    exit 1
}

absolute_path() {
    local dir base
    dir="$(dirname "$1")"
    base="$(basename "$1")"
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

resolved_link_path() {
    local link_target
    link_target="$(readlink "$1")"
    case "$link_target" in
    /*) absolute_path "$link_target" ;;
    *) absolute_path "$(dirname "$1")/$link_target" ;;
    esac
}

link_resolves_to() {
    [[ -L "$1" ]] || return 1
    [[ "$(resolved_link_path "$1")" == "$(absolute_path "$2")" ]]
}

synced=0
skipped=0
drift=0

for target in "${TARGETS[@]}"; do
    target_dir="$DOTFILES_ROOT/$target"
    if [[ "$CHECK_ONLY" == false ]]; then
        mkdir -p "$target_dir"
    fi

    for cmd_file in "$SOURCE_DIR"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        basename="$(basename "$cmd_file")"
        target_link="$target_dir/$basename"
        rel_target="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$cmd_file" "$target_dir")"

        if [[ -e "$target_link" || -L "$target_link" ]]; then
            if link_resolves_to "$target_link" "$cmd_file"; then
                skipped=$((skipped + 1))
                continue
            fi
            if [[ -L "$target_link" ]]; then
                if [[ "$CHECK_ONLY" == true ]]; then
                    echo "DRIFT: $target/$basename -> $(readlink "$target_link") (expected $rel_target)"
                    drift=$((drift + 1))
                    continue
                fi
                rm "$target_link"
            else
                echo "KEEP: $target/$basename is a real file (harness-specific override)"
                skipped=$((skipped + 1))
                continue
            fi
        fi

        if [[ "$CHECK_ONLY" == true ]]; then
            echo "MISSING: $target/$basename"
            drift=$((drift + 1))
            continue
        fi

        ln -s "$rel_target" "$target_link"
        echo "LINK: $target/$basename -> $rel_target"
        synced=$((synced + 1))
    done
done

if [[ "$CHECK_ONLY" == true ]]; then
    if [[ "$drift" -gt 0 ]]; then
        echo "Command harness drift detected: $drift issue(s)" >&2
        exit 1
    fi
    echo "Command harness in sync."
    exit 0
fi

echo "Synced: $synced, Skipped: $skipped (already linked or harness-specific override)"
