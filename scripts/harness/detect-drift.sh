#!/usr/bin/env bash
# Harness Engineering: Drift Detection
# Entropy management — finds configuration drift, stale symlinks, and inconsistencies.
# Run periodically or on-demand to catch issues before they compound.
#
# Usage: detect-drift.sh [DOTFILES_PATH]

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

DRIFT=0
WARNINGS=0

drift() {
    echo -e "${RED}DRIFT:${NC} $1"
    DRIFT=$((DRIFT + 1))
}
warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}
ok() { echo -e "${GREEN}OK:${NC} $1"; }

echo -e "${BLUE}=== Drift Detection ===${NC}"
echo ""

# ─────────────────────────────────────────────────────
# 1. Stow Symlink Integrity
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Stow Symlink Integrity ---${NC}"

# Check that key dotfiles are properly symlinked
declare -A EXPECTED_LINKS=(
    ["$HOME/.tmux.conf"]="$ROOT/.tmux.conf"
    ["$HOME/.zshrc"]="$ROOT/.zshrc"
    ["$HOME/.gitconfig"]="$ROOT/.gitconfig"
)

for target in "${!EXPECTED_LINKS[@]}"; do
    source="${EXPECTED_LINKS[$target]}"
    if [ -L "$target" ]; then
        actual=$(readlink "$target")
        if [ "$actual" = "$source" ] || [[ "$actual" == *"dotfiles/"* ]]; then
            ok "$target -> symlinked correctly"
        else
            drift "$target -> $actual (expected $source)"
        fi
    elif [ -f "$target" ]; then
        warn "$target exists but is not a symlink (stow may not have run)"
    else
        warn "$target does not exist"
    fi
done

