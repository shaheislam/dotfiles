#!/usr/bin/env bash
#
# phase-gates.sh - Pause/resume agent monitoring on external conditions
#
# A gate system that can pause agent monitoring when external conditions
# need to be met (CI pipeline, PR review, human input, dependency).
# Integrates with worktree-witness.sh - when a gate exists and is unresolved,
# the witness skips monitoring (agent is "gated").
#
# Gate Types:
#   ci-pipeline  - Wait for GitHub Actions CI to pass on the branch
#   pr-review    - Wait for PR to be approved
#   human-input  - Wait for human to signal (file-based)
#   dependency   - Wait for another worktree's agent to complete
#
# Usage:
#   phase-gates.sh check <gate-type> <worktree-path>     # Check if gate met (0=met, 1=not met)
#   phase-gates.sh wait <gate-type> <worktree-path>       # Block until met (--timeout)
#   phase-gates.sh create <gate-type> <worktree-path>     # Create a new gate
#   phase-gates.sh signal <worktree-path>                  # Signal human-input gate
#   phase-gates.sh list <worktree-path>                    # List active gates
#   phase-gates.sh clear <worktree-path>                   # Clear all gates
#
# Exit codes:
#   0 - Success / gate condition met
#   1 - Error or gate condition not met
#   2 - Timeout (wait command only)

set -euo pipefail

# Colors (matching existing scripts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_STATE="$SCRIPT_DIR/agent-state.sh"

VALID_GATE_TYPES=("ci-pipeline" "pr-review" "human-input" "dependency" "bd-bead")

# --- Helpers ---

gates_file() {
    local worktree="$1"
    echo "$worktree/.claude/gates.json"
}

ensure_gates_file() {
    local worktree="$1"
    local gf
    gf=$(gates_file "$worktree")
    mkdir -p "$(dirname "$gf")"
    if [[ ! -f "$gf" ]]; then
        echo '[]' >"$gf"
    fi
}

validate_gate_type() {
    local gate_type="$1"
    for valid in "${VALID_GATE_TYPES[@]}"; do
        if [[ "$gate_type" == "$valid" ]]; then
            return 0
        fi
    done
    echo -e "${RED}Error: Invalid gate type '$gate_type'${NC}" >&2
    echo "Valid types: ${VALID_GATE_TYPES[*]}" >&2
    return 1
}

validate_worktree() {
    local worktree="$1"
    if [[ ! -d "$worktree" ]]; then
        echo -e "${RED}Error: Not a directory: $worktree${NC}" >&2
        return 1
    fi
}

require_dep() {
    local cmd="$1" purpose="$2"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: '$cmd' not found (needed for $purpose)${NC}" >&2
        echo "Install: brew install $cmd" >&2
        return 1
    fi
}

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# --- Beads Gate Integration ---

# Check if bd is available and the worktree has a beads database
has_beads() {
    local worktree="$1"
    command -v bd &>/dev/null && [[ -d "$worktree/.beads" ]]
}

# Create a native bd gate (mirrors our local gate for Beads integration)
# Beads gate types: human, gh:run (ci), gh:pr (pr-review)
create_bd_gate() {
    local gate_type="$1" worktree="$2"
    has_beads "$worktree" || return 0

    local bd_type=""
    case "$gate_type" in
    ci-pipeline) bd_type="gh:run" ;;
    pr-review) bd_type="gh:pr" ;;
    human-input) bd_type="human" ;;
    *) return 0 ;; # No bd equivalent, skip
    esac

    local gate_title="gate: $gate_type for $(basename "$worktree")"
    (cd "$worktree" && bd create "$gate_title" --type=gate --labels "gt:gate,$bd_type" --silent 2>/dev/null) || true
}

# Check if a bd gate has been resolved
check_bd_gate_resolved() {
    local worktree="$1" gate_type="$2"
    has_beads "$worktree" || return 1

    # For gh:run and gh:pr gates, use bd gate check to evaluate
    (cd "$worktree" && bd gate check 2>/dev/null) || true
}

