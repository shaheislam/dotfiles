#!/bin/bash
set -euo pipefail
# WorktreeCreate hook - initialize new worktrees with beads + checkpoints

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // ""' 2>/dev/null || echo "")

if [ -z "$WORKTREE_PATH" ]; then
    exit 0
fi

LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-$(date +%Y-%m-%d).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeCreate: $WORKTREE_PATH" >>"$LOG_FILE"

# Initialize beads/checkpoints without holding the WorktreeCreate hook. These
# only need to be ready by the first agent commit, not before Claude continues.
(
    run_init_step() {
        local label="$1"
        shift
        local timeout_secs="${WORKTREE_INIT_TIMEOUT:-10}"
        local output=""
        local rc=0

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeCreate: ${label} start (timeout ${timeout_secs}s)" >>"$LOG_FILE"

        set +e
        if command -v timeout >/dev/null 2>&1; then
            output=$(cd "$WORKTREE_PATH" && timeout "$timeout_secs" "$@" 2>&1)
            rc=$?
        elif command -v gtimeout >/dev/null 2>&1; then
            output=$(cd "$WORKTREE_PATH" && gtimeout "$timeout_secs" "$@" 2>&1)
            rc=$?
        elif command -v python3 >/dev/null 2>&1; then
            output=$(cd "$WORKTREE_PATH" && python3 - "$timeout_secs" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
cmd = sys.argv[2:]

try:
    proc = subprocess.run(
        cmd,
        timeout=timeout,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if proc.stdout:
        sys.stdout.write(proc.stdout)
    sys.exit(proc.returncode)
except subprocess.TimeoutExpired as exc:
    output = exc.stdout or ""
    if isinstance(output, bytes):
        output = output.decode(errors="replace")
    if output:
        sys.stdout.write(output)
    print(f"timed out after {timeout:g}s", file=sys.stderr)
    sys.exit(124)
PY
)
            rc=$?
        else
            output=$(cd "$WORKTREE_PATH" && "$@" 2>&1)
            rc=$?
            output="timeout unavailable; ran without bound
${output}"
        fi
        set -e

        if [[ $rc -eq 0 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeCreate: ${label} ok" >>"$LOG_FILE"
        else
            {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeCreate: ${label} rc=${rc}"
                printf '%s\n' "$output" | head -25
                echo "---"
            } >>"$LOG_FILE"
        fi
    }

    if command -v bd &>/dev/null; then
        run_init_step "bd prime" bd prime
    fi

    if command -v entire &>/dev/null; then
        run_init_step "entire enable" entire enable
    fi
) </dev/null >/dev/null 2>&1 &

exit 0