# Check .config symlinks
if [ -d "$HOME/.config" ]; then
    for dir in "$ROOT/.config"/*/; do
        [ -d "$dir" ] || continue
        dirname=$(basename "$dir")
        target="$HOME/.config/$dirname"
        if [ -L "$target" ] || [ -d "$target" ]; then
            ok ".config/$dirname linked"
        else
            warn ".config/$dirname not linked to home"
        fi
    done
fi

echo ""

# ─────────────────────────────────────────────────────
# 2. Fish/Zsh PATH Parity
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- PATH Configuration Parity ---${NC}"

FISH_CONFIG="$ROOT/.config/fish/config.fish"
ZSHRC="$ROOT/.zshrc"

if [ -f "$FISH_CONFIG" ] && [ -f "$ZSHRC" ]; then
    # Extract PATH additions from Fish (fish_add_path or set PATH)
    fish_paths=$(grep -oE '(fish_add_path|set.*PATH).*(/[a-zA-Z0-9/.{}_-]+)' "$FISH_CONFIG" 2>/dev/null | grep -oE '/[a-zA-Z0-9/.{}_-]+' | sort -u || true)

    # Extract PATH additions from Zsh (export PATH=...)
    zsh_paths=$(grep -oE 'PATH.*(/[a-zA-Z0-9/.{}_-]+)' "$ZSHRC" 2>/dev/null | grep -oE '/[a-zA-Z0-9/.{}_-]+' | sort -u || true)

    # Common tool paths that should be in both
    common_paths=("/opt/homebrew/bin" "/usr/local/bin")
    for p in "${common_paths[@]}"; do
        in_fish=false
        in_zsh=false
        echo "$fish_paths" | grep -q "$p" && in_fish=true
        echo "$zsh_paths" | grep -q "$p" && in_zsh=true

        if $in_fish && $in_zsh; then
            ok "PATH '$p' in both Fish and Zsh"
        elif $in_fish; then
            warn "PATH '$p' in Fish but not Zsh"
        elif $in_zsh; then
            warn "PATH '$p' in Zsh but not Fish"
        fi
    done
else
    warn "Cannot check PATH parity: Fish config or .zshrc not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# 3. Tokyo Night Theme Consistency
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Theme Consistency ---${NC}"

# Check for Tokyo Night references across config files
theme_files=0
non_theme_files=0

while IFS= read -r config; do
    [ -f "$config" ] || continue
    rel="${config#$ROOT/}"

    # Look for color scheme references
    if grep -qiE '(tokyo.?night|tokyonight)' "$config" 2>/dev/null; then
        theme_files=$((theme_files + 1))
    elif grep -qiE '(color_?scheme|theme|colorscheme)' "$config" 2>/dev/null; then
        # Has a theme setting but it's not Tokyo Night
        scheme=$(grep -oiE '(color_?scheme|theme|colorscheme)\s*[=:]\s*\S+' "$config" 2>/dev/null | head -1 || true)
        if [ -n "$scheme" ] && ! echo "$scheme" | grep -qiE 'tokyo'; then
            warn "$rel has non-Tokyo Night theme: $scheme"
            non_theme_files=$((non_theme_files + 1))
        fi
    fi
done < <(find "$ROOT/.config" -maxdepth 2 -type f \( -name "*.conf" -o -name "*.toml" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" \) 2>/dev/null)

if [ $theme_files -gt 0 ] && [ $non_theme_files -eq 0 ]; then
    ok "Theme consistent: $theme_files configs use Tokyo Night"
elif [ $non_theme_files -gt 0 ]; then
    drift "$non_theme_files config(s) use non-Tokyo Night themes"
fi

echo ""

# ─────────────────────────────────────────────────────
# 4. Installed vs Declared Packages
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Package Drift ---${NC}"

BREWFILE="$ROOT/homebrew/Brewfile"
if [ -f "$BREWFILE" ] && command -v brew &>/dev/null; then
    # Check a few critical packages
    critical_pkgs=("fish" "stow" "tmux" "jq" "shellcheck" "git")
    for pkg in "${critical_pkgs[@]}"; do
        if brew list "$pkg" &>/dev/null; then
            if grep -qE "\"$pkg\"|'$pkg'" "$BREWFILE" 2>/dev/null; then
                ok "$pkg installed and in Brewfile"
            else
                warn "$pkg installed but NOT in Brewfile"
            fi
        else
            if grep -qE "\"$pkg\"|'$pkg'" "$BREWFILE" 2>/dev/null; then
                drift "$pkg in Brewfile but NOT installed"
            fi
        fi
    done
else
    warn "Cannot check packages: Brewfile or brew not found"
fi

echo ""

# ─────────────────────────────────────────────────────
# 5. OTEL Observability Health
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- OTEL Observability Health ---${NC}"

SETTINGS_FILE="$ROOT/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "OTEL_METRICS_EXPORTER" "$SETTINGS_FILE" 2>/dev/null; then
        ok "settings.json has OTEL env vars"
    else
        warn "settings.json missing OTEL env vars (OTEL_METRICS_EXPORTER)"
    fi

    if grep -q "CLAUDE_CODE_ENABLE_TELEMETRY" "$SETTINGS_FILE" 2>/dev/null; then
        ok "settings.json has CLAUDE_CODE_ENABLE_TELEMETRY"
    else
        warn "settings.json missing CLAUDE_CODE_ENABLE_TELEMETRY"
    fi
fi

# Check OTEL container if docker is available
if command -v docker &>/dev/null; then
    if docker ps --filter "name=otel-lgtm" --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
        ok "OTEL LGTM container running"
    else
        warn "OTEL LGTM container not running (start with: otel start)"
    fi
fi

echo ""

# ─────────────────────────────────────────────────────
# 6. Stale State Files
# ─────────────────────────────────────────────────────
echo -e "${BLUE}--- Stale State Files ---${NC}"

# Check for state files older than 7 days
stale_threshold=7
find "$HOME/.claude" -name "*.local.md" -mtime +"$stale_threshold" 2>/dev/null | while read -r f; do
    warn "Stale state file (>${stale_threshold}d): ${f#$HOME/}"
done

# Check for orphan PID files
find "$HOME/.claude" /tmp -maxdepth 2 -name "*.pid" -o -name "tmux-claude-*.pid" 2>/dev/null | while read -r pidfile; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
        warn "Orphan PID file: $pidfile (process $pid not running)"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────
echo -e "${BLUE}=== Drift Detection Summary ===${NC}"
echo ""
echo -e "  Drift issues: $DRIFT"
echo -e "  Warnings:     $WARNINGS"
echo ""

if [ $DRIFT -gt 0 ]; then
    echo -e "${RED}$DRIFT drift issue(s) detected. Run 'stow .' or fix manually.${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}No drift, but $WARNINGS warning(s) to review.${NC}"
    exit 0
else
    echo -e "${GREEN}No drift detected. Configuration is consistent.${NC}"
    exit 0
fi
