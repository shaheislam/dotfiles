#!/usr/bin/env bash
# Harness Engineering: Structural Architecture Tests
# Deterministic invariant checks that enforce conventions.
# Inspired by ArchUnit — tests the shape of the codebase, not its behavior.
#
# Usage: test-architecture.sh [DOTFILES_PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -gt 0 ] && [ -d "$1" ]; then
    ROOT="$(cd "$1" && pwd)"
else
    ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}  PASS${NC} $1"
}
fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}  FAIL${NC} $1"
}
skip() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}  SKIP${NC} $1"
}

echo -e "${BLUE}=== Architecture Test Suite ===${NC}"
echo ""

# ─────────────────────────────────────────────────────
# Group 1: Shell Script Conventions
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Shell Script Conventions ---${NC}"

# All .sh files must have a shebang
while IFS= read -r f; do
    first_line=$(head -1 "$f")
    rel="${f#$ROOT/}"
    if [[ "$first_line" =~ ^#! ]]; then
        pass "$rel has shebang"
    else
        fail "$rel missing shebang"
    fi
done < <(find "$ROOT/scripts" -name "*.sh" -type f 2>/dev/null)

# All .sh files must be executable
while IFS= read -r f; do
    rel="${f#$ROOT/}"
    if [ -x "$f" ]; then
        pass "$rel is executable"
    else
        fail "$rel not executable (chmod +x)"
    fi
done < <(find "$ROOT/scripts" -name "*.sh" -type f 2>/dev/null)

echo ""

# ─────────────────────────────────────────────────────
# Group 2: Fish Function Conventions
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Fish Function Conventions ---${NC}"

FISH_FUNC_DIR="$ROOT/.config/fish/functions"
if [ -d "$FISH_FUNC_DIR" ]; then
    # Fish functions should have --description
    desc_count=0
    no_desc_count=0
    for f in "$FISH_FUNC_DIR"/*.fish; do
        [ -f "$f" ] || continue
        rel="${f#$ROOT/}"
        if grep -q -- '--description' "$f"; then
            desc_count=$((desc_count + 1))
        else
            no_desc_count=$((no_desc_count + 1))
            fail "$rel missing --description flag"
        fi
    done
    if [ $no_desc_count -eq 0 ] && [ $desc_count -gt 0 ]; then
        pass "All $desc_count Fish functions have --description"
    fi

    # Fish function filename must match function name
    for f in "$FISH_FUNC_DIR"/*.fish; do
        [ -f "$f" ] || continue
        basename=$(basename "$f" .fish)
        rel="${f#$ROOT/}"
        if grep -qE "^function $basename\\b" "$f"; then
            pass "$rel: filename matches function name"
        else
            fail "$rel: filename '$basename' does not match function declaration"
        fi
    done
else
    skip "Fish functions directory not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# Group 3: Stow Package Integrity
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Stow Package Integrity ---${NC}"

# .config directories should be stow-managed (no orphans)
if [ -d "$ROOT/.config" ]; then
    for dir in "$ROOT/.config"/*/; do
        [ -d "$dir" ] || continue
        dirname=$(basename "$dir")
        # Verify the directory has at least one non-empty file
        if [ -n "$(find "$dir" -type f | head -1)" ]; then
            pass ".config/$dirname has content"
        else
            fail ".config/$dirname is empty (stow will skip)"
        fi
    done
fi

echo ""

# ─────────────────────────────────────────────────────
# Group 4: Hook Infrastructure
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Hook Infrastructure ---${NC}"

HOOKS_DIR="$ROOT/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    # All hook scripts must be executable
    for f in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.py; do
        [ -f "$f" ] || continue
        rel="${f#$ROOT/}"
        if [ -x "$f" ]; then
            pass "$rel is executable"
        else
            fail "$rel not executable"
        fi
    done

    # Hook scripts referenced in settings.json must exist
    SETTINGS="$ROOT/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
        # Extract hook script references
        hook_refs=$(grep -oE '[a-zA-Z0-9_-]+\.(sh|py)' "$SETTINGS" | sort -u)
        for ref in $hook_refs; do
            # Check if it exists somewhere in hooks/ or scripts/
            if find "$HOOKS_DIR" "$ROOT/scripts" -name "$ref" -type f 2>/dev/null | grep -q .; then
                pass "settings.json ref '$ref' found"
            else
                # Could be a non-local script (e.g., bd, entire) — skip those
                if [[ "$ref" =~ ^(bd|entire|claude) ]]; then
                    skip "settings.json ref '$ref' (external tool)"
                else
                    fail "settings.json ref '$ref' not found in hooks/ or scripts/"
                fi
            fi
        done
    fi
else
    skip "Hooks directory not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# Group 5: Documentation Consistency
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Documentation Consistency ---${NC}"

# CLAUDE.md must exist at root and .claude/
if [ -f "$ROOT/CLAUDE.md" ]; then
    pass "Root CLAUDE.md exists"
else
    fail "Root CLAUDE.md missing"
fi

if [ -f "$ROOT/.claude/CLAUDE.md" ]; then
    pass ".claude/CLAUDE.md exists"
else
    fail ".claude/CLAUDE.md missing"
fi

# Rules referenced by @ directives must exist
if [ -f "$ROOT/.claude/CLAUDE.md" ]; then
    refs=$(grep -oE '@[A-Z]+\.md' "$ROOT/.claude/CLAUDE.md" | sed 's/@//' || true)
    for ref in $refs; do
        if [ -f "$ROOT/.claude/$ref" ]; then
            pass "@$ref reference resolves"
        else
            fail "@$ref referenced but not found in .claude/"
        fi
    done
fi

echo ""

# ─────────────────────────────────────────────────────
# Group 6: No Hardcoded Paths
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Path Safety ---${NC}"

# Scripts should not hardcode /Users/username paths
bad_paths=0
for f in $(find "$ROOT/scripts" -name "*.sh" -type f 2>/dev/null | head -50); do
    rel="${f#$ROOT/}"
    if grep -qE '/Users/[a-z]+/' "$f" 2>/dev/null; then
        # Allow if it's in a comment
        non_comment=$(grep -vE '^\s*#' "$f" | grep -E '/Users/[a-z]+/' || true)
        if [ -n "$non_comment" ]; then
            fail "$rel contains hardcoded user path"
            bad_paths=$((bad_paths + 1))
        fi
    fi
done
if [ $bad_paths -eq 0 ]; then
    pass "No hardcoded user paths in scripts/"
fi

echo ""

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────
echo -e "${BLUE}=== Architecture Test Summary ===${NC}"
echo ""
echo -e "  Total:   $TESTS_RUN"
echo -e "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed:  $TESTS_FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"

if [ $TESTS_RUN -gt 0 ]; then
    rate=$(((TESTS_PASSED * 100) / TESTS_RUN))
    echo -e "  Rate:    ${rate}%"
fi

echo ""
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
