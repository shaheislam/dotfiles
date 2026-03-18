#!/usr/bin/env bash
# Harness Engineering: Initializer
# Bootstraps the harness environment following Anthropic's initializer agent pattern.
# Activates pre-commit hooks, validates scripts, runs initial verification.
#
# Usage:
#   init.sh              # Full bootstrap
#   init.sh --check      # Verify-only (no modifications)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

check_only=false
[[ "${1:-}" == "--check" ]] && check_only=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Harness Initializer ===${NC}"
echo ""

# ─────────────────────────────────────────────────────
# 1. Activate git pre-commit hooks
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Git Pre-Commit Hooks ---${NC}"

current_hooks_path=$(git -C "$ROOT" config core.hooksPath 2>/dev/null || echo "")
if [ "$current_hooks_path" = ".githooks" ]; then
    echo -e "${GREEN}OK${NC} core.hooksPath already set to .githooks"
else
    if $check_only; then
        echo -e "${YELLOW}NEEDS FIX${NC} core.hooksPath not set (currently: '${current_hooks_path:-unset}')"
    else
        git -C "$ROOT" config core.hooksPath .githooks
        echo -e "${GREEN}SET${NC} core.hooksPath = .githooks"
    fi
fi

if [ -f "$ROOT/.githooks/pre-commit" ] && [ -x "$ROOT/.githooks/pre-commit" ]; then
    echo -e "${GREEN}OK${NC} .githooks/pre-commit is executable"
else
    if $check_only; then
        echo -e "${YELLOW}NEEDS FIX${NC} .githooks/pre-commit missing or not executable"
    elif [ -f "$ROOT/.githooks/pre-commit" ]; then
        chmod +x "$ROOT/.githooks/pre-commit"
        echo -e "${GREEN}FIXED${NC} Made .githooks/pre-commit executable"
    else
        echo -e "${RED}MISSING${NC} .githooks/pre-commit does not exist"
    fi
fi

echo ""

# ─────────────────────────────────────────────────────
# 2. Validate harness scripts are executable
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Harness Script Permissions ---${NC}"

for script in "$SCRIPT_DIR"/*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    if [ -x "$script" ]; then
        echo -e "${GREEN}OK${NC} $name is executable"
    else
        if $check_only; then
            echo -e "${YELLOW}NEEDS FIX${NC} $name not executable"
        else
            chmod +x "$script"
            echo -e "${GREEN}FIXED${NC} Made $name executable"
        fi
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# 3. Validate required directories
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Required Directories ---${NC}"

required_dirs=(
    "$HOME/.claude/harness"
    "$HOME/.claude/hooks/logs"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}OK${NC} $dir exists"
    else
        if $check_only; then
            echo -e "${YELLOW}NEEDS FIX${NC} $dir missing"
        else
            mkdir -p "$dir"
            echo -e "${GREEN}CREATED${NC} $dir"
        fi
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# 4. Validate required tools
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Required Tools ---${NC}"

tools=("jq" "shellcheck" "git" "stow")
for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        version=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
        echo -e "${GREEN}OK${NC} $tool: $version"
    else
        echo -e "${RED}MISSING${NC} $tool not found (install via Brewfile)"
    fi
done

# Optional tools
optional=("fish" "fish_indent" "yamllint" "bd" "entire")
for tool in "${optional[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo -e "${GREEN}OK${NC} $tool available"
    else
        echo -e "${YELLOW}OPTIONAL${NC} $tool not found"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# 5. Run feature verification
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Feature Verification ---${NC}"

if [ -x "$SCRIPT_DIR/verify-harness.sh" ]; then
    "$SCRIPT_DIR/verify-harness.sh" --summary || true
else
    echo -e "${YELLOW}SKIP${NC} verify-harness.sh not executable"
fi

echo ""
echo -e "${BLUE}=== Harness initialization complete ===${NC}"
