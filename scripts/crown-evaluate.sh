#!/usr/bin/env bash
#
# crown-evaluate.sh - Tournament judge for multi-agent crown evaluation
#
# Compares N branch implementations against a base branch, sends their diffs
# to an LLM judge, and returns a verdict JSON with the winning branch.
#
# Usage:
#   crown-evaluate.sh [options] <branch1> <branch2> [branch3...]
#
# Options:
#   --base BRANCH      Base branch for diffs (default: main)
#   --judge PRESET     Judge mode: council|review|redteam (default: council)
#   --output FILE      Write verdict JSON to file
#   --dry-run          Show prompt without running judge
#   --max-diff-lines N Max diff lines per contestant (default: 500)
#   --repo PATH        Repository path (default: current directory)
#
# Exit codes:
#   0 - Winner determined
#   1 - Error
#   2 - No valid contestants (all diffs empty)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
BASE_BRANCH="main"
JUDGE_PRESET="council"
OUTPUT_FILE=""
DRY_RUN=false
MAX_DIFF_LINES=500
REPO_PATH="."
BRANCHES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --base)
        BASE_BRANCH="$2"
        shift 2
        ;;
    --judge)
        JUDGE_PRESET="$2"
        shift 2
        ;;
    --output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --max-diff-lines)
        MAX_DIFF_LINES="$2"
        shift 2
        ;;
    --repo)
        REPO_PATH="$2"
        shift 2
        ;;
    --help | -h)
        echo "Usage: crown-evaluate.sh [options] <branch1> <branch2> [branch3...]"
        echo ""
        echo "Compare N branch implementations and pick the best one."
        echo ""
        echo "Options:"
        echo "  --base BRANCH      Base branch for diffs (default: main)"
        echo "  --judge PRESET     Judge mode: council|review|redteam (default: council)"
        echo "  --output FILE      Write verdict JSON to file"
        echo "  --dry-run          Show prompt without running judge"
        echo "  --max-diff-lines N Max diff lines per contestant (default: 500)"
        echo "  --repo PATH        Repository path (default: current directory)"
        exit 0
        ;;
    -*)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    *)
        BRANCHES+=("$1")
        shift
        ;;
    esac
done

if [[ ${#BRANCHES[@]} -lt 2 ]]; then
    echo -e "${RED}Error: At least 2 branches required for comparison${NC}" >&2
    exit 1
fi

# Validate branches exist
for branch in "${BRANCHES[@]}"; do
    if ! git -C "$REPO_PATH" rev-parse --verify "$branch" &>/dev/null; then
        echo -e "${RED}Error: Branch '$branch' not found${NC}" >&2
        exit 1
    fi
done

# Validate base branch
if ! git -C "$REPO_PATH" rev-parse --verify "$BASE_BRANCH" &>/dev/null; then
    echo -e "${RED}Error: Base branch '$BASE_BRANCH' not found${NC}" >&2
    exit 1
fi

# Collect diffs
declare -A DIFFS
LABELS=()
LABEL_MAP=() # index -> branch name
valid_count=0
label_idx=0

for branch in "${BRANCHES[@]}"; do
    # Generate label: A, B, C, ...
    label=$(printf "\\x$(printf '%02x' $((65 + label_idx)))")
    LABELS+=("$label")
    LABEL_MAP+=("$branch")

    diff_output=$(git -C "$REPO_PATH" diff "$BASE_BRANCH...$branch" 2>/dev/null | head -n "$MAX_DIFF_LINES")
    if [[ -n "$diff_output" ]]; then
        DIFFS["$label"]="$diff_output"
        valid_count=$((valid_count + 1))
    else
        DIFFS["$label"]="(no changes)"
    fi
    label_idx=$((label_idx + 1))
done

if [[ "$valid_count" -eq 0 ]]; then
    echo -e "${RED}Error: No branches have changes relative to $BASE_BRANCH${NC}" >&2
    exit 2
fi

# If only one valid contestant, they win by default
if [[ "$valid_count" -eq 1 ]]; then
    for i in "${!LABELS[@]}"; do
        label="${LABELS[$i]}"
        if [[ "${DIFFS[$label]}" != "(no changes)" ]]; then
            winner_branch="${LABEL_MAP[$i]}"
            verdict="{\"winner\": \"$winner_branch\", \"reasoning\": \"Only one contestant with changes\", \"scores\": {\"$winner_branch\": 10}}"
            echo "$verdict"
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo "$verdict" >"$OUTPUT_FILE"
            fi
            exit 0
        fi
    done
fi

# Build comparison prompt
build_judge_prompt() {
    local mode="$1"

    local system_prompt=""
    case "$mode" in
    council)
        system_prompt="You are a panel of expert code reviewers conducting a structured evaluation. Consider multiple perspectives: software architect (design quality, maintainability), security engineer (vulnerabilities, input validation), operations (reliability, observability), and user experience (API ergonomics, error messages). Be thorough but decisive."
        ;;
    review)
        system_prompt="You are a senior code reviewer evaluating implementations. Focus on correctness, code quality, test coverage, edge case handling, and adherence to best practices. Be concise and direct."
        ;;
    redteam)
        system_prompt="You are an adversarial code reviewer. For each implementation, find: 1) Bugs and logic errors 2) Security vulnerabilities 3) Missing edge cases 4) Performance problems 5) Maintainability concerns. The winner is the implementation with the fewest critical issues."
        ;;
    *)
        system_prompt="You are an expert code reviewer comparing implementations. Pick the best one."
        ;;
    esac

    # Build the user prompt with all diffs
    local user_prompt="Compare the following ${#BRANCHES[@]} implementations of the same task. Each contestant independently implemented a solution branching from '$BASE_BRANCH'.

