#!/usr/bin/env bash
#
# test-rules.sh - Validate AI Gateway rule quality
#
# Tests that semgrep rules match expected patterns and that
# agent_guidance metadata is present and well-formed.
#
# Usage:
#   test-rules.sh                 # Run all tests
#   test-rules.sh --rule-schema   # Validate rule schema only
#   test-rules.sh --match-tests   # Run pattern match tests only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/semgrep-agent-rules.yaml"
RESULTS_FILE=$(mktemp)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo "PASS" >>"$RESULTS_FILE"
    echo -e "  ${GREEN}PASS${NC} $1"
}
fail() {
    echo "FAIL" >>"$RESULTS_FILE"
    echo -e "  ${RED}FAIL${NC} $1"
}
skip() {
    echo "SKIP" >>"$RESULTS_FILE"
    echo -e "  ${YELLOW}SKIP${NC} $1"
}

# ─── Schema Validation ──────────────────────────

test_rule_schema() {
    echo "Rule Schema Validation"
    echo "======================"

    if [[ ! -f "$RULES_FILE" ]]; then
        fail "Rules file not found: $RULES_FILE"
        return
    fi

    # Check YAML is valid
    if ! python3 -c "import yaml; yaml.safe_load(open('$RULES_FILE'))" 2>/dev/null; then
        fail "YAML syntax invalid"
        return
    fi
    pass "YAML syntax valid"

    # Check each rule has required fields
    local rule_count
    rule_count=$(python3 -c "
import yaml
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)
print(len(data.get('rules', [])))
")
    pass "Found $rule_count rules"

    # Validate each rule has governance metadata
    local schema_errors
    schema_errors=$(python3 -c "
import yaml, sys
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)

errors = []
for i, rule in enumerate(data.get('rules', [])):
    rid = rule.get('id', f'rule-{i}')
    meta = rule.get('metadata', {})

    if 'confidence' not in meta:
        errors.append(f'{rid}: missing metadata.confidence')
    elif meta['confidence'] not in ('high', 'medium', 'low'):
        errors.append(f'{rid}: confidence must be high/medium/low, got {meta[\"confidence\"]}')

    if 'version' not in meta:
        errors.append(f'{rid}: missing metadata.version')

    if 'agent_guidance' not in meta:
        errors.append(f'{rid}: missing metadata.agent_guidance')
    elif len(meta['agent_guidance'].strip()) < 20:
        errors.append(f'{rid}: agent_guidance too short (< 20 chars)')

    sev = rule.get('severity', '')
    if sev not in ('ERROR', 'WARNING', 'INFO'):
        errors.append(f'{rid}: invalid severity \"{sev}\"')

for e in errors:
    print(e)
sys.exit(0)
" 2>&1)

    if [[ -z "$schema_errors" ]]; then
        pass "All rules have required governance metadata (confidence, version, agent_guidance)"
    else
        while IFS= read -r line; do
            fail "$line"
        done <<<"$schema_errors"
    fi

    # Validate no duplicate rule IDs
    local dup_count
    dup_count=$(python3 -c "
import yaml
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)
ids = [r['id'] for r in data.get('rules', [])]
dups = [x for x in ids if ids.count(x) > 1]
print(len(set(dups)))
")
    if [[ "$dup_count" == "0" ]]; then
        pass "No duplicate rule IDs"
    else
        fail "$dup_count duplicate rule IDs found"
    fi

    # Report confidence distribution
    local dist
    dist=$(python3 -c "
import yaml
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)
conf = [r.get('metadata', {}).get('confidence', 'unknown') for r in data.get('rules', [])]
print(f'high={conf.count(\"high\")} medium={conf.count(\"medium\")} low={conf.count(\"low\")}')
")
    pass "Confidence distribution: $dist"
}

# ─── Pattern Match Tests ─────────────────────────

