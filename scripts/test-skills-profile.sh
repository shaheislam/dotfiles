#!/usr/bin/env bash
# Test suite for skills-profile and skills-manifest systems
# Usage: scripts/test-skills-profile.sh [--verbose]
set -euo pipefail

PASS=0
FAIL=0
SKIP=0
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$DOTFILES_DIR/skills"

# ── Helpers ──────────────────────────────────────────

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    [ -n "${2:-}" ] && echo "    $2"
}

skip() {
    SKIP=$((SKIP + 1))
    echo "  ⊘ $1 (skipped)"
}

section() {
    echo ""
    echo "── $1 ──"
}

# ── Directory Structure Tests ────────────────────────

section "Directory Structure"

if [ -d "$SKILLS_DIR" ]; then
    pass "skills/ directory exists"
else
    fail "skills/ directory missing"
fi

if [ -d "$SKILLS_DIR/profiles" ]; then
    pass "skills/profiles/ directory exists"
else
    fail "skills/profiles/ directory missing"
fi

if [ -d "$SKILLS_DIR/shared" ]; then
    pass "skills/shared/ directory exists"
else
    fail "skills/shared/ directory missing"
fi

if [ -d "$SKILLS_DIR/personal" ]; then
    pass "skills/personal/ directory exists"
else
    fail "skills/personal/ directory missing"
fi

if [ -d "$SKILLS_DIR/work" ]; then
    pass "skills/work/ directory exists"
else
    fail "skills/work/ directory missing"
fi

for harness_dir in .claude/skills .agents/skills .gemini/skills .opencode/skills .pi/agent/skills; do
    if [ -d "$DOTFILES_DIR/$harness_dir" ]; then
        pass "$harness_dir directory exists"
    else
        fail "$harness_dir directory missing"
    fi
done

if [ -f "$SKILLS_DIR/README.md" ]; then
    pass "skills/README.md exists"
else
    fail "skills/README.md missing"
fi

# ── Profile Tests ────────────────────────────────────

section "Profile Definitions"

for profile in personal work server; do
    profile_file="$SKILLS_DIR/profiles/$profile.toml"
    if [ -f "$profile_file" ]; then
        pass "$profile.toml exists"

        # Check required fields
        if grep -q '^\[profile\]' "$profile_file"; then
            pass "$profile.toml has [profile] section"
        else
            fail "$profile.toml missing [profile] section"
        fi

        if grep -q '^name' "$profile_file"; then
            pass "$profile.toml has name field"
        else
            fail "$profile.toml missing name field"
        fi

        if grep -q '^description' "$profile_file"; then
            pass "$profile.toml has description field"
        else
            fail "$profile.toml missing description field"
        fi

        if grep -q '^\[skills\]' "$profile_file"; then
            pass "$profile.toml has [skills] section"
        else
            fail "$profile.toml missing [skills] section"
        fi

        if grep -q '^include' "$profile_file"; then
            pass "$profile.toml has include list"
        else
            fail "$profile.toml missing include list"
        fi
    else
        fail "$profile.toml missing"
    fi
done

# ── Skill Format Tests ──────────────────────────────

section "Skill Format (SKILL.md)"

skill_count=0
bad_count=0

while IFS= read -r skill_file; do
    skill_count=$((skill_count + 1))
    skill_name=$(basename "$(dirname "$skill_file")")

    # Check YAML frontmatter
    if head -1 "$skill_file" | grep -q '^---'; then
        pass "$skill_name: has YAML frontmatter"
    else
        fail "$skill_name: missing YAML frontmatter"
        bad_count=$((bad_count + 1))
        continue
    fi

    # Check required 'name' field
    if grep -q '^name:' "$skill_file"; then
        pass "$skill_name: has name field"
    else
        fail "$skill_name: missing name field"
        bad_count=$((bad_count + 1))
    fi

    # Check required 'description' field
    if grep -q '^description:' "$skill_file"; then
        pass "$skill_name: has description field"
    else
        fail "$skill_name: missing description field"
        bad_count=$((bad_count + 1))
    fi

    # Check closing frontmatter delimiter
    if awk 'NR>1 && /^---/' "$skill_file" | head -1 | grep -q '^---'; then
        pass "$skill_name: frontmatter properly closed"
    else
        fail "$skill_name: frontmatter not closed"
        bad_count=$((bad_count + 1))
    fi
done < <(find "$SKILLS_DIR" -name "SKILL.md" -not -path "*/profiles/*" 2>/dev/null)

if [ "$skill_count" -gt 0 ]; then
    pass "Found $skill_count skill(s) in library"
else
    fail "No skills found in library"
fi

# ── Category Tests ───────────────────────────────────

section "Skill Categories"

