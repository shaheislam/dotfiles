#!/usr/bin/env bash
#
# town-beads.sh - Cross-project memory (Town-level Beads)
#
# Syncs bead summaries from individual project worktrees into a global
# git-backed repository at ~/.claude/town-beads/. Provides cross-project
# search and context priming.
#
# Usage:
#   town-beads.sh init
#   town-beads.sh sync <issue-key> [--from <worktree-path>]
#   town-beads.sh search <query>
#   town-beads.sh context [--recent N]
#   town-beads.sh list
#
# Exit codes:
#   0 - Success
#   1 - Error

set -euo pipefail

TOWN_DIR="${HOME}/.claude/town-beads"
INDEX_FILE="${TOWN_DIR}/index.jsonl"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# --- Commands ---

cmd_init() {
    if [[ -d "$TOWN_DIR/.git" ]]; then
        echo -e "${GREEN}Town beads already initialized${NC} at $TOWN_DIR"
        return 0
    fi

    mkdir -p "$TOWN_DIR/projects"
    cd "$TOWN_DIR"
    git init --quiet
    touch "$INDEX_FILE"
    git add .
    git commit --quiet -m "init: town beads repository"

    echo -e "${GREEN}Initialized town beads${NC} at $TOWN_DIR"
}

cmd_sync() {
    local issue_key="" from_path=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --from)
            from_path="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            if [[ -z "$issue_key" ]]; then
                issue_key="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$issue_key" ]]; then
        echo -e "${RED}Error: issue-key required${NC}" >&2
        exit 1
    fi

    # Auto-detect worktree path if not specified
    if [[ -z "$from_path" ]]; then
        from_path="$(pwd)"
    fi

    # Ensure town beads is initialized
    if [[ ! -d "$TOWN_DIR/.git" ]]; then
        cmd_init
    fi

    # Determine repo name from worktree
    local repo_name
    repo_name=$(basename "$(git -C "$from_path" rev-parse --git-common-dir 2>/dev/null | xargs dirname)" 2>/dev/null) || repo_name="unknown"

    # Create project directory
    local project_dir="${TOWN_DIR}/projects/${repo_name}"
    mkdir -p "$project_dir"

    # Build bead summary
    local bead_file="${project_dir}/${issue_key}.md"
    local ts
    ts="$(timestamp_now)"

    {
        echo "# ${issue_key}"
        echo ""
        echo "- **Project**: ${repo_name}"
        echo "- **Synced**: ${ts}"
        echo ""

        # Try to get bead content from project
        if command -v bd &>/dev/null && [[ -d "$from_path/.beads" ]]; then
            local bead_content
            bead_content=$(cd "$from_path" && bd show "$issue_key" 2>/dev/null) || true
            if [[ -n "$bead_content" ]]; then
                echo "## Bead Content"
                echo ""
                echo "$bead_content"
            fi
        fi

        # Get recent git log for this worktree
        local branch
        branch=$(git -C "$from_path" branch --show-current 2>/dev/null) || true
        if [[ -n "$branch" ]]; then
            echo ""
            echo "## Recent Commits"
            echo ""
            git -C "$from_path" log --oneline -5 2>/dev/null | while read -r line; do
                echo "- $line"
            done
        fi
    } >"$bead_file"

    # Update index
    local index_entry
    index_entry=$(printf '{"issue_key":"%s","project":"%s","synced":"%s","file":"%s"}' \
        "$issue_key" "$repo_name" "$ts" "projects/${repo_name}/${issue_key}.md")

    # Remove old entry for this key+project, add new
    local tmp="${INDEX_FILE}.tmp.$$"
    grep -v "\"issue_key\":\"${issue_key}\",\"project\":\"${repo_name}\"" "$INDEX_FILE" >"$tmp" 2>/dev/null || true
    echo "$index_entry" >>"$tmp"
    mv "$tmp" "$INDEX_FILE"

    # Commit to town beads repo
    cd "$TOWN_DIR"
    git add -A
    git commit --quiet -m "sync: ${issue_key} from ${repo_name}" 2>/dev/null || true

    echo -e "${GREEN}Synced${NC} ${issue_key} from ${repo_name} to town beads"
}

cmd_search() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo -e "${RED}Error: search query required${NC}" >&2
        exit 1
    fi

    if [[ ! -d "$TOWN_DIR" ]]; then
        echo "Town beads not initialized. Run: town-beads.sh init"
        exit 1
    fi

    echo -e "${BLUE}=== Town Beads Search: ${query} ===${NC}"

    # Search across all bead files
    local found=false
    while IFS= read -r match; do
        found=true
        local file="${match%%:*}"
        local content="${match#*:}"
        local relative="${file#$TOWN_DIR/}"
        echo -e "  ${DIM}${relative}${NC}: ${content}"
    done < <(grep -ri "$query" "$TOWN_DIR/projects/" 2>/dev/null || true)

    if ! $found; then
        echo "  No matches found."
    fi
}

cmd_context() {
    local recent=5

    while [[ $# -gt 0 ]]; do
        case $1 in
        --recent)
            recent="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
        echo "No town beads synced yet."
        return 0
    fi

    echo "TOWN BEADS CONTEXT (recent ${recent}):"
    echo ""

    # Get last N entries from index
    tail -n "$recent" "$INDEX_FILE" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local issue project synced file_path
        issue=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['issue_key'])" 2>/dev/null) || continue
        project=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['project'])" 2>/dev/null) || continue
        synced=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['synced'])" 2>/dev/null) || continue
        file_path=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['file'])" 2>/dev/null) || continue

        echo "- ${issue} (${project}, ${synced})"

        # Include first few lines of summary
        local full_path="${TOWN_DIR}/${file_path}"
        if [[ -f "$full_path" ]]; then
            head -10 "$full_path" | grep -v '^#' | grep -v '^$' | head -3 | while read -r summary_line; do
                echo "  $summary_line"
            done
        fi
    done
}

cmd_list() {
    if [[ ! -d "$TOWN_DIR/projects" ]]; then
        echo "No town beads synced yet."
        return 0
    fi

    echo -e "${BLUE}=== Town Beads ===${NC}"

    for project_dir in "$TOWN_DIR"/projects/*/; do
        [[ -d "$project_dir" ]] || continue
        local project
        project=$(basename "$project_dir")
        echo -e "  ${BOLD}${project}${NC}"

        for bead_file in "$project_dir"*.md; do
            [[ -f "$bead_file" ]] || continue
            local key
            key=$(basename "$bead_file" .md)
            local synced
            synced=$(grep "^- \*\*Synced\*\*:" "$bead_file" 2>/dev/null | head -1 | sed 's/.*: //' || echo "?")
            echo -e "    ${DIM}${key}${NC} (${synced})"
        done
    done
}

# --- Main ---

show_help() {
    echo "town-beads.sh - Cross-project memory (Town-level Beads)"
    echo ""
    echo "USAGE:"
    echo "  town-beads.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  init                              Initialize town beads repo"
    echo "  sync <issue-key> [--from <path>]  Sync project bead to town"
    echo "  search <query>                    Search across all town beads"
    echo "  context [--recent N]              Output recent bead summaries"
    echo "  list                              List all synced beads by project"
    echo ""
    echo "STORAGE:"
    echo "  ${TOWN_DIR}/"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
init) cmd_init ;;
sync) cmd_sync "$@" ;;
search) cmd_search "${1:-}" ;;
context) cmd_context "$@" ;;
list) cmd_list ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    exit 1
    ;;
esac