# Check a cross-rig bead gate (bd-bead gate type)
# Env: BD_AWAIT_ID = "<rig>:<bead-id>" format
check_bd_bead() {
    local worktree="$1"
    local await_id="${BD_AWAIT_ID:-}"

    if [[ -z "$await_id" ]]; then
        echo -e "${YELLOW}Warning: BD_AWAIT_ID not set for bd-bead gate${NC}" >&2
        return 1
    fi

    # Parse rig:bead-id format
    local rig bead_id
    rig="${await_id%%:*}"
    bead_id="${await_id#*:}"

    if [[ -z "$rig" || -z "$bead_id" ]]; then
        echo -e "${RED}Error: BD_AWAIT_ID must be in 'rig:bead-id' format (e.g. myproject:bd-abc12)${NC}" >&2
        return 1
    fi

    # Check if the referenced bead is closed (completed)
    local status
    status=$(bd show "$bead_id" --rig "$rig" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null) || status=""

    [[ "$status" == "closed" ]]
}

# --- Gate Check Implementations ---

check_ci_pipeline() {
    local worktree="$1"
    require_dep "gh" "ci-pipeline gate" || return 1

    local branch
    branch=$(git -C "$worktree" branch --show-current 2>/dev/null) || {
        echo -e "${RED}Error: Could not determine branch in $worktree${NC}" >&2
        return 1
    }

    local result
    result=$(gh run list --branch "$branch" --json status,conclusion --limit 1 2>/dev/null) || {
        echo -e "${YELLOW}Warning: Could not query GitHub Actions${NC}" >&2
        return 1
    }

    local conclusion
    conclusion=$(echo "$result" | jq -r '.[0].conclusion // empty' 2>/dev/null)

    if [[ "$conclusion" == "success" ]]; then
        return 0
    fi
    return 1
}

check_pr_review() {
    local worktree="$1"
    require_dep "gh" "pr-review gate" || return 1

    local branch
    branch=$(git -C "$worktree" branch --show-current 2>/dev/null) || {
        echo -e "${RED}Error: Could not determine branch in $worktree${NC}" >&2
        return 1
    }

    local decision
    decision=$(gh pr view "$branch" --json reviewDecision -q '.reviewDecision' 2>/dev/null) || {
        echo -e "${YELLOW}Warning: Could not query PR review status${NC}" >&2
        return 1
    }

    if [[ "$decision" == "APPROVED" ]]; then
        return 0
    fi
    return 1
}

check_human_input() {
    local worktree="$1"
    local signal_file="$worktree/.claude/gate-signal"

    if [[ -f "$signal_file" ]]; then
        rm -f "$signal_file"
        return 0
    fi
    return 1
}

check_dependency() {
    local worktree="$1"

    # Read metadata from the gate entry to find the dependency worktree
    local gf
    gf=$(gates_file "$worktree")
    [[ -f "$gf" ]] || return 1

    local dep_path
    dep_path=$(jq -r '[.[] | select(.type == "dependency" and .resolved == false)] | .[0].metadata.dependency_worktree // empty' "$gf" 2>/dev/null)

    if [[ -z "$dep_path" ]]; then
        echo -e "${YELLOW}Warning: No dependency worktree configured in gate metadata${NC}" >&2
        return 1
    fi

    if [[ ! -x "$AGENT_STATE" ]]; then
        echo -e "${RED}Error: agent-state.sh not found at $AGENT_STATE${NC}" >&2
        return 1
    fi

    local state
    state=$("$AGENT_STATE" "$dep_path" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',''))" 2>/dev/null) || state=""

    if [[ "$state" == "completed" ]]; then
        return 0
    fi
    return 1
}

# Dispatch gate check by type
check_gate() {
    local gate_type="$1" worktree="$2"

    case "$gate_type" in
    ci-pipeline) check_ci_pipeline "$worktree" ;;
    pr-review) check_pr_review "$worktree" ;;
    human-input) check_human_input "$worktree" ;;
    dependency) check_dependency "$worktree" ;;
    bd-bead) check_bd_bead "$worktree" ;;
    *)
        echo -e "${RED}Error: Unknown gate type '$gate_type'${NC}" >&2
        return 1
        ;;
    esac
}

