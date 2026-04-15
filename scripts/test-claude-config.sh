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

	for compat_skill in audit build-fix checkpoint commit deploy-check full-review handoff rebase review-pr ticket verify; do
		if [ -f "$DOTFILES/.claude/skills/${compat_skill}/SKILL.md" ]; then
			pass "Compatibility skill ${compat_skill}: present"
		else
			fail "Compatibility skill ${compat_skill}: missing"
		fi
	done
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

# --- settings.json Feature Keys ---
echo "--- settings.json Feature Keys ---"

if [ -f "$DOTFILES/.claude/settings.json" ]; then
	for key in '$schema' attribution fileSuggestion statusLine; do
		if python3 -c "import json; d=json.load(open('$DOTFILES/.claude/settings.json')); assert '$key' in d" 2>/dev/null; then
			pass "settings.json: '$key' present"
		else
			fail "settings.json: '$key' missing"
		fi
	done
fi

echo ""

# --- Statusline Script Tests ---
echo "--- Statusline Script ---"

STATUSLINE="$DOTFILES/scripts/claude-statusline.sh"
if [ -f "$STATUSLINE" ]; then
	pass "claude-statusline.sh exists"
	if [ -x "$STATUSLINE" ]; then
		pass "claude-statusline.sh is executable"
	else
		fail "claude-statusline.sh is not executable"
	fi

	# Test with mock JSON input
	MOCK='{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"cost":{"total_cost_usd":0.01,"total_duration_ms":5000},"context_window":{"used_percentage":25}}'
	OUTPUT=$(echo "$MOCK" | bash "$STATUSLINE" 2>/dev/null || true)
	if echo "$OUTPUT" | grep -q "Test"; then
		pass "Statusline renders model name from mock input"
	else
		fail "Statusline failed to render mock input"
	fi
else
	fail "claude-statusline.sh missing"
fi

echo ""

# --- Agent Memory/Permission Tests ---
echo "--- Agent Memory & Permissions ---"

if [ -d "$DOTFILES/.claude/agents" ]; then
	for agent in security-reviewer config-explorer; do
		if [ -f "$DOTFILES/.claude/agents/${agent}.md" ]; then
			if grep -q 'memory:' "$DOTFILES/.claude/agents/${agent}.md"; then
				pass "Agent ${agent}: has memory field"
			else
				warn "Agent ${agent}: missing memory field"
			fi
		fi
	done

	if [ -f "$DOTFILES/.claude/agents/shell-tester.md" ]; then
		if grep -q 'permissionMode:' "$DOTFILES/.claude/agents/shell-tester.md"; then
			pass "Agent shell-tester: has permissionMode field"
		else
			warn "Agent shell-tester: missing permissionMode field"
		fi
	fi
fi

echo ""

# --- Output Styles Tests ---
echo "--- Output Styles ---"

if [ -d "$DOTFILES/.claude/output-styles" ]; then
	style_count=$(find "$DOTFILES/.claude/output-styles" -name '*.md' | wc -l)
	pass ".claude/output-styles/ directory exists (${style_count} styles)"

	while IFS= read -r style; do
		basename_style=$(basename "$style")
		if head -1 "$style" | grep -q '^---'; then
			pass "Style ${basename_style}: has frontmatter"
		else
			warn "Style ${basename_style}: missing frontmatter"
		fi
	done < <(find "$DOTFILES/.claude/output-styles" -name '*.md')
else
	warn ".claude/output-styles/ directory missing"
fi

echo ""

# --- Subagent Lifecycle Hook Tests ---
echo "--- Subagent Lifecycle Hooks ---"

if [ -f "$DOTFILES/.claude/settings.json" ]; then
	for event in SubagentStart SubagentStop; do
		if python3 -c "import json; d=json.load(open('$DOTFILES/.claude/settings.json')); assert '$event' in d.get('hooks', {})" 2>/dev/null; then
			pass "Hook event '$event' wired in settings.json"
		else
			fail "Hook event '$event' missing from settings.json"
		fi
	done
fi

LIFECYCLE_HOOK="$DOTFILES/.claude/hooks/subagent-lifecycle.sh"
if [ -f "$LIFECYCLE_HOOK" ]; then
	pass "subagent-lifecycle.sh exists"
	if [ -x "$LIFECYCLE_HOOK" ]; then
		pass "subagent-lifecycle.sh is executable"
	else
		fail "subagent-lifecycle.sh is not executable"
	fi
else
	fail "subagent-lifecycle.sh missing"
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
