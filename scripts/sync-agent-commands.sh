#!/usr/bin/env bash
# sync-agent-commands.sh — Sync .agents/commands/ to agent-specific directories
#
# Superset-sh pattern: single source of truth in .agents/commands/,
# symlinked into .claude/commands/, .cursor/commands/, .codex/instructions/.
#
# Usage:
#   sync-agent-commands.sh [--dry-run] [repo-root]

set -euo pipefail

DRY_RUN=false
REPO_ROOT=""

for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) REPO_ROOT="$arg" ;;
    esac
done

# Find repo root
if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

SOURCE_DIR="$REPO_ROOT/.agents/commands"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "No .agents/commands/ directory found at $REPO_ROOT"
    exit 0
fi

# Agent target directories and their expected symlink format
declare -A AGENT_DIRS=(
    [claude]=".claude/commands"
    [cursor]=".cursor/commands"
)

synced=0
skipped=0

for agent in "${!AGENT_DIRS[@]}"; do
    target_dir="$REPO_ROOT/${AGENT_DIRS[$agent]}"

    if $DRY_RUN; then
        echo "Would create: $target_dir/"
    else
        mkdir -p "$target_dir"
    fi

    for cmd_file in "$SOURCE_DIR"/*.md; do
        [ -f "$cmd_file" ] || continue
        basename=$(basename "$cmd_file")
        target_link="$target_dir/$basename"

        # Calculate relative path from target to source
        rel_path=$(python3 -c "import os.path; print(os.path.relpath('$cmd_file', '$target_dir'))")

        if [ -L "$target_link" ]; then
            existing_target=$(readlink "$target_link")
            if [ "$existing_target" = "$rel_path" ]; then
                skipped=$((skipped + 1))
                continue
            fi
            # Different target, update
            if $DRY_RUN; then
                echo "Would update: $target_link -> $rel_path"
            else
                rm "$target_link"
                ln -s "$rel_path" "$target_link"
                echo "Updated: $target_link -> $rel_path"
            fi
        elif [ -e "$target_link" ]; then
            echo "SKIP: $target_link exists but is not a symlink (agent-specific override)"
            skipped=$((skipped + 1))
            continue
        else
            if $DRY_RUN; then
                echo "Would create: $target_link -> $rel_path"
            else
                ln -s "$rel_path" "$target_link"
                echo "Created: $target_link -> $rel_path"
            fi
        fi
        synced=$((synced + 1))
    done
done

# Also handle Codex instructions (different format — .codex/ uses instructions.md)
# Codex reads from AGENTS.md at root, so we append a reference there
CODEX_DIR="$REPO_ROOT/.codex"
if [ -d "$CODEX_DIR" ]; then
    codex_instructions="$CODEX_DIR/instructions.md"
    if [ ! -f "$codex_instructions" ]; then
        if $DRY_RUN; then
            echo "Would create: $codex_instructions (with references to .agents/commands/)"
        else
            {
                echo "# Shared Agent Commands"
                echo ""
                echo "See \`.agents/commands/\` for shared command prompts:"
                for cmd_file in "$SOURCE_DIR"/*.md; do
                    [ -f "$cmd_file" ] || continue
                    basename=$(basename "$cmd_file" .md)
                    echo "- **$basename**: $(head -1 "$cmd_file")"
                done
            } >"$codex_instructions"
            echo "Created: $codex_instructions"
            synced=$((synced + 1))
        fi
    fi
fi

echo ""
echo "Synced: $synced, Skipped: $skipped (already up-to-date or overridden)"
