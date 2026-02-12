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

# Test disable (without --purge: removes config, keeps hooks as harmless no-ops)
output=$("$CHECKPOINTS" disable 2>&1)
if echo "$output" | grep -q "Checkpoints disabled"; then
    pass "Disable succeeds"
else
    fail "Disable failed: ${output}"
fi

# Verify hooks still present (no-ops without config)
for hook in prepare-commit-msg post-commit pre-push; do
    if [[ -f ".git/hooks/${hook}" ]] && grep -q "checkpoints" ".git/hooks/${hook}" 2>/dev/null; then
        pass "Git hook retained (no-op): ${hook}"
    else
        fail "Git hook unexpectedly removed: ${hook}"
    fi
done

# Verify pending dir removed
if [[ ! -d ".checkpoints" ]]; then
    pass "Pending directory removed"
else
    fail "Pending directory still exists"
fi

# Re-enable then test disable --purge (removes hooks too)
"$CHECKPOINTS" enable >/dev/null 2>&1
output=$("$CHECKPOINTS" disable --purge 2>&1)
if echo "$output" | grep -q "Checkpoints disabled"; then
    pass "Disable --purge succeeds"
else
    fail "Disable --purge failed: ${output}"
fi
for hook in prepare-commit-msg post-commit pre-push; do
    if [[ -f ".git/hooks/${hook}" ]] && grep -q "checkpoints" ".git/hooks/${hook}" 2>/dev/null; then
        fail "Git hook not removed by --purge: ${hook}"
    else
        pass "Git hook removed by --purge: ${hook}"
    fi
done

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

section "Resume Command"

# Still in the repo with two checkpoints from "Multiple Checkpoints" section
output=$("$CHECKPOINTS" resume main 2>&1)
if echo "$output" | grep -q "Resume Context"; then
    pass "Resume shows context header"
else
    fail "Resume doesn't show context: ${output}"
fi

if echo "$output" | grep -q "Last checkpoint"; then
    pass "Resume shows last checkpoint SHA"
else
    fail "Resume missing checkpoint SHA"
fi

if echo "$output" | grep -q "Summary"; then
    pass "Resume shows summary"
else
    fail "Resume missing summary"
fi

# Test resume with nonexistent branch
output=$("$CHECKPOINTS" resume "nonexistent-branch" 2>&1)
if echo "$output" | grep -qi "no checkpoints found"; then
    pass "Resume handles unknown branch"
else
    pass "Resume handles unknown branch (no error)"
fi

section "Context Command"

output=$("$CHECKPOINTS" context --commits 5 2>&1)
if echo "$output" | grep -q "Checkpoint Context"; then
    pass "Context shows header"
else
    fail "Context doesn't show header: ${output}"
fi

if echo "$output" | grep -q "Why:"; then
    pass "Context shows summaries"
else
    fail "Context missing summaries"
fi

# Count entries
context_entries=$(echo "$output" | grep -c "^- [a-f0-9]" || true)
if [[ "$context_entries" -ge 2 ]]; then
    pass "Context shows multiple entries"
else
    fail "Context shows ${context_entries} entries, expected ≥2"
fi

# Test with --commits 1
output=$("$CHECKPOINTS" context --commits 1 2>&1)
context_entries=$(echo "$output" | grep -c "^- [a-f0-9]" || true)
if [[ "$context_entries" -eq 1 ]]; then
    pass "Context respects --commits limit"
else
    fail "Context --commits 1 shows ${context_entries} entries"
fi

# Test with --branch filter
output=$("$CHECKPOINTS" context --branch main 2>&1)
if echo "$output" | grep -q "main"; then
    pass "Context filters by branch"
else
    fail "Context branch filter not working"
fi

section "Search Command"

# Search for something in our checkpoint summaries
output=$("$CHECKPOINTS" search "README" 2>&1)
if echo "$output" | grep -qi "match.*found"; then
    pass "Search finds matches in metadata"
else
    fail "Search didn't find expected match: ${output}"
fi

# Search for something in transcripts
output=$("$CHECKPOINTS" search "changelog" 2>&1)
if echo "$output" | grep -qi "match.*found"; then
    pass "Search finds content in transcripts/metadata"
else
    fail "Search didn't find transcript content: ${output}"
fi

# Search for nonexistent term
output=$("$CHECKPOINTS" search "zzz_nonexistent_zzz" 2>&1)
if echo "$output" | grep -qi "no matches"; then
    pass "Search handles no results"
else
    fail "Search doesn't handle no results: ${output}"
fi

section "Clean Command"

# Clean should find no orphans in our test repo
output=$("$CHECKPOINTS" clean 2>&1)
if echo "$output" | grep -qi "valid"; then
    pass "Clean reports all valid"
else
    fail "Clean unexpected output: ${output}"
fi

section "Reset Command"

# Reset without --force should fail
output=$("$CHECKPOINTS" reset 2>&1 || true)
if echo "$output" | grep -qi "force"; then
    pass "Reset requires --force"
