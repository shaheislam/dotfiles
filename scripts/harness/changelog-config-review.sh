#!/usr/bin/env bash
# Harness Engineering: Config Review from Changelog Data
# Takes changelog JSONL data and reviews current dotfiles config for each tool
# that had notable releases. Generates a PR-ready markdown report with suggestions.
#
# Usage:
#   changelog-config-review.sh                          # Review today's changelog data
#   changelog-config-review.sh --date 2026-03-01        # Review specific date's data
#   changelog-config-review.sh --input /path/to.jsonl   # Review specific JSONL file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$HOME/.claude/harness/changelog-reports"

# Defaults
TODAY=$(date "+%Y-%m-%d")
INPUT_FILE=""

# Colors
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
    --date)
        TODAY="$2"
        shift 2
        ;;
    --input)
        INPUT_FILE="$2"
        shift 2
        ;;
    *)
        echo "Unknown: $1"
        exit 1
        ;;
    esac
done

# Resolve input file
if [ -z "$INPUT_FILE" ]; then
    INPUT_FILE="$REPORT_DIR/changelog-${TODAY}.jsonl"
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "No changelog data found: $INPUT_FILE" >&2
    echo "Run changelog-review.sh first to fetch release data." >&2
    exit 1
fi

REVIEW_FILE="$REPORT_DIR/config-review-${TODAY}.md"

echo -e "${BLUE}=== Config Review ===${NC}"
echo "Reviewing config for tools with notable releases..."
echo ""

# ─────────────────────────────────────────────────────
# Collect tools that need review (have flags)
# ─────────────────────────────────────────────────────

flagged_tools=$(jq -r 'select(.flags != "") | .name' "$INPUT_FILE" | sort -u)

if [ -z "$flagged_tools" ]; then
    echo -e "${GREEN}No tools require config review.${NC}"
    exit 0
fi

# ─────────────────────────────────────────────────────
# Config review functions per tool
# ─────────────────────────────────────────────────────

