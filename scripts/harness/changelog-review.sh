#!/usr/bin/env bash
# Harness Engineering: Monthly Changelog Review
# Fetches recent releases for tracked tools, identifies breaking changes and
# new features, and generates a report with config review suggestions.
#
# Usage:
#   changelog-review.sh                    # Full review (last 30 days)
#   changelog-review.sh --days 60          # Custom date range
#   changelog-review.sh --json             # JSON output
#   changelog-review.sh --category shell   # Filter by category
#   changelog-review.sh --dry-run          # Show what would be checked

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_FILE="$SCRIPT_DIR/changelog-tools.json"
CACHE_DIR="$HOME/.cache/dotfiles-changelog"
REPORT_DIR="$HOME/.claude/harness/changelog-reports"

# Defaults
DAYS=30
JSON_OUTPUT=false
DRY_RUN=false
CATEGORY_FILTER=""

# Colors
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: changelog-review.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --days N          Look back N days (default: 30)"
    echo "  --json            Output as JSON"
    echo "  --category CAT    Filter by category (shell, devops, security, etc.)"
    echo "  --dry-run         Show tools that would be checked"
    echo "  -h, --help        Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --days)
        DAYS="$2"
        shift 2
        ;;
    --json)
        JSON_OUTPUT=true
        shift
        ;;
    --category)
        CATEGORY_FILTER="$2"
        shift 2
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    -h | --help) usage ;;
    *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Validate prerequisites
if ! command -v gh &>/dev/null; then
    echo "Error: gh (GitHub CLI) required. Install via: brew install gh" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq required. Install via: brew install jq" >&2
    exit 1
fi

if [ ! -f "$TOOLS_FILE" ]; then
    echo "Error: Tool registry not found: $TOOLS_FILE" >&2
    exit 1
fi

# Ensure directories exist
mkdir -p "$CACHE_DIR" "$REPORT_DIR"

# Calculate date threshold
if date -v-1d &>/dev/null 2>&1; then
    # macOS date
    SINCE_DATE=$(date -v-"${DAYS}d" "+%Y-%m-%dT00:00:00Z")
else
    # GNU date
    SINCE_DATE=$(date -d "$DAYS days ago" "+%Y-%m-%dT00:00:00Z")
fi

TODAY=$(date "+%Y-%m-%d")

# ─────────────────────────────────────────────────────
# Load tool registry
# ─────────────────────────────────────────────────────

if [ -n "$CATEGORY_FILTER" ]; then
    TOOLS=$(jq -c --arg cat "$CATEGORY_FILTER" '.tools[] | select(.category == $cat)' "$TOOLS_FILE")
else
    TOOLS=$(jq -c '.tools[]' "$TOOLS_FILE")
fi

TOOL_COUNT=$(echo "$TOOLS" | wc -l | tr -d ' ')

if $DRY_RUN; then
    echo -e "${BLUE}=== Changelog Review (Dry Run) ===${NC}"
    echo "Would check $TOOL_COUNT tools for releases in last $DAYS days"
    echo ""
    echo "$TOOLS" | while IFS= read -r tool; do
        name=$(echo "$tool" | jq -r '.name')
        repo=$(echo "$tool" | jq -r '.repo')
        priority=$(echo "$tool" | jq -r '.priority')
        category=$(echo "$tool" | jq -r '.category')
        echo "  [$priority] $name ($repo) — $category"
    done
    exit 0
fi

# ─────────────────────────────────────────────────────
# Fetch releases for each tool
# ─────────────────────────────────────────────────────

BREAKING_COUNT=0
NEW_FEATURE_COUNT=0
TOTAL_RELEASES=0

if ! $JSON_OUTPUT; then
    echo -e "${BLUE}=== Monthly Changelog Review ===${NC}"
    echo "Checking $TOOL_COUNT tools for releases since $SINCE_DATE"
    echo ""
fi

fetch_releases() {
    local name="$1" repo="$2" priority="$3" category="$4" config_paths="$5"
    local cache_file="$CACHE_DIR/${name}-${TODAY}.json"

    # Use cached data if available (same day)
    if [ -f "$cache_file" ]; then
        cat "$cache_file"
        return 0
    fi

    # Fetch releases from GitHub API
    local releases
    releases=$(gh api "repos/$repo/releases" \
        --jq "[.[] | select(.published_at >= \"$SINCE_DATE\") | {tag: .tag_name, date: .published_at, url: .html_url, body: .body, prerelease: .prerelease}]" \
        2>/dev/null) || {
        echo "[]"
        return 1
    }

    # Cache the result
    echo "$releases" >"$cache_file"
    echo "$releases"
}

