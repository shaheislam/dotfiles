#!/usr/bin/env bash
# nvim-open-edited.sh - PostToolUse(Edit|Write|MultiEdit|ApplyPatch)
# Opens the edited file in the current tmux window's nvim pane via
# scripts/nvim-open-file.sh. Skips noise paths and never interrupts
# nvim insert mode. Silent always.
set -euo pipefail

INPUT=$(cat)
FILE_PATHS=$(echo "$INPUT" | jq -r '
  [
    .tool_input.file_path,
    .tool_input.filePath,
    .tool_input.notebook_path,
    .tool_input.path
  ]
  + (
    (.tool_input.patchText // .tool_input.patch_text // .tool_input.patch // "")
    | [scan("(?m)^\\*\\*\\* (?:(?:Add|Update) File: (.+)|Move to: (.+))$")[]?]
  )
  | .[]
  | select(. != null and . != "")
' 2>/dev/null || true)

[[ -z "$FILE_PATHS" ]] && exit 0
[[ -z "${TMUX:-}" ]] && exit 0

# Insert-mode guard: skip if user is actively typing in nvim.
# Probes any nvim listen socket; if mode() returns "i*", bail.
shopt -s nullglob 2>/dev/null || true
for sock in /tmp/nvim.*/[0-9]*/0 /tmp/nvim*.sock; do
    [[ -S "$sock" ]] || continue
    mode=$(nvim --server "$sock" --remote-expr 'mode()' 2>/dev/null || true)
    if [[ "$mode" == i* ]]; then
        exit 0
    fi
done

while IFS= read -r FILE_PATH; do
    [[ -z "$FILE_PATH" ]] && continue
    [[ ! -e "$FILE_PATH" ]] && continue

    case "$FILE_PATH" in
    */node_modules/* | */dist/* | */.git/* | */.beads/* | \
        */__pycache__/* | */.direnv/* | */.next/* | */.cache/* | \
        *.lock | */package-lock.json | *.pyc) continue ;;
    esac

    bash ~/dotfiles/scripts/nvim-open-file.sh "$FILE_PATH" >/dev/null 2>&1 || true
done <<<"$FILE_PATHS"
exit 0
