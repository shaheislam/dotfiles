#!/usr/bin/env bash
#
# agent-cv.sh - JSONL-based per-worker CV tracking
#
# Records the lifecycle of each autonomous agent run as a JSONL timeline,
# enabling post-mortem analysis, aggregate stats, and performance tracking
# across agent executions.
#
# Storage:
#   Per-worktree:  $WORKTREE_PATH/.claude/worker-cv.jsonl
#   Permanent:     ~/.claude/agent-cvs/<issue-key>.jsonl (copied on completion)
#
# Usage:
#   agent-cv.sh init <worktree> --issue <key> --title <title> [--sub <profile>] [--model <model>]
#   agent-cv.sh log <worktree> --event <type> --detail <msg>
#   agent-cv.sh show <worktree>
#   agent-cv.sh summary [--all]
#
# Event types:
#   init, started, iteration, stuck, triage, crash, retry, completed, failed, merged
#
# Exit codes:
#   0 - Success
#   1 - Error (bad args, missing deps)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ARCHIVE_DIR="${HOME}/.claude/agent-cvs"
VALID_EVENTS="init started iteration stuck triage crash retry completed failed merged"

# --- Helpers ---

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

cv_path() {
    local worktree="$1"
    echo "${worktree}/.claude/worker-cv.jsonl"
}

ensure_archive_dir() {
    mkdir -p "$ARCHIVE_DIR"
}

validate_event() {
    local event="$1"
    for valid in $VALID_EVENTS; do
        if [[ "$event" == "$valid" ]]; then
            return 0
        fi
    done
    echo -e "${RED}Error: Invalid event type '$event'${NC}" >&2
    echo "Valid types: $VALID_EVENTS" >&2
    return 1
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

append_entry() {
    local cv_file="$1"
    local json="$2"
    mkdir -p "$(dirname "$cv_file")"
    echo "$json" >>"$cv_file"
}

# --- Commands ---

cmd_init() {
    local worktree=""
    local issue_key=""
    local title=""
    local sub=""
    local model=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --issue)
            issue_key="$2"
            shift 2
            ;;
        --title)
            title="$2"
            shift 2
            ;;
        --sub)
            sub="$2"
            shift 2
            ;;
        --model)
            model="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            worktree="$1"
            shift
            ;;
        esac
    done

    if [[ -z "$worktree" || -z "$issue_key" || -z "$title" ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}" >&2
        echo "Usage: agent-cv.sh init <worktree> --issue <key> --title <title> [--sub <profile>] [--model <model>]" >&2
        exit 1
    fi

    # Resolve to absolute path
    worktree="$(cd "$worktree" 2>/dev/null && pwd || echo "$worktree")"

    local cv_file
    cv_file="$(cv_path "$worktree")"

    local ts
    ts="$(timestamp_now)"

    local json
    json=$(printf '{"timestamp":"%s","event":"init","issue_key":"%s","title":"%s","sub":"%s","model":"%s","detail":"CV initialized"}' \
        "$ts" \
        "$(json_escape "$issue_key")" \
        "$(json_escape "$title")" \
        "$(json_escape "$sub")" \
        "$(json_escape "$model")")

    append_entry "$cv_file" "$json"

    echo -e "${GREEN}CV initialized${NC} for ${BOLD}${issue_key}${NC} at ${DIM}${cv_file}${NC}"
}