review_tool_config() {
    local name="$1"
    local config_paths="$2"
    local flags="$3"
    local latest_tag="$4"
    local url="$5"
    local suggestions=""

    # Skip tools with no config paths
    if [ -z "$config_paths" ] || [ "$config_paths" = "" ]; then
        return
    fi

    echo -e "  ${CYAN}$name${NC} ($latest_tag)"

    # Check each config path
    IFS=', ' read -ra paths <<<"$config_paths"
    for path in "${paths[@]}"; do
        full_path="$ROOT/$path"

        if [ ! -e "$full_path" ]; then
            echo -e "    ${YELLOW}Config not found: $path${NC}"
            suggestions="${suggestions}\n- [ ] Create config file: \`$path\` (new features available in $latest_tag)"
            continue
        fi

        # Tool-specific config checks
        case "$name" in
        fish)
            # Check fish version features
            if [ -f "$full_path" ]; then
                if ! grep -q "status is-interactive" "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Consider guarding interactive config with \`status is-interactive\`"
                fi
            fi
            ;;
        tmux)
            if [ -f "$full_path" ]; then
                # Check for deprecated options
                if grep -qE 'set -g utf8|set-window-option -g utf8' "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Remove deprecated \`utf8\` option (automatic in modern tmux)"
                fi
                if grep -q 'mouse-select-pane' "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Replace deprecated \`mouse-select-pane\` with \`set -g mouse on\`"
                fi
            fi
            ;;
        starship)
            if [ -f "$full_path" ]; then
                # Check for deprecated module names
                if grep -q '\[battery\]' "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Review battery module — may have new config options"
                fi
            fi
            ;;
        fzf)
            if [ -f "$full_path" ]; then
                # Check for old FZF_DEFAULT_OPTS format
                if grep -q 'FZF_DEFAULT_OPTS' "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Review FZF_DEFAULT_OPTS for new options in $latest_tag"
                fi
            fi
            ;;
        git-delta)
            if [ -f "$full_path" ]; then
                if grep -q '\[delta\]' "$full_path" 2>/dev/null; then
                    suggestions="${suggestions}\n- [ ] Review delta config in .gitconfig — $latest_tag may have new features"
                fi
            fi
            ;;
        atuin)
            if [ -d "$full_path" ]; then
                local atuin_config="$full_path/config.toml"
                if [ -f "$atuin_config" ]; then
                    suggestions="${suggestions}\n- [ ] Review atuin config.toml for new sync/search options in $latest_tag"
                fi
            fi
            ;;
        yazi)
            if [ -d "$full_path" ]; then
                for f in "$full_path"/*.toml; do
                    [ -f "$f" ] || continue
                    suggestions="${suggestions}\n- [ ] Review $(basename "$f") for new options in $latest_tag"
                done
            fi
            ;;
        ghostty)
            if [ -d "$full_path" ]; then
                local ghostty_config="$full_path/config"
                if [ -f "$ghostty_config" ]; then
                    # Check for Tokyo Night theme
                    if ! grep -qi 'tokyo' "$ghostty_config" 2>/dev/null; then
                        suggestions="${suggestions}\n- [ ] Verify Tokyo Night theme is applied in Ghostty config"
                    fi
                    suggestions="${suggestions}\n- [ ] Review Ghostty config for new options in $latest_tag"
                fi
            fi
            ;;
        wezterm)
            if [ -d "$full_path" ]; then
                suggestions="${suggestions}\n- [ ] Review WezTerm config for new features in $latest_tag"
            fi
            ;;
        mise)
            if [ -d "$full_path" ]; then
                suggestions="${suggestions}\n- [ ] Review mise config for breaking changes in $latest_tag"
            fi
            ;;
        karabiner-elements)
            suggestions="${suggestions}\n- [ ] Check Karabiner release notes (config edited via GUI): $url"
            ;;
        *)
            if [ -n "$config_paths" ]; then
                suggestions="${suggestions}\n- [ ] Review $name config ($config_paths) for changes in $latest_tag"
            fi
            ;;
        esac
    done

    if [ -n "$suggestions" ]; then
        echo -e "$suggestions" | while IFS= read -r line; do
            [ -n "$line" ] && echo "    $line"
        done
    else
        echo -e "    ${GREEN}No config concerns identified${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────
# Generate config review report
# ─────────────────────────────────────────────────────

{
    echo "# Config Review — $TODAY"
    echo ""
    echo "Tools with notable releases that have local configuration:"
    echo ""

    # Breaking changes first
    breaking_tools=$(jq -r 'select(.flags | test("breaking")) | .name' "$INPUT_FILE" 2>/dev/null | sort -u)
    if [ -n "$breaking_tools" ]; then
        echo "## Breaking Changes (Action Required)"
        echo ""
        for tool in $breaking_tools; do
            latest=$(jq -r "select(.name == \"$tool\") | .tag" "$INPUT_FILE" | head -1)
            url=$(jq -r "select(.name == \"$tool\") | .url" "$INPUT_FILE" | head -1)
            config_paths=$(jq -r "select(.name == \"$tool\") | .config_paths" "$INPUT_FILE" | head -1)
            echo "### $tool ($latest)"
            echo ""
            echo "- Release: [$latest]($url)"
            if [ -n "$config_paths" ] && [ "$config_paths" != "" ]; then
                echo "- Config: \`$config_paths\`"
            fi
            echo ""
        done
    fi

    # Security fixes
    security_tools=$(jq -r 'select(.flags | test("security")) | .name' "$INPUT_FILE" 2>/dev/null | sort -u)
    if [ -n "$security_tools" ]; then
        echo "## Security Updates (Update Recommended)"
        echo ""
        for tool in $security_tools; do
            latest=$(jq -r "select(.name == \"$tool\") | .tag" "$INPUT_FILE" | head -1)
            url=$(jq -r "select(.name == \"$tool\") | .url" "$INPUT_FILE" | head -1)
            echo "- **$tool** $latest — [$latest]($url)"
        done
        echo ""
    fi

    # Config changes
    config_tools=$(jq -r 'select(.flags | test("config-change")) | .name' "$INPUT_FILE" 2>/dev/null | sort -u)
    if [ -n "$config_tools" ]; then
        echo "## Config Changes (Review Recommended)"
        echo ""
        for tool in $config_tools; do
            latest=$(jq -r "select(.name == \"$tool\") | .tag" "$INPUT_FILE" | head -1)
            url=$(jq -r "select(.name == \"$tool\") | .url" "$INPUT_FILE" | head -1)
            config_paths=$(jq -r "select(.name == \"$tool\") | .config_paths" "$INPUT_FILE" | head -1)
            echo "- **$tool** $latest — [$latest]($url)"
            if [ -n "$config_paths" ] && [ "$config_paths" != "" ]; then
                echo "  - Config: \`$config_paths\`"
            fi
        done
        echo ""
    fi

    # New features
    feature_tools=$(jq -r 'select(.flags | test("new-feature")) | .name' "$INPUT_FILE" 2>/dev/null | sort -u)
    if [ -n "$feature_tools" ]; then
        echo "## New Features (Optional)"
        echo ""
        for tool in $feature_tools; do
            latest=$(jq -r "select(.name == \"$tool\") | .tag" "$INPUT_FILE" | head -1)
            url=$(jq -r "select(.name == \"$tool\") | .url" "$INPUT_FILE" | head -1)
            config_paths=$(jq -r "select(.name == \"$tool\") | .config_paths" "$INPUT_FILE" | head -1)
            echo "- **$tool** $latest — [$latest]($url)"
            if [ -n "$config_paths" ] && [ "$config_paths" != "" ]; then
                echo "  - Config: \`$config_paths\`"
            fi
        done
        echo ""
    fi

    echo "---"
    echo "*Generated by changelog-config-review.sh on $TODAY*"
} >"$REVIEW_FILE"

# Also run interactive review
for tool in $flagged_tools; do
    latest_tag=$(jq -r "select(.name == \"$tool\") | .tag" "$INPUT_FILE" | head -1)
    url=$(jq -r "select(.name == \"$tool\") | .url" "$INPUT_FILE" | head -1)
    flags=$(jq -r "select(.name == \"$tool\") | .flags" "$INPUT_FILE" | head -1)
    config_paths=$(jq -r "select(.name == \"$tool\") | .config_paths" "$INPUT_FILE" | head -1)

    review_tool_config "$tool" "$config_paths" "$flags" "$latest_tag" "$url"
done

echo -e "${BLUE}=== Config Review Complete ===${NC}"
echo -e "  Report: ${CYAN}$REVIEW_FILE${NC}"
echo ""
echo "To create a PR from this review, run:"
echo "  changelog-pr.sh --report $REVIEW_FILE"
