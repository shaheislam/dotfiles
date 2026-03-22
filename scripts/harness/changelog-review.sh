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
#   changelog-review.sh --flagged          # Show only tools with actionable flags (for dispatch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_FILE="$SCRIPT_DIR/changelog-tools.json"
BREWFILE="${DOTFILES_ROOT:-$HOME/dotfiles}/homebrew/Brewfile"
CACHE_DIR="$HOME/.cache/dotfiles-changelog"
REPORT_DIR="$HOME/.claude/harness/changelog-reports"

# Defaults
DAYS=30
JSON_OUTPUT=false
DRY_RUN=false
FLAGGED_ONLY=false
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
    echo "  --flagged         After fetch, print only flagged tools as JSON (for subagent dispatch)"
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
    --flagged)
        FLAGGED_ONLY=true
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

if [ ! -f "$BREWFILE" ]; then
    echo "Error: Brewfile not found: $BREWFILE" >&2
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
# Auto-discover tools from Brewfile + brew info
# ─────────────────────────────────────────────────────

# Load overlay file for config paths and metadata
OVERLAY="{}"
if [ -f "$OVERLAY_FILE" ]; then
    OVERLAY=$(jq -r '.overlays // {}' "$OVERLAY_FILE")
    SKIP_PATTERNS=$(jq -r '.skip_patterns // [] | .[]' "$OVERLAY_FILE")
fi

