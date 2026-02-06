#!/usr/bin/env bash
# test-claude-autologin.sh
# Smoke test for Claude Code devcontainer auto-login feature.
#
# Tests:
# 1. Export script extracts credentials from Keychain
# 2. Exported file is valid JSON with expected structure
# 3. Import script can read and copy credentials
# 4. Permissions are restrictive (600)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_INSTANCE="test-autologin-$$"
TEST_DIR="${HOME}/.devcontainer/instances/${TEST_INSTANCE}/env"
PASS=0
FAIL=0

cleanup() {
    rm -rf "${HOME}/.devcontainer/instances/${TEST_INSTANCE}"
}
trap cleanup EXIT

print_result() {
    if [[ $1 -eq 0 ]]; then
        echo "  PASS: $2"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $2"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Claude Code Auto-Login Smoke Test ==="
echo ""

# Test 1: Export script runs without error
echo "Test 1: Export credentials from Keychain"
"${SCRIPT_DIR}/export-claude-credentials.sh" "${TEST_INSTANCE}" >/dev/null 2>&1
print_result $? "Export script completed"

# Test 2: Exported file exists
echo "Test 2: Credential file exists"
if test -f "${TEST_DIR}/.claude-credentials.json"; then
    print_result 0 "File exists at ${TEST_DIR}/.claude-credentials.json"
else
    print_result 1 "File exists at ${TEST_DIR}/.claude-credentials.json"
fi

# Test 3: File has correct permissions
echo "Test 3: File permissions"
PERMS=$(/usr/bin/stat -f "%OLp" "${TEST_DIR}/.claude-credentials.json" 2>/dev/null || stat -c "%a" "${TEST_DIR}/.claude-credentials.json" 2>/dev/null || echo "unknown")
if [[ "${PERMS}" = "600" ]]; then
    print_result 0 "Permissions are 600 (got: ${PERMS})"
else
    print_result 1 "Permissions are 600 (got: ${PERMS})"
fi

# Test 4: File is valid JSON
echo "Test 4: Valid JSON"
if python3 -c "import json; json.load(open('${TEST_DIR}/.claude-credentials.json'))" 2>/dev/null; then
    print_result 0 "File contains valid JSON"
else
    print_result 1 "File contains valid JSON"
fi

# Test 5: JSON has expected structure (claudeAiOauth key)
echo "Test 5: Expected credential structure"
if python3 -c "
import json
d = json.load(open('${TEST_DIR}/.claude-credentials.json'))
assert 'claudeAiOauth' in d, 'Missing claudeAiOauth key'
oauth = d['claudeAiOauth']
assert 'accessToken' in oauth, 'Missing accessToken'
assert 'refreshToken' in oauth, 'Missing refreshToken'
" 2>/dev/null; then
    print_result 0 "Contains claudeAiOauth with accessToken and refreshToken"
else
    print_result 1 "Contains claudeAiOauth with accessToken and refreshToken"
fi

# Test 6: Import script (simulated - test the logic without a container)
echo "Test 6: Import script validation"
CLAUDE_TEST_DIR=$(mktemp -d)
bash -c "
    SOURCE_FILE='${TEST_DIR}/.claude-credentials.json'
    TARGET_FILE='${CLAUDE_TEST_DIR}/.credentials.json'
    if [[ -f \"\${SOURCE_FILE}\" ]]; then
        cp \"\${SOURCE_FILE}\" \"\${TARGET_FILE}\"
        chmod 600 \"\${TARGET_FILE}\"
    fi
"
if test -f "${CLAUDE_TEST_DIR}/.credentials.json"; then
    print_result 0 "Import copies credentials to target directory"
else
    print_result 1 "Import copies credentials to target directory"
fi
rm -rf "${CLAUDE_TEST_DIR}"

# Summary
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
