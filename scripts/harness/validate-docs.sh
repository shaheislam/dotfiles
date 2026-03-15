#!/usr/bin/env bash
# Harness Engineering: Documentation Consistency Validator
# Cross-references documentation against actual codebase state.
# Detects stale references, missing files, and function table drift.
#
# Usage: validate-docs.sh [DOTFILES_PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -gt 0 ] && [ -d "$1" ]; then
    ROOT="$(cd "$1" && pwd)"
else
    ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES=0
WARNINGS=0

issue() {
    echo -e "${RED}ISSUE:${NC} $1"
    ISSUES=$((ISSUES + 1))
}
warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}
ok() { echo -e "${GREEN}OK:${NC} $1"; }

echo -e "${BLUE}=== Documentation Consistency Validator ===${NC}"
echo ""

# ─────────────────────────────────────────────────────
# 1. CLAUDE.md Function Table vs Actual Functions
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Function Table Cross-Reference ---${NC}"

CLAUDE_MD="$ROOT/CLAUDE.md"
FISH_FUNC_DIR="$ROOT/.config/fish/functions"

if [ -f "$CLAUDE_MD" ] && [ -d "$FISH_FUNC_DIR" ]; then
    # Extract function names from the table (column 1 between pipes)
    table_funcs=$(grep -E '^\| `[a-z]' "$CLAUDE_MD" | sed -E 's/^\| `([^`]+)`.*/\1/' | sort -u)

    for func in $table_funcs; do
        if [ -f "$FISH_FUNC_DIR/$func.fish" ]; then
            ok "Function '$func' exists in fish/functions/"
        else
            issue "CLAUDE.md lists '$func' but $FISH_FUNC_DIR/$func.fish not found"
        fi
    done

    # Check for functions that exist but aren't documented
    if [ -n "$table_funcs" ]; then
        for f in "$FISH_FUNC_DIR"/gwt-*.fish "$FISH_FUNC_DIR"/codex-*.fish; do
            [ -f "$f" ] || continue
            basename=$(basename "$f" .fish)
            if ! echo "$table_funcs" | grep -qx "$basename"; then
                warn "Function '$basename' exists but not in CLAUDE.md function table"
            fi
        done
    fi
else
    warn "Cannot cross-reference: CLAUDE.md or fish/functions/ not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# 2. .claude/rules/ Files Cross-Reference
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Rules File Cross-Reference ---${NC}"

RULES_DIR="$ROOT/.claude/rules"
if [ -d "$RULES_DIR" ]; then
    # Check that files mentioned in CLAUDE.md actually exist
    rule_refs=$(grep -oE 'rules/[a-z0-9-]+\.md' "$CLAUDE_MD" 2>/dev/null | sort -u || true)
    for ref in $rule_refs; do
        if [ -f "$ROOT/.claude/$ref" ]; then
            ok "Rule reference '$ref' exists"
        else
            issue "CLAUDE.md references '$ref' but file not found"
        fi
    done

    # Check for rule files not referenced anywhere
    for f in "$RULES_DIR"/*.md; do
        [ -f "$f" ] || continue
        basename=$(basename "$f")
        if ! grep -rq "$basename" "$CLAUDE_MD" "$ROOT/.claude/CLAUDE.md" 2>/dev/null; then
            warn "Rule file '$basename' exists but not referenced in CLAUDE.md"
        fi
    done
else
    warn "Rules directory not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# 3. Scripts Referenced in CLAUDE.md
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Script Reference Validation ---${NC}"

# Extract script references like scripts/foo.sh or scripts/dir/bar.sh
script_refs=$(grep -oE 'scripts/[a-zA-Z0-9/_-]+\.(sh|py)' "$CLAUDE_MD" 2>/dev/null | sort -u || true)
for ref in $script_refs; do
    if [ -f "$ROOT/$ref" ]; then
        ok "Script '$ref' exists"
    else
        issue "CLAUDE.md references '$ref' but file not found"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# 4. Brewfile vs setup.sh Parity
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Brewfile / setup.sh Parity ---${NC}"

BREWFILE="$ROOT/homebrew/Brewfile"
SETUP_SH="$ROOT/scripts/setup.sh"

if [ -f "$BREWFILE" ] && [ -f "$SETUP_SH" ]; then
    # Check that brew formulae referenced in setup.sh are in Brewfile
    setup_brews=$(grep -oE 'brew install [a-z0-9_-]+' "$SETUP_SH" 2>/dev/null | awk '{print $3}' | sort -u || true)
    for pkg in $setup_brews; do
        if grep -qE "\"$pkg\"|'$pkg'" "$BREWFILE" 2>/dev/null; then
            ok "setup.sh brew install '$pkg' is in Brewfile"
        else
            warn "setup.sh installs '$pkg' but it's not in Brewfile"
        fi
    done
else
    warn "Cannot check parity: Brewfile or setup.sh not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# 5. MCP Server Config Parity
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- MCP Config Parity ---${NC}"

DESKTOP_CONFIG="$ROOT/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "$DESKTOP_CONFIG" ] && [ -f "$SETUP_SH" ]; then
    # Extract MCP server names from desktop config
    desktop_mcps=$(jq -r '.mcpServers | keys[]' "$DESKTOP_CONFIG" 2>/dev/null | sort || true)
    # Extract MCP server names from setup.sh (claude mcp add <name>)
    cli_mcps=$(grep -oE 'claude mcp add [a-z0-9_-]+' "$SETUP_SH" 2>/dev/null | awk '{print $4}' | sort || true)

    if [ -n "$desktop_mcps" ] && [ -n "$cli_mcps" ]; then
        # Desktop MCPs not in CLI
        for mcp in $desktop_mcps; do
            if echo "$cli_mcps" | grep -qx "$mcp"; then
                ok "MCP '$mcp' in both desktop and CLI"
            else
                warn "MCP '$mcp' in desktop config but not in setup.sh CLI"
            fi
        done
    fi
else
    warn "Cannot check MCP parity: desktop config or setup.sh not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────
echo -e "${BLUE}=== Documentation Validation Summary ===${NC}"
echo ""
echo -e "  Issues:   $ISSUES"
echo -e "  Warnings: $WARNINGS"
echo ""

if [ $ISSUES -gt 0 ]; then
    echo -e "${RED}Documentation has $ISSUES issue(s) that should be addressed.${NC}"
    exit 1
else
    echo -e "${GREEN}Documentation is consistent.${NC}"
    exit 0
fi