# Parse Brewfile for formula/cask names (skip comments, taps, empty lines)
BREW_NAMES=()
while IFS= read -r line; do
    # Extract name from: brew "name" or cask "name"
    if [[ "$line" =~ ^[[:space:]]*(brew|cask)[[:space:]]+\"([^\"]+)\" ]]; then
        raw_name="${BASH_REMATCH[2]}"
        # Strip tap prefix (e.g., "oven-sh/bun/bun" → "bun")
        name="${raw_name##*/}"
        BREW_NAMES+=("$name")
    fi
done <"$BREWFILE"

# Get GitHub repos for all installed formulae in one call (cached per day)
BREW_CACHE="$CACHE_DIR/brew-info-${TODAY}.json"
if [ ! -f "$BREW_CACHE" ]; then
    if ! $DRY_RUN; then
        printf "  Discovering tool repos via brew info..." >&2
    fi
    brew info --json=v2 --installed 2>/dev/null | jq '[
        .formulae[] | {
            name: .name,
            homepage: .homepage,
            head_url: (.urls.head.url // ""),
            stable_url: (.urls.stable.url // "")
        }
    ] + [
        .casks[] | {
            name: .token,
            homepage: .homepage,
            head_url: "",
            stable_url: (.url // "")
        }
    ]' >"$BREW_CACHE" 2>/dev/null || echo "[]" >"$BREW_CACHE"
    if ! $DRY_RUN; then
        echo -e " done" >&2
    fi
fi

# Extract GitHub owner/repo from URL
extract_github_repo() {
    local url="$1"
    # Match github.com/owner/repo from various URL formats
    if [[ "$url" =~ github\.com[/:]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

# Build tool list: merge Brewfile names + brew info repos + overlay metadata
TOOLS_TMPFILE=$(mktemp)
for name in "${BREW_NAMES[@]}"; do
    # Check skip patterns from overlay
    skip=false
    for pattern in $SKIP_PATTERNS; do
        # shellcheck disable=SC2053
        if [[ "$name" == $pattern ]]; then
            skip=true
            break
        fi
    done
    $skip && continue

    # Check if overlay says skip
    overlay_skip=$(echo "$OVERLAY" | jq -r --arg n "$name" '.[$n].skip // false')
    [ "$overlay_skip" = "true" ] && continue

    # Resolve GitHub repo from brew info cache
    repo=""
    brew_entry=$(jq -r --arg n "$name" '.[] | select(.name == $n)' "$BREW_CACHE" 2>/dev/null)
    if [ -n "$brew_entry" ]; then
        head_url=$(echo "$brew_entry" | jq -r '.head_url // ""')
        homepage=$(echo "$brew_entry" | jq -r '.homepage // ""')
        stable_url=$(echo "$brew_entry" | jq -r '.stable_url // ""')

        # Try head_url first (most reliable), then homepage, then stable_url
        repo=$(extract_github_repo "$head_url" 2>/dev/null) ||
            repo=$(extract_github_repo "$homepage" 2>/dev/null) ||
            repo=$(extract_github_repo "$stable_url" 2>/dev/null) ||
            repo=""
    fi

    # Skip tools without a GitHub repo
    [ -z "$repo" ] && continue

    # Merge overlay metadata
    config_paths=$(echo "$OVERLAY" | jq -r --arg n "$name" '.[$n].config_paths // [] | join(", ")')
    priority=$(echo "$OVERLAY" | jq -r --arg n "$name" '.[$n].priority // "medium"')
    category=$(echo "$OVERLAY" | jq -r --arg n "$name" '.[$n].category // "other"')

    # Apply category filter
    if [ -n "$CATEGORY_FILTER" ] && [ "$category" != "$CATEGORY_FILTER" ]; then
        continue
    fi

    jq -nc \
        --arg name "$name" \
        --arg repo "$repo" \
        --arg priority "$priority" \
        --arg category "$category" \
        --arg config_paths "$config_paths" \
        '{name: $name, repo: $repo, priority: $priority, category: $category, config_paths: $config_paths}'
done >"$TOOLS_TMPFILE"

TOOLS=$(cat "$TOOLS_TMPFILE")
rm -f "$TOOLS_TMPFILE"
TOOL_COUNT=$(echo "$TOOLS" | grep -c '^{' || echo 0)

if $DRY_RUN; then
    echo -e "${BLUE}=== Changelog Review (Dry Run) ===${NC}"
    echo "Discovered $TOOL_COUNT tools from Brewfile with GitHub repos"
    echo ""
    echo "$TOOLS" | while IFS= read -r tool; do
        [ -z "$tool" ] && continue
        name=$(echo "$tool" | jq -r '.name')
        repo=$(echo "$tool" | jq -r '.repo')
        priority=$(echo "$tool" | jq -r '.priority')
        category=$(echo "$tool" | jq -r '.category')
        config_paths=$(echo "$tool" | jq -r '.config_paths')
        marker=""
        [ -n "$config_paths" ] && marker=" *"
        echo "  [$priority] $name ($repo) — $category$marker"
    done
    echo ""
    echo "  * = has config path overlay"
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
    [ -z "$tool" ] && continue
    name=$(echo "$tool" | jq -r '.name')
    repo=$(echo "$tool" | jq -r '.repo')
    priority=$(echo "$tool" | jq -r '.priority')
    category=$(echo "$tool" | jq -r '.category')
    config_paths=$(echo "$tool" | jq -r '.config_paths')

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

# Flagged-only mode: output one JSON object per tool with actionable flags
# Each object contains: name, latest_tag, url, flags, config_paths, category
# Designed for subagent dispatch — parent reads this and spawns one agent per tool
if $FLAGGED_ONLY && [ -f "$REPORT_DIR/changelog-${TODAY}.jsonl" ]; then
    jq -s '
        [.[] | select(.flags != "" and .config_paths != "" and .prerelease == false)]
        | group_by(.name)
        | map({
            name: .[0].name,
            repo: .[0].repo,
            category: .[0].category,
            config_paths: .[0].config_paths,
            latest_tag: (map(.tag) | first),
            latest_url: (map(.url) | first),
            all_flags: (map(.flags) | join(",") | split(",") | unique | join(",")),
            release_count: length,
            releases: map({tag: .tag, url: .url, flags: .flags})
        })
    ' "$REPORT_DIR/changelog-${TODAY}.jsonl"
fi