for category in shared personal work; do
    cat_dir="$SKILLS_DIR/$category"
    if [ -d "$cat_dir" ]; then
        count=$(find "$cat_dir" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            pass "$category: $count skill(s)"
        else
            fail "$category: empty (no SKILL.md files)"
        fi
    fi
done

# ── Profile Include Validation ───────────────────────

section "Profile Includes Validation"

for profile_file in "$SKILLS_DIR/profiles/"*.toml; do
    [ -f "$profile_file" ] || continue
    profile_name=$(basename "$profile_file" .toml)

    # Extract includes
    includes=$(grep '^include' "$profile_file" | sed 's/include.*=.*\[//;s/\].*//;s/"//g;s/,/ /g' | tr -d "'" | xargs)

    for inc in $includes; do
        if [ -d "$SKILLS_DIR/$inc" ]; then
            pass "$profile_name: includes '$inc' → exists"
        else
            fail "$profile_name: includes '$inc' → directory not found"
        fi
    done
done

# ── Fish Function Tests ──────────────────────────────

section "Fish Functions"

fish_funcs_dir="$DOTFILES_DIR/.config/fish/functions"

if [ -f "$fish_funcs_dir/skills-profile.fish" ]; then
    pass "skills-profile.fish exists"

    # Check it has all subcommands
    for subcmd in activate deactivate list status doctor help; do
        if grep -q "case $subcmd" "$fish_funcs_dir/skills-profile.fish"; then
            pass "skills-profile: has '$subcmd' subcommand"
        else
            fail "skills-profile: missing '$subcmd' subcommand"
        fi
    done
else
    fail "skills-profile.fish missing"
fi

if [ -f "$fish_funcs_dir/skills-manifest.fish" ]; then
    pass "skills-manifest.fish exists"

    for subcmd in sync init clean status help; do
        if grep -q "case $subcmd" "$fish_funcs_dir/skills-manifest.fish"; then
            pass "skills-manifest: has '$subcmd' subcommand"
        else
            fail "skills-manifest: missing '$subcmd' subcommand"
        fi
    done
else
    fail "skills-manifest.fish missing"
fi

if [ -x "$DOTFILES_DIR/scripts/sync-skills-harnesses.sh" ]; then
    pass "sync-skills-harnesses.sh exists and is executable"
else
    fail "sync-skills-harnesses.sh missing or not executable"
fi

# ── Manifest Tests ───────────────────────────────────

section "Skill Manifest"

manifest_file="$DOTFILES_DIR/.claude/skill-manifest.toml"

if [ -f "$manifest_file" ]; then
    pass "skill-manifest.toml exists"

    if grep -q '^\[manifest\]' "$manifest_file"; then
        pass "manifest has [manifest] section"
    else
        fail "manifest missing [manifest] section"
    fi

    if grep -q '^\[sources\]' "$manifest_file"; then
        pass "manifest has [sources] section"
    else
        fail "manifest missing [sources] section"
    fi

    # Validate source references resolve
    in_sources=false
    while IFS= read -r line; do
        trimmed=$(echo "$line" | xargs)
        if [ "$trimmed" = "[sources]" ]; then
            in_sources=true
            continue
        fi
        if echo "$trimmed" | grep -q '^\['; then
            in_sources=false
            continue
        fi
        if [ "$in_sources" = true ] && echo "$trimmed" | grep -q '=' && ! echo "$trimmed" | grep -q '^#'; then
            key="${trimmed%%=*}"
            key="${key%"${key##*[![:space:]]}"}"
            val=$(echo "$trimmed" | sed 's/^[^=]*=\s*//' | tr -d '"' | xargs)

            if echo "$val" | grep -q '^dotfiles:'; then
                rel="${val#dotfiles:}"
                resolved="$SKILLS_DIR/$rel"
                if [ -d "$resolved" ] && [ -f "$resolved/SKILL.md" ]; then
                    pass "manifest source '$key' → resolves to valid skill"
                else
                    fail "manifest source '$key' → not found at $resolved"
                fi
            fi
        fi
    done <"$manifest_file"
else
    fail "skill-manifest.toml missing"
fi

# ── Fish Syntax Check ────────────────────────────────

section "Fish Syntax Validation"

if command -v fish >/dev/null 2>&1; then
    for fish_file in "$fish_funcs_dir/skills-profile.fish" "$fish_funcs_dir/skills-manifest.fish"; do
        if [ -f "$fish_file" ]; then
            if fish -n "$fish_file" 2>/dev/null; then
                pass "$(basename "$fish_file"): valid Fish syntax"
            else
                fail "$(basename "$fish_file"): Fish syntax error"
            fi
        fi
    done
else
    skip "Fish not installed, skipping syntax checks"
fi

# ── Cross-Tool Compatibility ─────────────────────────

section "Agent Skills Standard Compatibility"

while IFS= read -r skill_file; do
    skill_name=$(basename "$(dirname "$skill_file")")

    # Agent Skills standard requires: name (1-64 chars, lowercase+hyphens)
    name_val=$(grep '^name:' "$skill_file" | head -1 | sed 's/^name:[[:space:]]*//')
    if echo "$name_val" | grep -qE '^[a-z][a-z0-9-]{0,63}$'; then
        pass "$skill_name: name follows Agent Skills standard"
    else
        fail "$skill_name: name '$name_val' doesn't follow standard (lowercase, hyphens, 1-64 chars)"
    fi

    # Standard requires: description (1-1024 chars)
    desc_val=$(grep '^description:' "$skill_file" | head -1 | sed 's/^description:[[:space:]]*//')
    desc_len=${#desc_val}
    if [ "$desc_len" -ge 1 ] && [ "$desc_len" -le 1024 ]; then
        pass "$skill_name: description length OK ($desc_len chars)"
    else
        fail "$skill_name: description length $desc_len (must be 1-1024)"
    fi
done < <(find "$SKILLS_DIR" -name "SKILL.md" -not -path "*/profiles/*" 2>/dev/null)

# ── Harness Materialization ───────────────────────────

section "Harness Materialization"

if "$DOTFILES_DIR/scripts/sync-skills-harnesses.sh" --check >/dev/null 2>&1; then
    pass "Harness skill surfaces are in sync"
else
    fail "Harness skill surfaces have drift" "Run scripts/sync-skills-harnesses.sh"
fi

for harness_dir in .claude/skills .agents/skills .gemini/skills .opencode/skills .pi/agent/skills; do
    if [ -L "$DOTFILES_DIR/$harness_dir/dotfiles-sync" ]; then
        pass "$harness_dir has central dotfiles-sync link"
    else
        fail "$harness_dir missing central dotfiles-sync link"
    fi
done

# ── Summary ──────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ]
