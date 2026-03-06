#!/usr/bin/env bash
# codex-bridge-review.sh - Iterative Codex→Claude cross-provider review loop
#
# Runs Codex as primary agent, then sends changes to Claude for review.
# If Claude identifies issues, feeds feedback back to Codex for another pass.
# Mirrors the cross-provider bridge but with Codex as primary, Claude as reviewer.
#
# Usage: codex-bridge-review.sh [options] -- <codex-args...> <prompt>
#
# Options:
#   --max-iterations N    Max review cycles (default: 3)
#   --mode MODE           Review mode: review|redteam|steelman|assumptions
#   --claude-model MODEL  Claude model for review (default: claude-sonnet-4-6)
#   --claude-profile NAME Use specific Claude subscription profile
#   --timeout SECS        Claude review timeout (default: 120)
#   --verbose             Verbose logging
#   --dry-run             Show config without executing
#
# Environment:
#   CODEX_BRIDGE_MAX_ITERATIONS  Override --max-iterations
#   CODEX_BRIDGE_MODE            Override --mode
#   CODEX_BRIDGE_CLAUDE_MODEL    Override --claude-model
#   CODEX_BRIDGE_VERBOSE         Enable verbose (1 or 2)

set -euo pipefail

# --- Defaults ---
MAX_ITERATIONS="${CODEX_BRIDGE_MAX_ITERATIONS:-3}"
REVIEW_MODE="${CODEX_BRIDGE_MODE:-review}"
CLAUDE_MODEL="${CODEX_BRIDGE_CLAUDE_MODEL:-claude-sonnet-4-6}"
CLAUDE_PROFILE=""
REVIEW_TIMEOUT=120
VERBOSE="${CODEX_BRIDGE_VERBOSE:-0}"
DRY_RUN=false
PROMPT_FILE=""
MAX_DIFF_LINES=500
ITERATION_COOLDOWN=5
CODEX_ARGS=()

# --- Colors ---
if [ -t 2 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED=""
fi

log() { echo "${C_DIM}[codex-bridge]${C_RESET} $*" >&2; }
log_v() { [ "$VERBOSE" != "0" ] && log "$@" || true; }
log_banner() { echo "${C_CYAN}${C_BOLD}=== $1 ===${C_RESET}" >&2; }

# --- Parse options (everything before --) ---
while [ $# -gt 0 ]; do
    case "$1" in
    --max-iterations)
        MAX_ITERATIONS="$2"
        shift 2
        ;;
    --mode)
        REVIEW_MODE="$2"
        shift 2
        ;;
    --claude-model)
        CLAUDE_MODEL="$2"
        shift 2
        ;;
    --claude-profile)
        CLAUDE_PROFILE="$2"
        shift 2
        ;;
    --timeout)
        REVIEW_TIMEOUT="$2"
        shift 2
        ;;
    --verbose)
        VERBOSE=1
        shift
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --prompt-file)
        PROMPT_FILE="$2"
        shift 2
        ;;
    --max-diff-lines)
        MAX_DIFF_LINES="$2"
        shift 2
        ;;
    --cooldown)
        ITERATION_COOLDOWN="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *) break ;; # First non-option = start of codex args
    esac
done

# Everything remaining is passed to codex exec
CODEX_ARGS=("$@")

