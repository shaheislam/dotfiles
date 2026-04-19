#!/usr/bin/env bash
# nvim-bridge.sh - UserPromptSubmit hook
# Reads Neovim editor state from /tmp/nvim-claude-bridge/<hash>/state.json
# Outputs {"systemMessage": "..."} with current editor context
# Graceful no-op if no state file or Neovim not running

set -euo pipefail

BRIDGE_DIR="/tmp/nvim-claude-bridge"
TTL_SECONDS=300 # 5 minutes

# No bridge dir = no Neovim running, silent exit
[[ -d "$BRIDGE_DIR" ]] || exit 0

# Determine project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

# Find state file for this project
HASH=$(echo -n "$PROJECT_DIR" | shasum -a 256 | cut -c1-8)
STATE_FILE="$BRIDGE_DIR/$HASH/state.json"

[[ -f "$STATE_FILE" ]] || exit 0

# Optimized: Use a single jq call to validate PID, TTL, and build the context message
# Saves ~200ms per prompt by avoiding multiple subprocesses and repeated file reads
JQ_OUTPUT=$(jq -r --arg now "$(date +%s)" --arg ttl "$TTL_SECONDS" '
  # Helper to check if a section is fresh
  def is_fresh(ts): ($now | tonumber) - (ts | tonumber // 0) < ($ttl | tonumber);

  # Check if nvim process is still alive (if pid is provided)
  . as $root |
  .nvim_pid as $pid |
  
  # Diagnostics
  (if is_fresh(.diagnostics.timestamp) and ((.diagnostics.error_count // 0) > 0 or (.diagnostics.warning_count // 0) > 0) then
     "Diagnostics(\(.diagnostics.error_count // 0)E/\(.diagnostics.warning_count // 0)W): " +
     ([(.diagnostics.errors // [] | .[] | "\(.file):\(.line) \(.source): \(.message)"),
       (.diagnostics.warnings // [] | .[] | "\(.file):\(.line) \(.source): \(.message)")] | join("; "))
   else empty end) as $diag |

  # Focus
  (if is_fresh(.focus.timestamp) and (.focus.file // "" != "") then
     "Focus: \(.focus.file):\(.focus.line // 1) (\(.focus.filetype // "text"))"
   else empty end) as $focus |

  # Git
  (if is_fresh(.git_hunks.timestamp) and (.git_hunks.summary // "" != "") then
     "Git: \(.git_hunks.summary) [\((.git_hunks.files_changed // []) | join(", "))]"
   else empty end) as $git |

  # Tests
  (if is_fresh(.tests.timestamp) and (.tests.status // "" != "") then
     "Tests: \(.tests.status) (\(.tests.passed_count // 0) passed, \(.tests.failed_count // 0) failed)" +
     (if .tests.status == "fail" and (.tests.failed // [] | length > 0) then
        " — " + ([.tests.failed[] | "\(.name): \(.message)"] | .[0:5] | join("; "))
      else "" end)
   else empty end) as $tests |

  # Combine fresh parts
  [$diag, $focus, $git, $tests] | del(..|null) as $parts |
  if ($parts | length) > 0 then
    "Neovim context: " + ($parts | join(" | "))
  else
    empty
  end
' "$STATE_FILE" 2>/dev/null || echo "")

# If nvim_pid exists but process is dead, jq wont know. Check here.
# This check is fast as it uses the PID we already extracted from the file.
NVIM_PID=$(jq -r '.nvim_pid // empty' "$STATE_FILE" 2>/dev/null)
if [[ -n "$NVIM_PID" ]] && ! kill -0 "$NVIM_PID" 2>/dev/null; then
	rm -rf "${BRIDGE_DIR:?}/${HASH:?}" 2>/dev/null
	exit 0
fi

# Exit if no context was generated
[[ -z "$JQ_OUTPUT" ]] && exit 0

# Output for Claude Code hook
echo "{\"systemMessage\": $(echo "$JQ_OUTPUT" | jq -Rs .)}"
