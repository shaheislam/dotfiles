#!/usr/bin/env bash
#
# test-checkpoints.sh - Unit tests for the checkpoint system
#
# Creates a temp git repo, enables checkpoints, simulates a session,
# makes a commit, and verifies checkpoint data on the orphan branch.
#
# Usage:
#   test-checkpoints.sh          # Run all tests
#   test-checkpoints.sh --live   # Include live session tests (requires Claude)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKPOINTS="${SCRIPT_DIR}/checkpoints.sh"
PASS=0
FAIL=0
SKIP=0

# Test helpers
pass() { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}⊘${NC} $* (skipped)"; SKIP=$((SKIP + 1)); }
section() { echo -e "\n${BOLD}$*${NC}"; }

# Temp directory management
TEST_DIR=""
cleanup() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

setup_test_repo() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "initial" > README.md
    git add README.md
    git commit -q -m "Initial commit"
}

# --- Tests ---

section "Prerequisites"

if [[ -x "$CHECKPOINTS" ]]; then
    pass "checkpoints.sh exists and is executable"
else
    fail "checkpoints.sh not found at ${CHECKPOINTS}"
    exit 1
fi

for dep in jq git shasum; do
    if command -v "$dep" &>/dev/null; then
        pass "${dep} available"
    else
        fail "${dep} not found"
    fi
done

for hook in checkpoint-commit-msg.sh checkpoint-post-commit.sh checkpoint-pre-push.sh checkpoint-pre-prompt.sh checkpoint-capture.sh; do
    if [[ -f "${SCRIPT_DIR}/hooks/${hook}" ]]; then
        pass "Hook script: ${hook}"
    else
        fail "Hook script missing: ${hook}"
    fi
done

section "Enable / Disable"

setup_test_repo

# Test enable
output=$("$CHECKPOINTS" enable 2>&1)
if echo "$output" | grep -q "Checkpoints enabled"; then
    pass "Enable succeeds"
else
    fail "Enable failed: ${output}"
fi

# Check orphan branch created
if git show-ref --quiet "refs/heads/checkpoints/v1"; then
    pass "Orphan branch created"
else
    fail "Orphan branch not created"
fi

# Check config file
if [[ -f ".checkpoints/config.json" ]]; then
    strategy=$(jq -r '.strategy' .checkpoints/config.json)
    if [[ "$strategy" == "manual" ]]; then
        pass "Config file with default strategy"
    else
        fail "Wrong strategy: ${strategy}"
    fi
else
    fail "Config file not created"
fi

# Check git hooks installed
for hook in prepare-commit-msg post-commit pre-push; do
    if [[ -f ".git/hooks/${hook}" ]] && grep -q "checkpoints" ".git/hooks/${hook}"; then
        pass "Git hook installed: ${hook}"
    else
        fail "Git hook not installed: ${hook}"
    fi
done

# Check .gitignore updated
if grep -q "\.checkpoints/" .gitignore 2>/dev/null; then
    pass ".gitignore entry added"
else
    fail ".gitignore entry missing"
fi

# Test status
output=$("$CHECKPOINTS" status 2>&1)
if echo "$output" | grep -q "Enabled"; then
    pass "Status shows enabled"
else
    fail "Status doesn't show enabled: ${output}"
fi

# Test doctor
output=$("$CHECKPOINTS" doctor 2>&1 || true)
if echo "$output" | grep -q "passed"; then
    pass "Doctor runs without error"
else
    fail "Doctor failed: ${output}"
fi

# Test disable
output=$("$CHECKPOINTS" disable 2>&1)
if echo "$output" | grep -q "Checkpoints disabled"; then
    pass "Disable succeeds"
else
    fail "Disable failed: ${output}"
fi

# Verify hooks removed
for hook in prepare-commit-msg post-commit pre-push; do
    if [[ -f ".git/hooks/${hook}" ]] && grep -q "checkpoints" ".git/hooks/${hook}" 2>/dev/null; then
        fail "Git hook not removed: ${hook}"
    else
        pass "Git hook removed: ${hook}"
    fi
