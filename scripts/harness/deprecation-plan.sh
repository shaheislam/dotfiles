#!/usr/bin/env bash
# Harness Engineering: Deprecation Planning
# Analyzes the impact of removing a tool/config from the dotfiles.
# Uses dep-trace (Fish) and git history to produce a removal plan.
#
# Usage:
#   deprecation-plan.sh <tool-name>           # Full deprecation analysis
#   deprecation-plan.sh <tool-name> --json    # JSON output for scripting
#   deprecation-plan.sh <tool-name> --brief   # One-line summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BREWFILE="$ROOT/homebrew/Brewfile"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo "Usage: deprecation-plan.sh <tool-name> [--json|--brief]"
    echo ""
    echo "Analyzes the impact of removing a tool from the dotfiles."
    echo "Produces: dependency map, removal sequence, affected files, effort estimate."
    exit 0
}

[[ $# -eq 0 ]] && usage
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

TOOL="$1"
shift
JSON_OUTPUT=false
BRIEF=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --json) JSON_OUTPUT=true ;;
    --brief) BRIEF=true ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

# ─────────────────────────────────────────────────────
# 1. Gather dependency data via ripgrep
# ─────────────────────────────────────────────────────

fish_funcs=$(rg -l --no-heading "$TOOL" "$ROOT/.config/fish/functions/" 2>/dev/null || true)
fish_conf=$(rg -l --no-heading "$TOOL" "$ROOT/.config/fish/config.fish" "$ROOT/.config/fish/conf.d/" 2>/dev/null || true)
scripts=$(rg -l --no-heading "$TOOL" "$ROOT/scripts/" 2>/dev/null || true)
configs=$(rg -l --no-heading "$TOOL" "$ROOT/.config/" --glob '!fish/**' 2>/dev/null || true)
claude_refs=$(rg -l --no-heading "$TOOL" "$ROOT/.claude/" 2>/dev/null || true)
zsh_refs=$(rg -l --no-heading "$TOOL" "$ROOT/.zshrc" "$ROOT/.zprofile" 2>/dev/null || true)
brewfile_hit=$(rg --no-heading "$TOOL" "$BREWFILE" 2>/dev/null || true)
has_config_dir="no"
[[ -d "$ROOT/.config/$TOOL" ]] && has_config_dir="yes"

# Count totals
count_lines() { echo "$1" | grep -c . 2>/dev/null || echo 0; }
fish_func_count=$(count_lines "$fish_funcs")
fish_conf_count=$(count_lines "$fish_conf")
script_count=$(count_lines "$scripts")
config_count=$(count_lines "$configs")
claude_count=$(count_lines "$claude_refs")
zsh_count=$(count_lines "$zsh_refs")
total=$((fish_func_count + fish_conf_count + script_count + config_count + claude_count + zsh_count))

# ─────────────────────────────────────────────────────
# 2. Git history analysis
# ─────────────────────────────────────────────────────

last_modified=$(git -C "$ROOT" log -1 --format="%cr" -- "*$TOOL*" 2>/dev/null || echo "unknown")
commit_count=$(git -C "$ROOT" log --oneline -- "*$TOOL*" 2>/dev/null | wc -l | xargs)

# ─────────────────────────────────────────────────────
# 3. Impact assessment
# ─────────────────────────────────────────────────────

if [[ $total -gt 10 ]]; then
    impact="HIGH"
    effort="2-4 hours"
elif [[ $total -gt 3 ]]; then
    impact="MEDIUM"
    effort="30-60 minutes"
else
    impact="LOW"
    effort="< 30 minutes"
fi

# ─────────────────────────────────────────────────────
# Brief mode
# ─────────────────────────────────────────────────────

if $BRIEF; then
    echo "$TOOL: $total refs | impact:$impact | effort:$effort | brew:$([ -n "$brewfile_hit" ] && echo "yes" || echo "no") | config-dir:$has_config_dir"
    exit 0
fi

# ─────────────────────────────────────────────────────
# JSON mode
# ─────────────────────────────────────────────────────

if $JSON_OUTPUT; then
    to_json_array() {
        if [[ -z "$1" ]]; then
            echo "[]"
        else
            echo "$1" | jq -R . | jq -s .
        fi
    }

    jq -nc \
        --arg tool "$TOOL" \
        --arg impact "$impact" \
        --arg effort "$effort" \
        --arg last_modified "$last_modified" \
        --arg commit_count "$commit_count" \
        --arg config_dir "$has_config_dir" \
        --arg brewfile "$brewfile_hit" \
        --arg total "$total" \
        --argjson fish_funcs "$(to_json_array "$fish_funcs")" \
        --argjson scripts "$(to_json_array "$scripts")" \
        --argjson configs "$(to_json_array "$configs")" \
        '{
            tool: $tool,
            impact: $impact,
            effort: $effort,
            total_refs: ($total | tonumber),
            last_modified: $last_modified,
            commit_count: ($commit_count | tonumber),
            has_config_dir: ($config_dir == "yes"),
            in_brewfile: ($brewfile != ""),
            fish_functions: $fish_funcs,
            scripts: $scripts,
            configs: $configs
        }'
    exit 0