"
    for i in "${!LABELS[@]}"; do
        label="${LABELS[$i]}"
        user_prompt+="=== Contestant ${label} ===
\`\`\`diff
${DIFFS[$label]}
\`\`\`

"
    done

    user_prompt+="Evaluate each implementation on:
1. **Correctness** — Does it solve the problem completely?
2. **Code Quality** — Clean, readable, well-structured?
3. **Edge Cases** — Handles failures, boundary conditions?
4. **Security** — No vulnerabilities introduced?
5. **Maintainability** — Easy to understand and modify?

Score each contestant 1-10 on each criterion. Then declare the winner.

IMPORTANT: Your response MUST include a line in exactly this format:
WINNER: <contestant-letter>

For example: WINNER: A

Also include scores in this format (one per contestant):
SCORE <letter>: <total-score>

End with a brief explanation of why the winner was chosen."

    printf '%s\n' "$system_prompt"
    printf '%s\n' "---SEPARATOR---"
    printf '%s\n' "$user_prompt"
}

# Generate the prompt
prompt_output=$(build_judge_prompt "$JUDGE_PRESET")
system_prompt=$(echo "$prompt_output" | sed -n '1,/^---SEPARATOR---$/p' | head -n -1)
user_prompt=$(echo "$prompt_output" | sed -n '/^---SEPARATOR---$/,$ p' | tail -n +2)

# Dry run: show prompt and exit
if $DRY_RUN; then
    echo -e "${BLUE}=== Crown Evaluation (dry-run) ===${NC}"
    echo ""
    echo -e "${YELLOW}Judge preset: $JUDGE_PRESET${NC}"
    echo -e "${YELLOW}Base branch: $BASE_BRANCH${NC}"
    echo -e "${YELLOW}Contestants: ${#BRANCHES[@]}${NC}"
    for i in "${!LABELS[@]}"; do
        echo -e "  ${LABELS[$i]}: ${LABEL_MAP[$i]}"
    done
    echo ""
    echo -e "${BLUE}--- System Prompt ---${NC}"
    echo "$system_prompt"
    echo ""
    echo -e "${BLUE}--- User Prompt ---${NC}"
    echo "$user_prompt"
    exit 0
fi

# Run the judge
echo -e "${BLUE}Crown evaluation: ${#BRANCHES[@]} contestants, judge=$JUDGE_PRESET${NC}" >&2

# Select model based on judge preset
judge_model="opus"
case "$JUDGE_PRESET" in
review) judge_model="sonnet" ;;
redteam) judge_model="opus" ;;
council) judge_model="opus" ;;
esac

# Run claude -p with system prompt and user prompt
judge_output=$(claude -p --model "$judge_model" --system-prompt "$system_prompt" "$user_prompt" 2>/dev/null)

if [[ -z "$judge_output" ]]; then
    echo -e "${RED}Error: Judge returned empty output${NC}" >&2
    exit 1
fi

# Parse winner from output
winner_letter=$(echo "$judge_output" | grep -oP 'WINNER:\s*\K[A-Z]' | head -1)

if [[ -z "$winner_letter" ]]; then
    echo -e "${YELLOW}Warning: Could not parse WINNER line from judge output${NC}" >&2
    echo -e "${YELLOW}Judge output:${NC}" >&2
    echo "$judge_output" >&2
    # Fallback: try to find any single letter after "winner" (case-insensitive)
    winner_letter=$(echo "$judge_output" | grep -ioP 'winner[^a-z]*\K[A-Z]' | head -1)
fi

if [[ -z "$winner_letter" ]]; then
    echo -e "${RED}Error: Could not determine winner from judge output${NC}" >&2
    exit 1
fi

# Map letter back to branch
winner_idx=$(($(printf '%d' "'$winner_letter") - 65))
if [[ "$winner_idx" -lt 0 || "$winner_idx" -ge "${#LABEL_MAP[@]}" ]]; then
    echo -e "${RED}Error: Winner letter '$winner_letter' out of range${NC}" >&2
    exit 1
fi
winner_branch="${LABEL_MAP[$winner_idx]}"

# Parse scores
declare -A SCORES
for i in "${!LABELS[@]}"; do
    label="${LABELS[$i]}"
    score=$(echo "$judge_output" | grep -oP "SCORE\s+${label}:\s*\K[0-9]+" | head -1)
    SCORES["${LABEL_MAP[$i]}"]="${score:-0}"
done

# Build scores JSON
scores_json="{"
first=true
for i in "${!LABEL_MAP[@]}"; do
    branch="${LABEL_MAP[$i]}"
    if ! $first; then scores_json+=","; fi
    scores_json+="\"$branch\":${SCORES[$branch]:-0}"
    first=false
done
scores_json+="}"

# Escape reasoning for JSON (replace newlines, quotes)
reasoning=$(echo "$judge_output" | tail -20 | tr '\n' ' ' | sed 's/"/\\"/g' | head -c 500)

# Build verdict JSON
verdict="{\"winner\":\"$winner_branch\",\"winner_letter\":\"$winner_letter\",\"reasoning\":\"$reasoning\",\"scores\":$scores_json,\"judge\":\"$JUDGE_PRESET\",\"base\":\"$BASE_BRANCH\",\"contestants\":[$(printf '"%s",' "${BRANCHES[@]}" | sed 's/,$//')],\"evaluated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

# Output verdict
echo "$verdict"

# Write to file if requested
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$verdict" >"$OUTPUT_FILE"
    echo -e "${GREEN}Verdict written to $OUTPUT_FILE${NC}" >&2
fi

echo -e "${GREEN}Winner: $winner_branch (Contestant $winner_letter)${NC}" >&2