cmd_log() {
    local worktree=""
    local event=""
    local detail=""
    local iteration=""
    local duration_s=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --event)
            event="$2"
            shift 2
            ;;
        --detail)
            detail="$2"
            shift 2
            ;;
        --iteration)
            iteration="$2"
            shift 2
            ;;
        --duration)
            duration_s="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            worktree="$1"
            shift
            ;;
        esac
    done

    if [[ -z "$worktree" || -z "$event" ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}" >&2
        echo "Usage: agent-cv.sh log <worktree> --event <type> --detail <msg> [--iteration N] [--duration N]" >&2
        exit 1
    fi

    validate_event "$event"

    worktree="$(cd "$worktree" 2>/dev/null && pwd || echo "$worktree")"

    local cv_file
    cv_file="$(cv_path "$worktree")"

    if [[ ! -f "$cv_file" ]]; then
        echo -e "${YELLOW}Warning: No CV found at ${cv_file}, creating entry anyway${NC}" >&2
    fi

    local ts
    ts="$(timestamp_now)"

    # Build JSON with optional fields
    local json
    json=$(printf '{"timestamp":"%s","event":"%s","detail":"%s"' \
        "$ts" \
        "$(json_escape "$event")" \
        "$(json_escape "$detail")")

    if [[ -n "$iteration" ]]; then
        json="${json},\"iteration\":${iteration}"
    fi
    if [[ -n "$duration_s" ]]; then
        json="${json},\"duration_s\":${duration_s}"
    fi

    # Pull issue_key from init entry if available
    if [[ -f "$cv_file" ]]; then
        local issue_key
        issue_key=$(head -1 "$cv_file" | grep -o '"issue_key":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        if [[ -n "$issue_key" ]]; then
            json="${json},\"issue_key\":\"$(json_escape "$issue_key")\""
        fi
    fi

    json="${json}}"

    append_entry "$cv_file" "$json"

    # Archive on terminal events
    if [[ "$event" == "completed" || "$event" == "failed" || "$event" == "merged" ]]; then
        archive_cv "$worktree"
    fi

    echo -e "${GREEN}Logged${NC} ${BOLD}${event}${NC}: ${detail}"
}

archive_cv() {
    local worktree="$1"
    local cv_file
    cv_file="$(cv_path "$worktree")"

    if [[ ! -f "$cv_file" ]]; then
        return 0
    fi

    ensure_archive_dir

    # Extract issue key from init entry
    local issue_key
    issue_key=$(head -1 "$cv_file" | grep -o '"issue_key":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

    if [[ -z "$issue_key" ]]; then
        issue_key="unknown-$(basename "$worktree")"
    fi

    local archive_file="${ARCHIVE_DIR}/${issue_key}.jsonl"
    cp "$cv_file" "$archive_file"
    echo -e "${DIM}Archived to ${archive_file}${NC}"
}

cmd_show() {
    local worktree="$1"

    if [[ -z "$worktree" ]]; then
        echo -e "${RED}Error: Missing worktree path${NC}" >&2
        echo "Usage: agent-cv.sh show <worktree>" >&2
        exit 1
    fi

    worktree="$(cd "$worktree" 2>/dev/null && pwd || echo "$worktree")"

    local cv_file
    cv_file="$(cv_path "$worktree")"

    # Also check archive if worktree CV doesn't exist
    if [[ ! -f "$cv_file" ]]; then
        # Try treating argument as an issue key in the archive
        local archive_candidate="${ARCHIVE_DIR}/${worktree}.jsonl"
        if [[ -f "$archive_candidate" ]]; then
            cv_file="$archive_candidate"
        else
            echo -e "${RED}Error: No CV found at ${cv_file}${NC}" >&2
            exit 1
        fi
    fi

    # Read init entry for header
    local init_line
    init_line=$(head -1 "$cv_file")

    local issue_key title sub model
    issue_key=$(echo "$init_line" | grep -o '"issue_key":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    title=$(echo "$init_line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 || echo "untitled")
    sub=$(echo "$init_line" | grep -o '"sub":"[^"]*"' | cut -d'"' -f4 || true)
    model=$(echo "$init_line" | grep -o '"model":"[^"]*"' | cut -d'"' -f4 || true)

    echo ""
    echo -e "${BOLD}${BLUE}Agent CV: ${issue_key}${NC}"
    echo -e "${BOLD}Title:${NC} ${title}"
    if [[ -n "$sub" ]]; then
        echo -e "${BOLD}Profile:${NC} ${sub}"
    fi
    if [[ -n "$model" ]]; then
        echo -e "${BOLD}Model:${NC} ${model}"
    fi
    echo -e "${DIM}$(printf '%.0s─' {1..60})${NC}"
    echo ""

    # Print timeline
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        local ts event detail iteration duration_s
        ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || true)
        event=$(echo "$line" | grep -o '"event":"[^"]*"' | cut -d'"' -f4 || true)
        detail=$(echo "$line" | grep -o '"detail":"[^"]*"' | cut -d'"' -f4 || true)
        iteration=$(echo "$line" | grep -o '"iteration":[0-9]*' | cut -d: -f2 || true)
        duration_s=$(echo "$line" | grep -o '"duration_s":[0-9]*' | cut -d: -f2 || true)

        # Color based on event type
        local color="$NC"
        local icon=" "
        case "$event" in
        init)
            color="$BLUE"
            icon="+"
            ;;
        started)
            color="$GREEN"
            icon=">"
            ;;
        iteration)
            color="$CYAN"
            icon="~"
            ;;
        stuck)
            color="$YELLOW"
            icon="!"
            ;;
        triage)
            color="$MAGENTA"
            icon="?"
            ;;
        crash)
            color="$RED"
            icon="x"
            ;;
        retry)
            color="$YELLOW"
            icon="r"
            ;;
        completed)
            color="$GREEN"
            icon="*"
            ;;
        failed)
            color="$RED"
            icon="X"
            ;;
        merged)
            color="$GREEN"
            icon="M"
            ;;
        esac

        # Format timestamp (show time only if same day)
        local short_ts="${ts:-unknown}"
        if [[ -n "$ts" ]]; then
            short_ts="${ts:11:8}" # HH:MM:SS
            if [[ $line_num -eq 1 ]]; then
                short_ts="${ts:0:10} ${ts:11:8}" # Full date on first entry
            fi
        fi

        local suffix=""
        if [[ -n "$iteration" ]]; then
            suffix="${suffix} ${DIM}(iter ${iteration})${NC}"
        fi
        if [[ -n "$duration_s" ]]; then
            suffix="${suffix} ${DIM}[${duration_s}s]${NC}"
        fi

        echo -e "  ${DIM}${short_ts}${NC}  ${color}${icon} ${BOLD}${event}${NC}${color}: ${detail}${NC}${suffix}"

    done <"$cv_file"

    echo ""

    # Calculate total duration if we have init and a terminal event
    local first_ts last_ts
    first_ts=$(head -1 "$cv_file" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || true)
    last_ts=$(tail -1 "$cv_file" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ -n "$first_ts" && -n "$last_ts" && "$first_ts" != "$last_ts" ]]; then
        # Use date for duration calculation (macOS compatible)
        local start_epoch end_epoch
        if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$first_ts" "+%s" &>/dev/null; then
            # macOS
            start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$first_ts" "+%s")
            end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_ts" "+%s")
        elif date -d "$first_ts" "+%s" &>/dev/null; then
            # GNU/Linux
            start_epoch=$(date -d "$first_ts" "+%s")
            end_epoch=$(date -d "$last_ts" "+%s")
        else
            start_epoch=0
            end_epoch=0
        fi

        if [[ $start_epoch -gt 0 && $end_epoch -gt 0 ]]; then
            local total_s=$((end_epoch - start_epoch))
            local hours=$((total_s / 3600))
            local mins=$(((total_s % 3600) / 60))
            echo -e "${DIM}Total elapsed: ${hours}h ${mins}m${NC}"
        fi
    fi

    # Count events
    local total_events iteration_count
    total_events=$(wc -l <"$cv_file" | tr -d ' ')
    iteration_count=$(grep -c '"event":"iteration"' "$cv_file" || echo 0)
    echo -e "${DIM}Events: ${total_events} | Iterations: ${iteration_count}${NC}"
    echo ""
}