test_pattern_matches() {
    echo ""
    echo "Pattern Match Tests"
    echo "==================="

    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not available (install or fix pydantic)"
        return
    fi

    # Verify semgrep actually works (catches broken installs)
    if ! semgrep --version >/dev/null 2>&1; then
        skip "semgrep installed but broken (likely pydantic issue)"
        return
    fi

    # Test: python bare except
    local tmp
    tmp=$(mktemp /tmp/test_rule_XXXX.py)
    printf 'try:\n    x = 1\nexcept:\n    pass\n' >"$tmp"
    if semgrep scan --config "$RULES_FILE" --json --quiet "$tmp" 2>/dev/null | jq -e '.results | length > 0' >/dev/null 2>&1; then
        pass "python-bare-except matches bare except"
    else
        fail "python-bare-except did not match bare except"
    fi
    rm -f "$tmp"

    # Test: python subprocess shell=True
    tmp=$(mktemp /tmp/test_rule_XXXX.py)
    printf 'import subprocess\nsubprocess.run("ls -la", shell=True)\n' >"$tmp"
    if semgrep scan --config "$RULES_FILE" --json --quiet "$tmp" 2>/dev/null | jq -e '.results | length > 0' >/dev/null 2>&1; then
        pass "python-subprocess-shell-true matches shell=True"
    else
        fail "python-subprocess-shell-true did not match"
    fi
    rm -f "$tmp"

    # Negative test: safe code should NOT match security rules
    tmp=$(mktemp /tmp/test_rule_XXXX.py)
    printf 'import subprocess\nsubprocess.run(["ls", "-la"])\n' >"$tmp"
    if semgrep scan --config "$RULES_FILE" --json --quiet "$tmp" 2>/dev/null | jq -e '[.results[] | select(.check_id | test("subprocess"))] | length == 0' >/dev/null 2>&1; then
        pass "python-subprocess-shell-true does NOT match safe subprocess call"
    else
        fail "python-subprocess-shell-true false positive on safe code"
    fi
    rm -f "$tmp"
}

# ─── Guidance Quality Checks ────────────────────

test_guidance_quality() {
    echo ""
    echo "Guidance Quality Checks"
    echo "======================="

    local issues
    issues=$(python3 -c "
import yaml, sys
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)

issues = []
for rule in data.get('rules', []):
    rid = rule['id']
    meta = rule.get('metadata', {})
    guidance = meta.get('agent_guidance', '')

    if '/Users/' in guidance or '/home/' in guidance:
        issues.append(f'{rid}: guidance contains absolute paths')

    for term in ['claude', 'chatgpt', 'copilot', 'cursor']:
        if term.lower() in guidance.lower():
            issues.append(f'{rid}: guidance references specific AI tool \"{term}\"')

    if meta.get('confidence') == 'high' and not any(kw in guidance for kw in ['Replace', 'Add ', 'Use ', 'Wrap', 'Move']):
        issues.append(f'{rid}: high-confidence rule lacks concrete fix verb')

for issue in issues:
    print(issue)
" 2>&1)

    if [[ -z "$issues" ]]; then
        pass "All guidance passes quality checks (no absolute paths, no AI tool refs, high-confidence has fix verbs)"
    else
        while IFS= read -r line; do
            fail "$line"
        done <<<"$issues"
    fi
}

# ─── Main ────────────────────────────────────────

MODE="${1:-all}"

case "$MODE" in
--rule-schema) test_rule_schema ;;
--match-tests) test_pattern_matches ;;
*)
    test_rule_schema
    test_pattern_matches
    test_guidance_quality
    ;;
esac

echo ""
PASSED=$(grep -c '^PASS$' "$RESULTS_FILE" || true)
FAILED=$(grep -c '^FAIL$' "$RESULTS_FILE" || true)
SKIPPED=$(grep -c '^SKIP$' "$RESULTS_FILE" || true)
rm -f "$RESULTS_FILE"

echo "Results: $PASSED passed, $FAILED failed, $SKIPPED skipped"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