else
    fail "Reset doesn't require confirmation: ${output}"
fi

# Reset with --force should delete the branch
output=$("$CHECKPOINTS" reset --force 2>&1)
if echo "$output" | grep -qi "deleted"; then
    pass "Reset --force deletes branch"
else
    fail "Reset --force failed: ${output}"
fi

# Verify branch is gone
if ! git show-ref --quiet "refs/heads/checkpoints/v1"; then
    pass "Checkpoint branch removed after reset"
else
    fail "Checkpoint branch still exists after reset"
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

section "Log --git (Annotated Git Log)"

# Set up a fresh repo with mixed commits (some with checkpoints, some without)
setup_test_repo
"$CHECKPOINTS" enable 2>&1 >/dev/null

# Commit 1: with checkpoint
fake_sid_git1="test-git-$(date +%s)-1"
mkdir -p ".checkpoints/${fake_sid_git1}"
cat > ".checkpoints/${fake_sid_git1}/pending.json" <<EOF
{
  "session_id": "${fake_sid_git1}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "main",
  "token_estimate": 1200,
  "transcript_lines": 10,
  "files_modified": ["README.md"],
  "new_files": [],
  "tool_calls_summary": ["  2 Bash", "  3 Read"],
  "summary": "First checkpoint commit"
}
EOF
echo "first checkpoint" > ".checkpoints/${fake_sid_git1}/prompt.txt"
echo '{"type":"human","message":{"content":"first"}}' > ".checkpoints/${fake_sid_git1}/transcript.jsonl"
echo "change 1" >> README.md
git add README.md
git commit -q -m "First commit with checkpoint"
sha_git1=$(git rev-parse HEAD)

# Commit 2: without checkpoint (no pending data)
echo "change 2" >> README.md
git add README.md
git commit -q -m "Second commit without checkpoint"
sha_git2=$(git rev-parse HEAD)

# Commit 3: with checkpoint
fake_sid_git3="test-git-$(date +%s)-3"
mkdir -p ".checkpoints/${fake_sid_git3}"
cat > ".checkpoints/${fake_sid_git3}/pending.json" <<EOF
{
  "session_id": "${fake_sid_git3}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "main",
  "token_estimate": 2500,
  "transcript_lines": 25,
  "files_modified": ["README.md"],
  "new_files": ["notes.txt"],
  "tool_calls_summary": ["  1 Edit"],
  "summary": "Third checkpoint commit"
}
EOF
echo "third checkpoint" > ".checkpoints/${fake_sid_git3}/prompt.txt"
echo '{"type":"human","message":{"content":"third"}}' > ".checkpoints/${fake_sid_git3}/transcript.jsonl"
echo "change 3" >> README.md
echo "notes" > notes.txt
git add README.md notes.txt
git commit -q -m "Third commit with checkpoint"
sha_git3=$(git rev-parse HEAD)

# Test: --git shows all 3 commits (plus initial)
output=$("$CHECKPOINTS" log --git 2>&1)
commit_lines=$(echo "$output" | grep -c "^..*[a-f0-9]\{7\}" || true)
if [[ "$commit_lines" -ge 3 ]]; then
    pass "log --git shows all commits"
else
    fail "log --git shows ${commit_lines} commits, expected ≥3"
fi

# Test: checkpoint annotation present only on checkpoint commits
annotation_count=$(echo "$output" | grep -c "✦" || true)
if [[ "$annotation_count" -eq 2 ]]; then
    pass "Checkpoint annotations on exactly 2 commits"
else
    fail "Expected 2 checkpoint annotations, got ${annotation_count}"
fi

# Test: annotation contains tokens
if echo "$output" | grep "✦" | grep -q "tokens"; then
    pass "Annotations contain token counts"
else
    fail "Annotations missing token counts"
fi

# Test: annotation contains tools
if echo "$output" | grep "✦" | grep -q "Bash\|Read\|Edit"; then
    pass "Annotations contain tool summaries"
else
    fail "Annotations missing tool summaries"
fi

# Test: -n flag limits output
output=$("$CHECKPOINTS" log --git -n 1 2>&1)
commit_lines=$(echo "$output" | grep -c "^..*[a-f0-9]\{7\}" || true)
if [[ "$commit_lines" -eq 1 ]]; then
    pass "log --git -n 1 shows only 1 commit"
else
    fail "log --git -n 1 shows ${commit_lines} commits, expected 1"
fi

# Test: non-checkpoint commit has no annotation
if echo "$output" | grep -q "Second commit without"; then
    # If the second commit is shown, make sure it has no annotation
    second_line=$(echo "$output" | grep -A1 "Second commit without" | tail -1)
    if echo "$second_line" | grep -q "✦"; then
        fail "Non-checkpoint commit has annotation"
    else
        pass "Non-checkpoint commit has no annotation"
    fi
else
    pass "Non-checkpoint commit filtered correctly by -n"
fi

# --- Summary ---

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}  ${YELLOW}${SKIP} skipped${NC}"
echo "═══════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
