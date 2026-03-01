#!/usr/bin/env bash
# Test Claude Code configuration follows best practices
# Based on: https://code.claude.com/docs/en/overview
set -euo pipefail

DOTFILES="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0
WARN=0

pass() {
    PASS=$((PASS + 1))
    printf "  \033[32m✓\033[0m %s\n" "$1"
}
fail() {
    FAIL=$((FAIL + 1))
    printf "  \033[31m✗\033[0m %s\n" "$1"
}
warn() {
    WARN=$((WARN + 1))
    printf "  \033[33m!\033[0m %s\n" "$1"
}

echo "=== Claude Code Config Best Practices Test ==="
echo "Dotfiles: $DOTFILES"
echo ""

# --- CLAUDE.md Size Tests ---
echo "--- CLAUDE.md Size (target: <200 lines) ---"

root_lines=$(wc -l <"$DOTFILES/CLAUDE.md" 2>/dev/null || echo 0)
if [ "$root_lines" -lt 200 ]; then
    pass "Root CLAUDE.md: ${root_lines} lines (< 200)"
else
    fail "Root CLAUDE.md: ${root_lines} lines (>= 200, recommended < 200)"
fi

if [ -f "$DOTFILES/.claude/CLAUDE.md" ]; then
    inner_lines=$(wc -l <"$DOTFILES/.claude/CLAUDE.md")
    if [ "$inner_lines" -lt 200 ]; then
        pass ".claude/CLAUDE.md: ${inner_lines} lines (< 200)"
    else
        fail ".claude/CLAUDE.md: ${inner_lines} lines (>= 200)"
    fi
fi

# Check imported files referenced by .claude/CLAUDE.md
if [ -f "$DOTFILES/.claude/CLAUDE.md" ]; then
    while IFS= read -r import; do
        import_file="$DOTFILES/.claude/$import"
        if [ -f "$import_file" ]; then
            import_lines=$(wc -l <"$import_file")
            if [ "$import_lines" -lt 200 ]; then
                pass "Import $import: ${import_lines} lines (< 200)"
            else
                warn "Import $import: ${import_lines} lines (consider splitting)"
            fi
        fi
    done < <(grep -o '^@[^ ]*' "$DOTFILES/.claude/CLAUDE.md" | sed 's/^@//')
fi

echo ""

# --- .claude/rules/ Tests ---
echo "--- .claude/rules/ (path-scoped rules) ---"

if [ -d "$DOTFILES/.claude/rules" ]; then
    rule_count=$(find "$DOTFILES/.claude/rules" -name '*.md' | wc -l)
    pass ".claude/rules/ directory exists (${rule_count} rules)"

    # Check rules have frontmatter with paths
    while IFS= read -r rule; do
        basename_rule=$(basename "$rule")
        if head -1 "$rule" | grep -q '^---'; then
            if grep -q 'paths:' "$rule"; then
                pass "Rule ${basename_rule}: has path-scoped frontmatter"
            else
                warn "Rule ${basename_rule}: has frontmatter but no paths (loads every session)"
            fi
        else
            warn "Rule ${basename_rule}: missing YAML frontmatter"
        fi
    done < <(find "$DOTFILES/.claude/rules" -name '*.md')
else
    fail ".claude/rules/ directory missing (recommended for path-scoped rules)"
fi

echo ""

# --- .claude/agents/ Tests ---
echo "--- .claude/agents/ (custom subagents) ---"

if [ -d "$DOTFILES/.claude/agents" ]; then
    agent_count=$(find "$DOTFILES/.claude/agents" -name '*.md' | wc -l)
    pass ".claude/agents/ directory exists (${agent_count} agents)"

    while IFS= read -r agent; do
        basename_agent=$(basename "$agent")
        if head -1 "$agent" | grep -q '^---'; then
            if grep -q 'description:' "$agent"; then
                pass "Agent ${basename_agent}: has description"
            else
                warn "Agent ${basename_agent}: missing description field"
            fi
            if grep -q 'tools:' "$agent"; then
                pass "Agent ${basename_agent}: has tool restrictions"
            else
                warn "Agent ${basename_agent}: no tool restrictions (has full access)"
            fi
        else
            fail "Agent ${basename_agent}: missing YAML frontmatter"
        fi
    done < <(find "$DOTFILES/.claude/agents" -name '*.md')
else
    fail ".claude/agents/ directory missing"
fi

echo ""

# --- Skills Tests ---
echo "--- Skills Configuration ---"

if [ -d "$DOTFILES/.claude/skills" ]; then
    skill_count=$(find "$DOTFILES/.claude/skills" -name 'SKILL.md' 2>/dev/null | wc -l)
    pass ".claude/skills/ exists (${skill_count} skills)"

    # Check skills have frontmatter
    skills_with_frontmatter=0
    skills_total=0
    while IFS= read -r skill; do
        skills_total=$((skills_total + 1))
        if head -1 "$skill" | grep -q '^---'; then
            skills_with_frontmatter=$((skills_with_frontmatter + 1))
        fi
    done < <(find "$DOTFILES/.claude/skills" -name 'SKILL.md' 2>/dev/null)

    if [ "$skills_total" -gt 0 ]; then
        pct=$((skills_with_frontmatter * 100 / skills_total))
        if [ "$pct" -ge 80 ]; then
            pass "Skills with frontmatter: ${skills_with_frontmatter}/${skills_total} (${pct}%)"
        else
            warn "Skills with frontmatter: ${skills_with_frontmatter}/${skills_total} (${pct}%, target >= 80%)"
        fi
    fi
else
    fail ".claude/skills/ directory missing"
fi

echo ""

# --- Hooks Tests ---
echo "--- Hooks Configuration ---"

if [ -f "$DOTFILES/.claude/settings.json" ]; then
    if python3 -c "import json; json.load(open('$DOTFILES/.claude/settings.json'))" 2>/dev/null; then
        pass "settings.json: valid JSON"
    else
        fail "settings.json: invalid JSON"
    fi

    if python3 -c "import json; d=json.load(open('$DOTFILES/.claude/settings.json')); assert 'hooks' in d" 2>/dev/null; then
        hook_events=$(python3 -c "import json; d=json.load(open('$DOTFILES/.claude/settings.json')); print(len(d.get('hooks', {})))")
        pass "Hooks configured: ${hook_events} events"
    else
        warn "No hooks configured in settings.json"
    fi
else
    warn ".claude/settings.json not found"
fi

echo ""

# --- Summary ---
echo "=== Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "RESULT: FAIL"
    exit 1
else
    echo "RESULT: PASS"
    exit 0
fi