analyze_release() {
    local body="$1"
    local flags=""

    # Check for breaking changes
    if echo "$body" | grep -qiE '(breaking|BREAKING|backward.?incompatible|migration.?required|removed|deprecated)'; then
        flags="${flags}breaking,"
    fi

    # Check for new features worth enabling
    if echo "$body" | grep -qiE '(new.?feature|new.?option|new.?config|added.?support|introducing)'; then
        flags="${flags}new-feature,"
    fi

    # Check for security fixes
    if echo "$body" | grep -qiE '(security|CVE-|vulnerability|fix.*vuln)'; then
        flags="${flags}security,"
    fi

    # Check for config changes
    if echo "$body" | grep -qiE '(config|configuration|setting|option|flag).*(change|new|add|deprecat|remov)'; then
        flags="${flags}config-change,"
    fi

    # Remove trailing comma
    echo "${flags%,}"
}

# Process each tool
echo "$TOOLS" | while IFS= read -r tool; do
    name=$(echo "$tool" | jq -r '.name')
    repo=$(echo "$tool" | jq -r '.repo')
    priority=$(echo "$tool" | jq -r '.priority')
    category=$(echo "$tool" | jq -r '.category')
    config_paths=$(echo "$tool" | jq -r '.config_paths | join(", ")')

    if ! $JSON_OUTPUT; then
        printf "  Checking %-20s " "$name..."
    fi

    releases=$(fetch_releases "$name" "$repo" "$priority" "$category" "$config_paths")

    if [ "$releases" = "[]" ] || [ -z "$releases" ]; then
        if ! $JSON_OUTPUT; then
            echo -e "${GREEN}no new releases${NC}"
        fi
        continue
    fi

    release_count=$(echo "$releases" | jq 'length')
    TOTAL_RELEASES=$((TOTAL_RELEASES + release_count))

    if ! $JSON_OUTPUT; then
        echo -e "${YELLOW}$release_count release(s)${NC}"
    fi

    # Analyze each release
    echo "$releases" | jq -c '.[]' | while IFS= read -r release; do
        tag=$(echo "$release" | jq -r '.tag')
        date=$(echo "$release" | jq -r '.date')
        url=$(echo "$release" | jq -r '.url')
        body=$(echo "$release" | jq -r '.body // ""')
        prerelease=$(echo "$release" | jq -r '.prerelease')

        flags=$(analyze_release "$body")

        if [ -n "$flags" ] && ! $JSON_OUTPUT; then
            echo -e "    ${CYAN}$tag${NC} ($date)"

            if echo "$flags" | grep -q "breaking"; then
                echo -e "      ${RED}BREAKING CHANGE${NC}"
                BREAKING_COUNT=$((BREAKING_COUNT + 1))
            fi
            if echo "$flags" | grep -q "new-feature"; then
                echo -e "      ${GREEN}New feature available${NC}"
                NEW_FEATURE_COUNT=$((NEW_FEATURE_COUNT + 1))
            fi
            if echo "$flags" | grep -q "security"; then
                echo -e "      ${RED}Security fix${NC}"
            fi
            if echo "$flags" | grep -q "config-change"; then
                echo -e "      ${YELLOW}Config change${NC}"
            fi

            if [ -n "$config_paths" ] && [ "$config_paths" != "" ]; then
                echo -e "      Config: $config_paths"
            fi
            echo "      $url"
        fi

        # Output JSON line for report generation
        jq -nc \
            --arg name "$name" \
            --arg repo "$repo" \
            --arg tag "$tag" \
            --arg date "$date" \
            --arg url "$url" \
            --arg flags "$flags" \
            --arg priority "$priority" \
            --arg category "$category" \
            --arg config_paths "$config_paths" \
            --argjson prerelease "$prerelease" \
            '{name: $name, repo: $repo, tag: $tag, date: $date, url: $url, flags: $flags, priority: $priority, category: $category, config_paths: $config_paths, prerelease: $prerelease}' \
            >>"$REPORT_DIR/changelog-${TODAY}.jsonl"
    done
done

# ─────────────────────────────────────────────────────
# Generate summary report
# ─────────────────────────────────────────────────────

REPORT_FILE="$REPORT_DIR/changelog-${TODAY}.md"