if [ ${#CODEX_ARGS[@]} -eq 0 ] && [ -z "$PROMPT_FILE" ]; then
    echo "Error: No codex arguments provided" >&2
    echo "Usage: codex-bridge-review.sh [options] -- <codex-exec-args...>" >&2
    exit 1
fi

# --- Review prompt templates ---
review_prompt() {
    local mode="$1" original_task="$2" diff="$3" iteration="$4"
    local base_context="Original task: $original_task

Changes made (git diff):
\`\`\`diff
$diff
\`\`\`"

    case "$mode" in
    review)
        echo "$base_context

Review these changes for:
- Correctness: Does the code do what was asked?
- Bugs: Any logic errors, edge cases, or potential crashes?
- Security: Any vulnerabilities introduced?
- Quality: Any obvious improvements?

If the changes look good, respond with exactly: LGTM
If there are issues, describe them concisely with specific fix suggestions."
        ;;
    redteam)
        echo "$base_context

You are a red team reviewer. Adversarially attack these changes:
- What could go wrong in production?
- What edge cases are missed?
- What assumptions might be wrong?
- What security issues exist?

If you cannot find significant issues, respond with exactly: LGTM
Otherwise, describe the most critical issues with specific concerns."
        ;;
    steelman)
        echo "$base_context

Steelman these changes - assume the author made reasonable choices, then verify:
- Are the design decisions justified given the task?
- Is there a simpler approach that achieves the same goal?
- Are there any correctness issues despite the reasonable approach?

If the approach is sound, respond with exactly: LGTM
If there are genuine issues beyond style preferences, describe them."
        ;;
    assumptions)
        echo "$base_context

Identify unstated assumptions in these changes:
- What does the code assume about its environment?
- What data format/range assumptions are made?
- What concurrency/ordering assumptions exist?
- Are any assumptions likely to break?

If assumptions are reasonable and well-handled, respond with exactly: LGTM
If dangerous assumptions exist, describe them with mitigation suggestions."
        ;;
    *)
        echo "$base_context

Review these changes. If they look correct, respond with: LGTM
Otherwise, describe issues with fix suggestions."
        ;;
    esac
}

followup_prompt() {
    local original_task="$1" review_feedback="$2" iteration="$3" max="$4"
    echo "A code reviewer (iteration $iteration/$max) identified these issues with your previous changes:

--- REVIEWER FEEDBACK ---
$review_feedback
--- END FEEDBACK ---

Original task: $original_task

Please address the reviewer's feedback. Fix the identified issues while keeping the original task goals intact."
}

# --- Dry run ---
if $DRY_RUN; then
    log_banner "Codex Bridge Review (DRY RUN)"
    log "Max iterations:  $MAX_ITERATIONS"
    log "Review mode:     $REVIEW_MODE"
    log "Claude model:    $CLAUDE_MODEL"
    log "Claude profile:  ${CLAUDE_PROFILE:-default}"
    log "Review timeout:  ${REVIEW_TIMEOUT}s"
    log "Max diff lines:  $MAX_DIFF_LINES"
    log "Cooldown:        ${ITERATION_COOLDOWN}s"
    log "Prompt file:     ${PROMPT_FILE:-<inline>}"
    log "Codex args:      ${CODEX_ARGS[*]}"
    exit 0
fi

# --- Validate tools ---
if ! command -v codex &>/dev/null; then
    echo "Error: codex CLI not found" >&2
    exit 1
fi
if ! command -v claude &>/dev/null; then
    echo "Error: claude CLI not found" >&2
    exit 1
fi

# --- Capture initial state ---
INITIAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")

# Extract the prompt: --prompt-file takes precedence, else last codex arg
if [ -n "$PROMPT_FILE" ]; then
    if [ ! -f "$PROMPT_FILE" ]; then
        echo "Error: Prompt file not found: $PROMPT_FILE" >&2
        exit 1
    fi
    ORIGINAL_PROMPT=$(cat "$PROMPT_FILE")
    # Append prompt to codex args (read safely from file, no shell expansion)
    CODEX_ARGS+=("$ORIGINAL_PROMPT")
else
    ORIGINAL_PROMPT="${CODEX_ARGS[${#CODEX_ARGS[@]} - 1]}"
fi

# --- Main loop ---
iteration=0
while [ $iteration -lt "$MAX_ITERATIONS" ]; do
    iteration=$((iteration + 1))

    if [ $iteration -eq 1 ]; then
        log_banner "Codex Execution (iteration $iteration/$MAX_ITERATIONS)"
        log_v "Running: codex ${CODEX_ARGS[*]}"

        # First run: use original codex args
        codex_exit=0
        codex "${CODEX_ARGS[@]}" || codex_exit=$?
        if [ "$codex_exit" -ne 0 ]; then
            log "${C_RED}Codex failed (exit $codex_exit)${C_RESET}"
            exit "$codex_exit"
        fi
    else
        log_banner "Codex Fix Pass (iteration $iteration/$MAX_ITERATIONS)"

        # Subsequent runs: use follow-up prompt with reviewer feedback
        local_prompt=$(followup_prompt "$ORIGINAL_PROMPT" "$review_output" "$((iteration - 1))" "$MAX_ITERATIONS")
        log_v "Follow-up prompt length: ${#local_prompt} chars"

        # Re-run codex with feedback prompt (keep same exec mode flags, replace prompt)
        # Extract flags (all but last arg which was the prompt)
        local_args=("${CODEX_ARGS[@]:0:${#CODEX_ARGS[@]}-1}")
        codex_exit=0
        codex "${local_args[@]}" "$local_prompt" || codex_exit=$?
        if [ "$codex_exit" -ne 0 ]; then
            log "${C_RED}Codex fix pass failed (exit $codex_exit)${C_RESET}"
            break
        fi
    fi

    # Check if anything changed
    current_diff=$(git diff "$INITIAL_HEAD" 2>/dev/null || echo "")
    if [ -z "$current_diff" ]; then
        log "No changes detected — skipping review"
        break
    fi

    # Skip review on last iteration (no more fix passes possible)
    if [ $iteration -eq "$MAX_ITERATIONS" ]; then
        log "Max iterations reached — accepting changes"
        break
    fi

    # Truncate large diffs to avoid exceeding Claude's context
    diff_line_count=$(echo "$current_diff" | wc -l | tr -d ' ')
    if [ "$diff_line_count" -gt "$MAX_DIFF_LINES" ]; then
        log "${C_YELLOW}Diff is $diff_line_count lines, truncating to $MAX_DIFF_LINES${C_RESET}"
        current_diff=$(echo "$current_diff" | head -n "$MAX_DIFF_LINES")
        current_diff="${current_diff}
... (truncated: $diff_line_count total lines, showing first $MAX_DIFF_LINES)"
    fi

    # --- Claude Review ---
    log_banner "Claude Review (iteration $iteration/$MAX_ITERATIONS, mode=$REVIEW_MODE)"

    review_prompt_text=$(review_prompt "$REVIEW_MODE" "$ORIGINAL_PROMPT" "$current_diff" "$iteration")
    log_v "Review prompt length: ${#review_prompt_text} chars"

    # Build claude command
    claude_cmd=(claude -p --model "$CLAUDE_MODEL")
    if [ -n "$CLAUDE_PROFILE" ]; then
        claude_cmd=(env "CLAUDE_CONFIG_DIR=$HOME/.claude-$CLAUDE_PROFILE" "${claude_cmd[@]}")
    fi

    review_output=$(echo "$review_prompt_text" | timeout "$REVIEW_TIMEOUT" "${claude_cmd[@]}" 2>/dev/null) || {
        log "${C_YELLOW}Claude review timed out or failed — accepting changes${C_RESET}"
        break
    }

    if [ -z "$review_output" ]; then
        log "Claude returned empty review — accepting changes"
        break
    fi

    # Check for LGTM consensus (strict: LGTM on a line by itself, no trailing caveats)
    if echo "$review_output" | grep -qE '^\s*LGTM\s*$'; then
        log "${C_GREEN}Claude approved changes (LGTM)${C_RESET}"
        if [ "$VERBOSE" != "0" ]; then
            echo "${C_DIM}Review: $(echo "$review_output" | head -3)${C_RESET}" >&2
        fi
        break
    fi

    # Not approved — show feedback
    log "${C_YELLOW}Claude requested changes:${C_RESET}"
    echo "$review_output" | head -20 >&2
    if [ "$(echo "$review_output" | wc -l)" -gt 20 ]; then
        echo "${C_DIM}  ... ($(echo "$review_output" | wc -l) lines total)${C_RESET}" >&2
    fi

    # Rate-limit between iterations to avoid API hammering
    if [ "$ITERATION_COOLDOWN" -gt 0 ]; then
        log_v "Cooldown: ${ITERATION_COOLDOWN}s before next iteration"
        sleep "$ITERATION_COOLDOWN"
    fi
done

log "Bridge review complete after $iteration iteration(s)"