# Mark a gate as resolved in the JSON file
mark_resolved() {
    local gate_type="$1" worktree="$2"
    local gf
    gf=$(gates_file "$worktree")
    [[ -f "$gf" ]] || return 0

    local tmp
    tmp=$(mktemp)
    jq --arg type "$gate_type" --arg now "$(timestamp_now)" \
        '[.[] | if (.type == $type and .resolved == false) then .resolved = true | .resolved_at = $now else . end]' \
        "$gf" >"$tmp" && mv "$tmp" "$gf"
}

# --- Commands ---

cmd_check() {
    local gate_type="$1" worktree="$2"
    validate_gate_type "$gate_type" || exit 1
    validate_worktree "$worktree" || exit 1
    require_dep "jq" "gate management" || exit 1

    if check_gate "$gate_type" "$worktree"; then
        mark_resolved "$gate_type" "$worktree"
        echo -e "${GREEN}Gate met: $gate_type${NC}"
        exit 0
    else
        echo -e "${YELLOW}Gate not met: $gate_type${NC}"
        exit 1
    fi
}

cmd_wait() {
    local gate_type="$1" worktree="$2" timeout="${3:-3600}"
    validate_gate_type "$gate_type" || exit 1
    validate_worktree "$worktree" || exit 1
    require_dep "jq" "gate management" || exit 1

    echo -e "${BLUE}Waiting for gate: $gate_type (timeout: ${timeout}s)${NC}"

    local start
    start=$(date +%s)

    while true; do
        if check_gate "$gate_type" "$worktree"; then
            mark_resolved "$gate_type" "$worktree"
            echo -e "${GREEN}Gate met: $gate_type${NC}"
            exit 0
        fi

        local elapsed=$(($(date +%s) - start))
        if [[ "$elapsed" -ge "$timeout" ]]; then
            echo -e "${RED}Timeout waiting for gate: $gate_type (${timeout}s)${NC}"
            exit 2
        fi

        sleep 15
    done
}

cmd_create() {
    local gate_type="$1" worktree="$2"
    validate_gate_type "$gate_type" || exit 1
    validate_worktree "$worktree" || exit 1
    require_dep "jq" "gate management" || exit 1

    ensure_gates_file "$worktree"
    local gf
    gf=$(gates_file "$worktree")

    # Check for existing unresolved gate of same type
    local existing
    existing=$(jq --arg type "$gate_type" \
        '[.[] | select(.type == $type and .resolved == false)] | length' "$gf")

    if [[ "$existing" -gt 0 ]]; then
        echo -e "${YELLOW}Gate already exists: $gate_type (unresolved)${NC}"
        exit 0
    fi

    # Build metadata based on gate type
    local metadata='{}'
    case "$gate_type" in
    ci-pipeline | pr-review)
        local branch
        branch=$(git -C "$worktree" branch --show-current 2>/dev/null || echo "")
        metadata=$(jq -n --arg branch "$branch" '{"branch": $branch}')
        ;;
    human-input)
        metadata='{"signal_file": ".claude/gate-signal"}'
        ;;
    dependency)
        local dep_path="${DEP_WORKTREE:-}"
        if [[ -z "$dep_path" ]]; then
            echo -e "${RED}Error: Set DEP_WORKTREE env var for dependency gate${NC}" >&2
            echo "Usage: DEP_WORKTREE=/path/to/other/worktree phase-gates.sh create dependency <worktree>" >&2
            exit 1
        fi
        metadata=$(jq -n --arg dep "$dep_path" '{"dependency_worktree": $dep}')
        ;;
    esac

    # Add gate entry
    local tmp
    tmp=$(mktemp)
    jq --arg type "$gate_type" --arg now "$(timestamp_now)" --argjson meta "$metadata" \
        '. += [{
            "type": $type,
            "created_at": $now,
            "resolved": false,
            "resolved_at": null,
            "metadata": $meta
        }]' "$gf" >"$tmp" && mv "$tmp" "$gf"

    echo -e "${GREEN}Gate created: $gate_type${NC}"

    # Mirror to native Beads gate when available (enables bd gate check integration)
    create_bd_gate "$gate_type" "$worktree"

    # For human-input, hint about how to signal
    if [[ "$gate_type" == "human-input" ]]; then
        echo -e "  Signal with: ${BLUE}phase-gates.sh signal $worktree${NC}"
    fi
    # For bd-bead, hint about the await_id
    if [[ "$gate_type" == "bd-bead" ]]; then
        echo -e "  Set ${BLUE}BD_AWAIT_ID=<rig>:<bead-id>${NC} when checking"
    fi
}