if ! $JSON_OUTPUT; then
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"

    # Count from the JSONL file
    if [ -f "$REPORT_DIR/changelog-${TODAY}.jsonl" ]; then
        total=$(wc -l <"$REPORT_DIR/changelog-${TODAY}.jsonl" | tr -d ' ')
        breaking=$(grep -c '"breaking"' "$REPORT_DIR/changelog-${TODAY}.jsonl" 2>/dev/null || echo 0)
        features=$(grep -c '"new-feature"' "$REPORT_DIR/changelog-${TODAY}.jsonl" 2>/dev/null || echo 0)
        security=$(grep -c '"security"' "$REPORT_DIR/changelog-${TODAY}.jsonl" 2>/dev/null || echo 0)
        config=$(grep -c '"config-change"' "$REPORT_DIR/changelog-${TODAY}.jsonl" 2>/dev/null || echo 0)

        echo "  Total releases:    $total"
        echo -e "  Breaking changes:  ${RED}$breaking${NC}"
        echo -e "  New features:      ${GREEN}$features${NC}"
        echo -e "  Security fixes:    ${RED}$security${NC}"
        echo -e "  Config changes:    ${YELLOW}$config${NC}"

        # Generate markdown report
        {
            echo "# Monthly Changelog Review — $TODAY"
            echo ""
            echo "**Period**: Last $DAYS days (since $SINCE_DATE)"
            echo "**Tools checked**: $TOOL_COUNT"
            echo "**Releases found**: $total"
            echo ""
            echo "## Action Items"
            echo ""

            if [ "$breaking" -gt 0 ]; then
                echo "### Breaking Changes"
                echo ""
                grep '"breaking"' "$REPORT_DIR/changelog-${TODAY}.jsonl" | while IFS= read -r line; do
                    n=$(echo "$line" | jq -r '.name')
                    t=$(echo "$line" | jq -r '.tag')
                    u=$(echo "$line" | jq -r '.url')
                    c=$(echo "$line" | jq -r '.config_paths')
                    echo "- **$n** $t — [Release notes]($u)"
                    [ -n "$c" ] && [ "$c" != "" ] && echo "  - Config: \`$c\`"
                done
                echo ""
            fi

            if [ "$security" -gt 0 ]; then
                echo "### Security Updates"
                echo ""
                grep '"security"' "$REPORT_DIR/changelog-${TODAY}.jsonl" | while IFS= read -r line; do
                    n=$(echo "$line" | jq -r '.name')
                    t=$(echo "$line" | jq -r '.tag')
                    u=$(echo "$line" | jq -r '.url')
                    echo "- **$n** $t — [Release notes]($u)"
                done
                echo ""
            fi

            if [ "$features" -gt 0 ]; then
                echo "### New Features Worth Reviewing"
                echo ""
                grep '"new-feature"' "$REPORT_DIR/changelog-${TODAY}.jsonl" | while IFS= read -r line; do
                    n=$(echo "$line" | jq -r '.name')
                    t=$(echo "$line" | jq -r '.tag')
                    u=$(echo "$line" | jq -r '.url')
                    c=$(echo "$line" | jq -r '.config_paths')
                    echo "- **$n** $t — [Release notes]($u)"
                    [ -n "$c" ] && [ "$c" != "" ] && echo "  - Config: \`$c\`"
                done
                echo ""
            fi

            if [ "$config" -gt 0 ]; then
                echo "### Config Changes"
                echo ""
                grep '"config-change"' "$REPORT_DIR/changelog-${TODAY}.jsonl" | while IFS= read -r line; do
                    n=$(echo "$line" | jq -r '.name')
                    t=$(echo "$line" | jq -r '.tag')
                    u=$(echo "$line" | jq -r '.url')
                    c=$(echo "$line" | jq -r '.config_paths')
                    echo "- **$n** $t — [Release notes]($u)"
                    [ -n "$c" ] && [ "$c" != "" ] && echo "  - Config: \`$c\`"
                done
                echo ""
            fi

            echo "## All Releases"
            echo ""
            echo "| Tool | Version | Date | Flags |"
            echo "|------|---------|------|-------|"
            while IFS= read -r line; do
                n=$(echo "$line" | jq -r '.name')
                t=$(echo "$line" | jq -r '.tag')
                d=$(echo "$line" | jq -r '.date' | cut -dT -f1)
                f=$(echo "$line" | jq -r '.flags')
                u=$(echo "$line" | jq -r '.url')
                echo "| [$n]($u) | $t | $d | $f |"
            done <"$REPORT_DIR/changelog-${TODAY}.jsonl"
        } >"$REPORT_FILE"

        echo ""
        echo -e "  Report: ${CYAN}$REPORT_FILE${NC}"
        echo -e "  Data:   ${CYAN}$REPORT_DIR/changelog-${TODAY}.jsonl${NC}"
    else
        echo "  No releases found in the last $DAYS days."
    fi
fi

# JSON output mode
if $JSON_OUTPUT && [ -f "$REPORT_DIR/changelog-${TODAY}.jsonl" ]; then
    jq -s '.' "$REPORT_DIR/changelog-${TODAY}.jsonl"
fi