cmd_summary() {
    local show_all=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --all)
            show_all=true
            shift
            ;;
        --help | -h)
            echo "Usage: agent-cv.sh summary [--all]"
            echo ""
            echo "Aggregate stats from archived CVs in ~/.claude/agent-cvs/"
            echo ""
            echo "Options:"
            echo "  --all    Include CVs from active worktrees too"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument $1${NC}" >&2
            exit 1
            ;;
        esac
    done

    ensure_archive_dir

    local cv_files=()

    # Collect archived CVs
    if compgen -G "${ARCHIVE_DIR}/*.jsonl" >/dev/null 2>&1; then
        for f in "${ARCHIVE_DIR}"/*.jsonl; do
            cv_files+=("$f")
        done
    fi

    # Optionally scan active worktrees
    if $show_all; then
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
        if [[ -n "$git_root" ]]; then
            while IFS= read -r wt_dir; do
                local wt_cv="${wt_dir}/.claude/worker-cv.jsonl"
                if [[ -f "$wt_cv" ]]; then
                    # Avoid duplicates
                    local is_dup=false
                    for existing in "${cv_files[@]}"; do
                        if [[ "$existing" == "$wt_cv" ]]; then
                            is_dup=true
                            break
                        fi
                    done
                    if ! $is_dup; then
                        cv_files+=("$wt_cv")
                    fi
                fi
            done < <(git worktree list --porcelain 2>/dev/null | grep '^worktree ' | cut -d' ' -f2-)
        fi
    fi

    if [[ ${#cv_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No CVs found in ${ARCHIVE_DIR}/${NC}"
        echo "Run agent-cv.sh init to create a CV, or use --all to scan worktrees."
        exit 0
    fi

    # Aggregate stats
    local total_cvs=0
    local completed=0
    local failed=0
    local merged=0
    local total_iterations=0
    local total_crashes=0
    local total_retries=0
    local total_stuck=0

    echo ""
    echo -e "${BOLD}${BLUE}Agent CV Summary${NC}"
    echo -e "${DIM}$(printf '%.0s─' {1..72})${NC}"
    printf "  ${BOLD}%-16s %-30s %6s %6s %6s${NC}\n" "Issue" "Title" "Iters" "Status" "Events"
    echo -e "${DIM}$(printf '%.0s─' {1..72})${NC}"

    for cv_file in "${cv_files[@]}"; do
        total_cvs=$((total_cvs + 1))

        local init_line
        init_line=$(head -1 "$cv_file")

        local issue_key title
        issue_key=$(echo "$init_line" | grep -o '"issue_key":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        title=$(echo "$init_line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 || echo "untitled")

        # Truncate title
        if [[ ${#title} -gt 28 ]]; then
            title="${title:0:25}..."
        fi

        local event_count iter_count status_label status_color
        event_count=$(wc -l <"$cv_file" | tr -d ' ')
        iter_count=$(grep -c '"event":"iteration"' "$cv_file" || echo 0)
        total_iterations=$((total_iterations + iter_count))
        total_crashes=$((total_crashes + $(grep -c '"event":"crash"' "$cv_file" || echo 0)))
        total_retries=$((total_retries + $(grep -c '"event":"retry"' "$cv_file" || echo 0)))
        total_stuck=$((total_stuck + $(grep -c '"event":"stuck"' "$cv_file" || echo 0)))

        # Determine final status
        local last_event
        last_event=$(tail -1 "$cv_file" | grep -o '"event":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

        case "$last_event" in
        completed)
            status_label="done"
            status_color="$GREEN"
            completed=$((completed + 1))
            ;;
        failed)
            status_label="fail"
            status_color="$RED"
            failed=$((failed + 1))
            ;;
        merged)
            status_label="merged"
            status_color="$GREEN"
            merged=$((merged + 1))
            ;;
        *)
            status_label="active"
            status_color="$YELLOW"
            ;;
        esac

        printf "  %-16s %-30s %6s ${status_color}%6s${NC} %6s\n" \
            "$issue_key" "$title" "$iter_count" "$status_label" "$event_count"
    done

    echo -e "${DIM}$(printf '%.0s─' {1..72})${NC}"
    echo ""
    echo -e "${BOLD}Totals:${NC}"
    echo -e "  CVs: ${total_cvs} | ${GREEN}Completed: ${completed}${NC} | ${GREEN}Merged: ${merged}${NC} | ${RED}Failed: ${failed}${NC}"
    echo -e "  Iterations: ${total_iterations} | Crashes: ${total_crashes} | Retries: ${total_retries} | Stuck: ${total_stuck}"

    if [[ $total_cvs -gt 0 ]]; then
        local avg_iter=$((total_iterations / total_cvs))
        echo -e "  Avg iterations/ticket: ${avg_iter}"
    fi
    echo ""
}

# --- Main ---

show_help() {
    echo "agent-cv.sh - JSONL-based per-worker CV tracking"
    echo ""
    echo "USAGE:"
    echo "  agent-cv.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  init <worktree> --issue <key> --title <title> [--sub <p>] [--model <m>]"
    echo "                              Initialize CV for a new agent run"
    echo "  log <worktree> --event <type> --detail <msg> [--iteration N] [--duration N]"
    echo "                              Append lifecycle event to CV"
    echo "  show <worktree>             Pretty-print CV timeline"
    echo "  summary [--all]             Aggregate stats across archived CVs"
    echo ""
    echo "EVENT TYPES:"
    echo "  init, started, iteration, stuck, triage, crash, retry,"
    echo "  completed, failed, merged"
    echo ""
    echo "STORAGE:"
    echo "  Per-worktree:  <worktree>/.claude/worker-cv.jsonl"
    echo "  Archive:       ~/.claude/agent-cvs/<issue-key>.jsonl"
    echo ""
    echo "EXAMPLES:"
    echo "  agent-cv.sh init ./wt-auth --issue ENG-123 --title 'Fix auth' --sub personal"
    echo "  agent-cv.sh log ./wt-auth --event started --detail 'Ralph-loop begin'"
    echo "  agent-cv.sh log ./wt-auth --event iteration --detail 'Tests passing' --iteration 3"
    echo "  agent-cv.sh log ./wt-auth --event completed --detail 'All tests green' --duration 1800"
    echo "  agent-cv.sh show ./wt-auth"
    echo "  agent-cv.sh summary --all"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
init)
    cmd_init "$@"
    ;;
log)
    cmd_log "$@"
    ;;
show)
    cmd_show "$@"
    ;;
summary)
    cmd_summary "$@"
    ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    echo "Run 'agent-cv.sh help' for usage" >&2
    exit 1
    ;;
esac