cmd_signal() {
    local worktree="$1"
    validate_worktree "$worktree" || exit 1

    local signal_file="$worktree/.claude/gate-signal"
    mkdir -p "$(dirname "$signal_file")"
    echo "$(timestamp_now)" >"$signal_file"

    echo -e "${GREEN}Signal sent: human-input gate for $(basename "$worktree")${NC}"
}

cmd_list() {
    local worktree="$1"
    validate_worktree "$worktree" || exit 1
    require_dep "jq" "gate management" || exit 1

    local gf
    gf=$(gates_file "$worktree")

    if [[ ! -f "$gf" ]]; then
        echo -e "${YELLOW}No gates for $(basename "$worktree")${NC}"
        exit 0
    fi

    local count
    count=$(jq 'length' "$gf")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No gates for $(basename "$worktree")${NC}"
        exit 0
    fi

    echo -e "${BLUE}=== Phase Gates ($(basename "$worktree")) ===${NC}"
    echo ""

    local i=0
    while [[ $i -lt $count ]]; do
        local type resolved created_at resolved_at
        type=$(jq -r ".[$i].type" "$gf")
        resolved=$(jq -r ".[$i].resolved" "$gf")
        created_at=$(jq -r ".[$i].created_at" "$gf")
        resolved_at=$(jq -r ".[$i].resolved_at // \"—\"" "$gf")

        local color icon
        if [[ "$resolved" == "true" ]]; then
            color="$GREEN"
            icon="✓"
        else
            color="$YELLOW"
            icon="⏳"
        fi

        echo -e "  ${icon} ${color}${type}${NC}"
        echo -e "    Created:  $created_at"
        if [[ "$resolved" == "true" ]]; then
            echo -e "    Resolved: $resolved_at"
        fi

        # Show metadata
        local meta
        meta=$(jq -r ".[$i].metadata | to_entries[] | \"    \\(.key): \\(.value)\"" "$gf" 2>/dev/null) || true
        if [[ -n "$meta" ]]; then
            echo "$meta"
        fi
        echo ""

        i=$((i + 1))
    done
}

cmd_clear() {
    local worktree="$1"
    validate_worktree "$worktree" || exit 1

    local gf
    gf=$(gates_file "$worktree")

    if [[ -f "$gf" ]]; then
        echo '[]' >"$gf"
    fi

    # Also clean up any signal file
    rm -f "$worktree/.claude/gate-signal"

    echo -e "${GREEN}Gates cleared for $(basename "$worktree")${NC}"
}

# Utility: check if any unresolved gates exist (used by worktree-witness.sh)
cmd_has_active() {
    local worktree="$1"
    local gf
    gf=$(gates_file "$worktree")

    if [[ ! -f "$gf" ]]; then
        exit 1 # no gates file = no active gates
    fi

    require_dep "jq" "gate management" || exit 1

    local active
    active=$(jq '[.[] | select(.resolved == false)] | length' "$gf" 2>/dev/null) || active=0

    if [[ "$active" -gt 0 ]]; then
        exit 0 # has active gates
    fi
    exit 1 # no active gates
}

# --- Main ---

