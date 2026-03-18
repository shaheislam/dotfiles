#!/usr/bin/env bash
# Harness Engineering: Feature Verification
# Runs the harness feature list and updates pass/fail status.
# Inspired by Anthropic's "effective harnesses" feature_list.json pattern.
#
# Usage:
#   verify-harness.sh              # Run all checks, update JSON
#   verify-harness.sh --json       # Output results as JSON only
#   verify-harness.sh --summary    # One-line summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FEATURES_FILE="$SCRIPT_DIR/harness-features.json"

json_only=false
summary_only=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --json)
        json_only=true
        shift
        ;;
    --summary)
        summary_only=true
        shift
        ;;
    *) shift ;;
    esac
done

if [ ! -f "$FEATURES_FILE" ]; then
    echo "ERROR: harness-features.json not found at $FEATURES_FILE" >&2
    exit 1
fi

# Track results
declare -A RESULTS

# --- Feature: pre-commit-hooks ---
check_pre_commit() {
    local pass=true
    [ -f "$ROOT/.githooks/pre-commit" ] && [ -x "$ROOT/.githooks/pre-commit" ] || pass=false
    local hooks_path
    hooks_path=$(git -C "$ROOT" config core.hooksPath 2>/dev/null || echo "")
    [ "$hooks_path" = ".githooks" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: session-report ---
check_session_report() {
    local pass=true
    [ -f "$SCRIPT_DIR/session-report.sh" ] && [ -x "$SCRIPT_DIR/session-report.sh" ] || pass=false
    # Check if wired into SessionEnd
    if [ -f "$ROOT/.claude/settings.json" ]; then
        grep -q "session-report" "$ROOT/.claude/settings.json" 2>/dev/null || pass=false
    else
        pass=false
    fi
    $pass && echo "true" || echo "false"
}

# --- Feature: telemetry-query ---
check_telemetry_query() {
    local pass=true
    [ -f "$SCRIPT_DIR/query-telemetry.sh" ] && [ -x "$SCRIPT_DIR/query-telemetry.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: architecture-tests ---
check_architecture_tests() {
    local pass=true
    [ -f "$SCRIPT_DIR/test-architecture.sh" ] && [ -x "$SCRIPT_DIR/test-architecture.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: doc-validation ---
check_doc_validation() {
    local pass=true
    [ -f "$SCRIPT_DIR/validate-docs.sh" ] && [ -x "$SCRIPT_DIR/validate-docs.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: drift-detection ---
check_drift_detection() {
    local pass=true
    [ -f "$SCRIPT_DIR/detect-drift.sh" ] && [ -x "$SCRIPT_DIR/detect-drift.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: harness-init ---
check_harness_init() {
    local pass=true
    [ -f "$SCRIPT_DIR/init.sh" ] && [ -x "$SCRIPT_DIR/init.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: otel-observability ---
check_otel() {
    local pass=true
    local settings="$ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        grep -q "CLAUDE_CODE_ENABLE_TELEMETRY" "$settings" 2>/dev/null || pass=false
        grep -q "OTEL_METRICS_EXPORTER" "$settings" 2>/dev/null || pass=false
    else
        pass=false
    fi
    [ -f "$ROOT/scripts/otel/docker-compose.yml" ] || pass=false
    [ -f "$ROOT/.config/fish/functions/otel.fish" ] || pass=false
    $pass && echo "true" || echo "false"
}

# --- Feature: session-continuity ---
check_session_continuity() {
    local pass=true
    local settings="$ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        grep -q "bd prime" "$settings" 2>/dev/null || pass=false
        grep -q "work-detect" "$settings" 2>/dev/null || pass=false
    else
        pass=false
    fi
    $pass && echo "true" || echo "false"
}

# --- Feature: self-improvement ---
check_self_improvement() {
    local pass=true
    [ -f "$SCRIPT_DIR/suggest-improvements.sh" ] && [ -x "$SCRIPT_DIR/suggest-improvements.sh" ] || pass=false
    $pass && echo "true" || echo "false"
}

# Run all checks
RESULTS["pre-commit-hooks"]=$(check_pre_commit)
RESULTS["session-report"]=$(check_session_report)
RESULTS["telemetry-query"]=$(check_telemetry_query)
RESULTS["architecture-tests"]=$(check_architecture_tests)
RESULTS["doc-validation"]=$(check_doc_validation)
RESULTS["drift-detection"]=$(check_drift_detection)
RESULTS["harness-init"]=$(check_harness_init)
RESULTS["otel-observability"]=$(check_otel)
RESULTS["session-continuity"]=$(check_session_continuity)
RESULTS["self-improvement"]=$(check_self_improvement)

# Update the features JSON
if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq_filter='.'
    for id in "${!RESULTS[@]}"; do
        val="${RESULTS[$id]}"
        jq_filter="$jq_filter | map(if .id == \"$id\" then .passes = $val else . end)"
    done
    jq "$jq_filter" "$FEATURES_FILE" >"$tmp" && mv "$tmp" "$FEATURES_FILE"
fi

# Count results
total=${#RESULTS[@]}
passing=0
failing=0
for id in "${!RESULTS[@]}"; do
    if [ "${RESULTS[$id]}" = "true" ]; then
        passing=$((passing + 1))
    else
        failing=$((failing + 1))
    fi
done

# Output
if $summary_only; then
    echo "Harness: $passing/$total passing ($failing failing)"
    exit 0
fi

if $json_only; then
    jq -c '.' "$FEATURES_FILE"
    exit 0
fi

# Human-readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Harness Feature Verification ===${NC}"
echo ""

for id in $(jq -r '.[].id' "$FEATURES_FILE"); do
    desc=$(jq -r ".[] | select(.id == \"$id\") | .description" "$FEATURES_FILE")
    status="${RESULTS[$id]:-false}"
    if [ "$status" = "true" ]; then
        echo -e "  ${GREEN}PASS${NC} $id"
    else
        echo -e "  ${RED}FAIL${NC} $id"
    fi
    echo "       $desc"
done

echo ""
echo -e "${BLUE}Summary: $passing/$total passing${NC}"

if [ $failing -gt 0 ]; then
    echo ""
    echo "Failing features:"
    for id in "${!RESULTS[@]}"; do
        [ "${RESULTS[$id]}" = "false" ] && echo "  - $id"
    done
    exit 1
fi