fi

# ─────────────────────────────────────────────────────
# Human-readable output
# ─────────────────────────────────────────────────────

echo -e "${BOLD}Deprecation Plan: $TOOL${NC}"
echo "════════════════════════════════════════"
echo ""

# Impact summary
echo -e "${BOLD}Impact Assessment${NC}"
echo "────────────────────────────────────────"
echo -e "  Impact level:     ${impact}"
echo -e "  Estimated effort: ${effort}"
echo -e "  Total references: ${total}"
echo -e "  Git commits:      ${commit_count}"
echo -e "  Last modified:    ${last_modified}"
echo ""

# Brewfile
echo -e "${BOLD}Package Management${NC}"
echo "────────────────────────────────────────"
if [[ -n "$brewfile_hit" ]]; then
    echo -e "  ${RED}Remove from Brewfile:${NC}"
    echo "    $brewfile_hit"
else
    echo -e "  ${GREEN}Not in Brewfile (no package to remove)${NC}"
fi
echo ""

# Config directory
echo -e "${BOLD}Configuration${NC}"
echo "────────────────────────────────────────"
if [[ "$has_config_dir" == "yes" ]]; then
    echo -e "  ${RED}Remove config directory:${NC} .config/$TOOL/"
    ls "$ROOT/.config/$TOOL/" 2>/dev/null | sed 's/^/    /'
else
    echo -e "  ${GREEN}No dedicated config directory${NC}"
fi
echo ""

# Files to modify
echo -e "${BOLD}Files to Modify${NC}"
echo "────────────────────────────────────────"

print_file_list() {
    local label="$1" files="$2" count="$3"
    if [[ -n "$files" && "$count" -gt 0 ]]; then
        echo -e "  ${YELLOW}${label} (${count}):${NC}"
        echo "$files" | sed "s|$ROOT/||" | sed 's/^/    /'
    fi
}

print_file_list "Fish functions" "$fish_funcs" "$fish_func_count"
print_file_list "Fish config/conf.d" "$fish_conf" "$fish_conf_count"
print_file_list "Scripts" "$scripts" "$script_count"
print_file_list "Other configs" "$configs" "$config_count"
print_file_list "Claude references" "$claude_refs" "$claude_count"
print_file_list "Zsh references" "$zsh_refs" "$zsh_count"
echo ""

# Removal sequence
echo -e "${BOLD}Recommended Removal Sequence${NC}"
echo "────────────────────────────────────────"
step=1

if [[ -n "$fish_funcs" ]]; then
    echo "  $step. Remove/update Fish functions that depend on $TOOL"
    step=$((step + 1))
fi

if [[ -n "$fish_conf" ]]; then
    echo "  $step. Clean Fish config.fish / conf.d references"
    step=$((step + 1))
fi

if [[ -n "$zsh_refs" ]]; then
    echo "  $step. Clean Zsh config references"
    step=$((step + 1))
fi

if [[ -n "$scripts" ]]; then
    echo "  $step. Update or remove scripts"
    step=$((step + 1))
fi

if [[ -n "$configs" ]]; then
    echo "  $step. Remove/update other config files"
    step=$((step + 1))
fi

if [[ "$has_config_dir" == "yes" ]]; then
    echo "  $step. Remove .config/$TOOL/ directory"
    step=$((step + 1))
fi

if [[ -n "$brewfile_hit" ]]; then
    echo "  $step. Remove from homebrew/Brewfile"
    step=$((step + 1))
fi

if [[ -n "$claude_refs" ]]; then
    echo "  $step. Update Claude documentation references"
    step=$((step + 1))
fi

echo "  $step. Run stow to verify symlinks are clean"
step=$((step + 1))
echo "  $step. Commit: chore: remove $TOOL"
echo ""

echo -e "${BOLD}Checklist${NC}"
echo "────────────────────────────────────────"
echo "  [ ] All dependents identified above have been updated"
echo "  [ ] No runtime errors in Fish shell after removal"
echo "  [ ] No runtime errors in Zsh after removal"
echo "  [ ] stow --restow completes without errors"
echo "  [ ] scripts/setup.sh runs without errors"
echo "  [ ] No broken symlinks (detect-drift.sh)"