show_help() {
    cat <<'EOF'
phase-gates.sh - Pause/resume agent monitoring on external conditions

USAGE:
  phase-gates.sh check <gate-type> <worktree-path>      Check if gate condition met
  phase-gates.sh wait <gate-type> <worktree-path>        Block until condition met
  phase-gates.sh create <gate-type> <worktree-path>      Create a new gate
  phase-gates.sh signal <worktree-path>                   Signal human-input gate
  phase-gates.sh list <worktree-path>                     List active gates
  phase-gates.sh clear <worktree-path>                    Clear all gates
  phase-gates.sh has-active <worktree-path>               Exit 0 if active gates exist

GATE TYPES:
  ci-pipeline    Wait for GitHub Actions CI to pass (mirrors to bd gh:run gate)
  pr-review      Wait for PR to be approved (mirrors to bd gh:pr gate)
  human-input    Wait for human to signal (file-based, mirrors to bd human gate)
  dependency     Wait for another worktree's agent to complete
  bd-bead        Wait for a cross-rig bead to close (set BD_AWAIT_ID=<rig>:<bead-id>)

OPTIONS:
  --timeout N    Seconds to wait before timeout (default: 3600, wait command only)

ENVIRONMENT:
  DEP_WORKTREE   Path to dependency worktree (for 'dependency' gate type)

EXIT CODES:
  0 - Success / gate condition met / active gates exist
  1 - Error / gate condition not met / no active gates
  2 - Timeout (wait command only)

EXAMPLES:
  # Wait for CI before continuing
  phase-gates.sh create ci-pipeline /path/to/worktree
  phase-gates.sh wait ci-pipeline /path/to/worktree --timeout 1800

  # Gate on PR review
  phase-gates.sh create pr-review /path/to/worktree
  phase-gates.sh check pr-review /path/to/worktree

  # Human approval gate
  phase-gates.sh create human-input /path/to/worktree
  # ... later, from another terminal:
  phase-gates.sh signal /path/to/worktree

  # Dependency on another agent
  DEP_WORKTREE=/path/to/other phase-gates.sh create dependency /path/to/worktree

  # Wait for a bead in another rig to close (Beads native cross-rig gate)
  phase-gates.sh create bd-bead /path/to/worktree
  BD_AWAIT_ID=myproject:bd-abc12 phase-gates.sh check bd-bead /path/to/worktree
EOF
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
check)
    if [[ $# -lt 2 ]]; then
        echo -e "${RED}Error: gate-type and worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh check <gate-type> <worktree-path>" >&2
        exit 1
    fi
    cmd_check "$1" "$2"
    ;;
wait)
    if [[ $# -lt 2 ]]; then
        echo -e "${RED}Error: gate-type and worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh wait <gate-type> <worktree-path> [--timeout N]" >&2
        exit 1
    fi
    gate_type="$1"
    worktree="$2"
    shift 2
    timeout=3600
    while [[ $# -gt 0 ]]; do
        case $1 in
        --timeout)
            timeout="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        esac
    done
    cmd_wait "$gate_type" "$worktree" "$timeout"
    ;;
create)
    if [[ $# -lt 2 ]]; then
        echo -e "${RED}Error: gate-type and worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh create <gate-type> <worktree-path>" >&2
        exit 1
    fi
    cmd_create "$1" "$2"
    ;;
signal)
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error: worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh signal <worktree-path>" >&2
        exit 1
    fi
    cmd_signal "$1"
    ;;
list)
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error: worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh list <worktree-path>" >&2
        exit 1
    fi
    cmd_list "$1"
    ;;
clear)
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error: worktree-path required${NC}" >&2
        echo "Usage: phase-gates.sh clear <worktree-path>" >&2
        exit 1
    fi
    cmd_clear "$1"
    ;;
has-active)
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error: worktree-path required${NC}" >&2
        exit 1
    fi
    cmd_has_active "$1"
    ;;
--help | -h | help)
    show_help
    ;;
"")
    show_help
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    echo "Run 'phase-gates.sh --help' for usage" >&2
    exit 1
    ;;
esac