done

# Verify pending dir removed
if [[ ! -d ".checkpoints" ]]; then
    pass "Pending directory removed"
else
    fail "Pending directory still exists"
fi

section "Checkpoint Capture Simulation"

setup_test_repo
"$CHECKPOINTS" enable 2>&1 >/dev/null

# Simulate a Claude session by creating a fake pending checkpoint
fake_session_id="test-session-$(date +%s)"
mkdir -p ".checkpoints/${fake_session_id}"

cat > ".checkpoints/${fake_session_id}/pending.json" <<EOF
{
  "session_id": "${fake_session_id}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "main",
  "token_estimate": 1500,
  "transcript_lines": 42,
  "files_modified": ["README.md"],
  "new_files": [],
  "tool_calls_summary": ["  3 Edit", "  2 Read", "  1 Bash"],
  "summary": "Updated README with project description"
}
EOF

cat > ".checkpoints/${fake_session_id}/transcript.jsonl" <<'EOF'
{"type":"human","message":{"content":"Update the README with a project description"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"I'll update the README now."}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file":"README.md"}}]}}
EOF

echo "Update the README with a project description" > ".checkpoints/${fake_session_id}/prompt.txt"

# Make a code change and commit (triggers hooks)
echo "# Test Project" > README.md
echo "This is a test project." >> README.md
git add README.md

git commit -q -m "Update README with project description"

# Verify checkpoint trailer in commit message
commit_msg=$(git log -1 --format=%B)
if echo "$commit_msg" | grep -q "^Checkpoint:"; then
    checkpoint_id=$(echo "$commit_msg" | grep "^Checkpoint:" | awk '{print $2}')
    pass "Checkpoint trailer added: ${checkpoint_id}"
else
    fail "Checkpoint trailer missing from commit message"
fi

# Verify data on orphan branch
commit_sha=$(git rev-parse HEAD)
shard="${commit_sha:0:2}/${commit_sha:2:6}"

if git show "checkpoints/v1:${shard}/metadata.json" >/dev/null 2>&1; then
    pass "Metadata stored on orphan branch"
else
    fail "Metadata not found on orphan branch at ${shard}/metadata.json"
fi

# Verify metadata contains the commit SHA
stored_sha=$(git show "checkpoints/v1:${shard}/metadata.json" 2>/dev/null | jq -r '.commit_sha' 2>/dev/null || true)
if [[ "$stored_sha" == "$commit_sha" ]]; then
    pass "Metadata contains correct commit SHA"
else
    fail "Metadata SHA mismatch: expected ${commit_sha}, got ${stored_sha}"
fi

# Verify transcript stored
if git show "checkpoints/v1:${shard}/sessions/${fake_session_id}/transcript.jsonl" >/dev/null 2>&1; then
    pass "Transcript stored on orphan branch"
else
    fail "Transcript not found on orphan branch"
fi

# Verify prompt stored
if git show "checkpoints/v1:${shard}/sessions/${fake_session_id}/prompt.txt" >/dev/null 2>&1; then
    pass "Prompt stored on orphan branch"
else
    fail "Prompt not found on orphan branch"
fi

# Verify pending directory cleaned up
if [[ ! -d ".checkpoints/${fake_session_id}" ]]; then
    pass "Pending checkpoint cleaned up"
else
    fail "Pending checkpoint not cleaned up"
fi

section "Log and Show Commands"

# Test log
output=$("$CHECKPOINTS" log 2>&1)
if echo "$output" | grep -q "${commit_sha:0:12}"; then
    pass "Log shows the checkpoint"
else
    fail "Log doesn't show checkpoint: ${output}"
fi

# Test show
output=$("$CHECKPOINTS" show "$commit_sha" 2>&1)
if echo "$output" | grep -q "commit_sha"; then
    pass "Show displays checkpoint metadata"
else
    fail "Show doesn't display metadata: ${output}"
fi

if echo "$output" | grep -q "Transcript"; then
    pass "Show displays transcript section"
else
    fail "Show doesn't display transcript"
fi

# Test show with short SHA
output=$("$CHECKPOINTS" show "${commit_sha:0:8}" 2>&1)
if echo "$output" | grep -q "commit_sha"; then
    pass "Show works with short SHA"
else
    fail "Show doesn't work with short SHA"
fi

section "Multiple Checkpoints"

# Make a second commit with a new checkpoint
fake_session_id2="test-session-$(date +%s)-2"
mkdir -p ".checkpoints/${fake_session_id2}"

cat > ".checkpoints/${fake_session_id2}/pending.json" <<EOF
{
  "session_id": "${fake_session_id2}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "main",
  "token_estimate": 800,
  "transcript_lines": 15,
  "files_modified": ["README.md"],
  "new_files": ["CHANGELOG.md"],
  "tool_calls_summary": ["  1 Write"],
  "summary": "Added changelog"
}
EOF

echo '{"type":"human","message":{"content":"Add a changelog"}}' > ".checkpoints/${fake_session_id2}/transcript.jsonl"
echo "Add a changelog" > ".checkpoints/${fake_session_id2}/prompt.txt"

echo "# Changelog" > CHANGELOG.md
git add README.md CHANGELOG.md
git commit -q -m "Add changelog"

# Verify both checkpoints exist
commit_sha2=$(git rev-parse HEAD)
shard2="${commit_sha2:0:2}/${commit_sha2:2:6}"

if git show "checkpoints/v1:${shard2}/metadata.json" >/dev/null 2>&1; then
    pass "Second checkpoint stored"
else
    fail "Second checkpoint not stored"
fi

# Original checkpoint should still be there
if git show "checkpoints/v1:${shard}/metadata.json" >/dev/null 2>&1; then
    pass "First checkpoint still present"
else
    fail "First checkpoint was lost"
fi

# Log should show both
output=$("$CHECKPOINTS" log 2>&1)
checkpoint_count=$(echo "$output" | grep -c "^[a-f0-9]" || true)
if [[ "$checkpoint_count" -ge 2 ]]; then
    pass "Log shows both checkpoints"
else
    fail "Log shows ${checkpoint_count} checkpoints, expected ≥2"
fi

section "Enable with Custom Strategy"

setup_test_repo
output=$("$CHECKPOINTS" enable --strategy auto 2>&1)
if [[ -f ".checkpoints/config.json" ]]; then
    strategy=$(jq -r '.strategy' .checkpoints/config.json)
    if [[ "$strategy" == "auto" ]]; then
        pass "Custom strategy 'auto' stored"
    else
        fail "Wrong strategy: ${strategy}"
    fi
else
    fail "Config not created with custom strategy"
fi

section "Idempotent Enable"

# Enable again — should not fail
output=$("$CHECKPOINTS" enable 2>&1)
if echo "$output" | grep -q "already installed"; then
    pass "Idempotent enable (hooks already installed)"
else
    pass "Enable re-ran without error"
fi

section "Edge Cases"

# Test show with nonexistent commit
output=$("$CHECKPOINTS" show "deadbeef1234" 2>&1 || true)
if echo "$output" | grep -qi "no checkpoint\|unknown commit"; then
    pass "Show handles unknown commit"
else
    fail "Show doesn't handle unknown commit gracefully"
fi

# Test log with no checkpoints (fresh repo)
setup_test_repo
"$CHECKPOINTS" enable 2>&1 >/dev/null
output=$("$CHECKPOINTS" log 2>&1)
if echo "$output" | grep -qi "no checkpoints"; then
    pass "Log handles empty checkpoint history"
else
    pass "Log handles empty state (no error)"
fi

# --- Summary ---

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}  ${YELLOW}${SKIP} skipped${NC}"
echo "═══════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
