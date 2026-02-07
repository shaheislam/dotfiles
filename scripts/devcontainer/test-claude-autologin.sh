#!/usr/bin/env bash
# test-claude-autologin.sh
# Smoke test for Claude Code devcontainer auto-login feature.
#
# Tests:
# 1. Export script creates and exports credentials
# 2. Exported file is valid JSON with expected structure
# 3. Idempotency: second export is a no-op
# 4. --force flag overwrites existing credentials
# 5. Permissions are correct (600 file)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${HOME}/.claude/.credentials.json"
PASS=0
FAIL=0

# Back up existing credentials if present
BACKUP=""
if [[ -f "${CRED_FILE}" ]]; then
    BACKUP=$(mktemp)
    cp "${CRED_FILE}" "${BACKUP}"
fi

cleanup() {
    # Restore original credentials if we backed them up
    if [[ -n "${BACKUP}" ]] && [[ -f "${BACKUP}" ]]; then
        cp "${BACKUP}" "${CRED_FILE}"
        chmod 600 "${CRED_FILE}"
        rm -f "${BACKUP}"
    fi
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

# Remove existing credentials so we test a fresh export
rm -f "${CRED_FILE}"

# Test 1: Export script runs without error
echo "Test 1: Export credentials from Keychain"
"${SCRIPT_DIR}/export-claude-credentials.sh" --force >/dev/null 2>&1
print_result $? "Export script completed"

# Test 2: Credential file exists with correct permissions
echo "Test 2: Credential file permissions"
if test -f "${CRED_FILE}"; then
    FILE_PERMS=$(/usr/bin/stat -f "%OLp" "${CRED_FILE}" 2>/dev/null || stat -c "%a" "${CRED_FILE}" 2>/dev/null || echo "unknown")
    if [[ "${FILE_PERMS}" = "600" ]]; then
        print_result 0 "File permissions are 600 (got: ${FILE_PERMS})"
    else
        print_result 1 "File permissions are 600 (got: ${FILE_PERMS})"
    fi
else
    print_result 1 "Credential file exists"
fi

# Test 3: File is valid JSON
echo "Test 3: Valid JSON"
if python3 -c "import json; json.load(open('${CRED_FILE}'))" 2>/dev/null; then
    print_result 0 "File contains valid JSON"
else
    print_result 1 "File contains valid JSON"
fi

# Test 4: JSON has expected structure (claudeAiOauth key)
echo "Test 4: Expected credential structure"
if python3 -c "
import json
d = json.load(open('${CRED_FILE}'))
assert 'claudeAiOauth' in d, 'Missing claudeAiOauth key'
oauth = d['claudeAiOauth']
assert 'accessToken' in oauth, 'Missing accessToken'
assert 'refreshToken' in oauth, 'Missing refreshToken'
" 2>/dev/null; then
    print_result 0 "Contains claudeAiOauth with accessToken and refreshToken"
else
    print_result 1 "Contains claudeAiOauth with accessToken and refreshToken"
fi

# Test 5: Idempotency - second export is a no-op
echo "Test 5: Idempotency (second export is no-op)"
OUTPUT=$("${SCRIPT_DIR}/export-claude-credentials.sh" 2>&1)
if echo "${OUTPUT}" | grep -q "already exist"; then
    print_result 0 "Second export skipped (credentials already exist)"
else
    print_result 1 "Second export skipped (expected 'already exist' message, got: ${OUTPUT})"
fi

# Test 6: --force flag overwrites existing credentials
echo "Test 6: --force flag overwrites"
OUTPUT=$("${SCRIPT_DIR}/export-claude-credentials.sh" --force 2>&1)
if echo "${OUTPUT}" | grep -q "exported"; then
    print_result 0 "--force flag triggers fresh export"
else
    print_result 1 "--force flag triggers fresh export (got: ${OUTPUT})"
fi

# Summary
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
