#!/usr/bin/env bash
# test-ci-hooks.sh — Tests for CI hooks system.
# Run: bash scripts/ci-hooks/test-ci-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

ok() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}
fail() {
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
}

# --- detect-stack.sh tests ---
echo "=== detect-stack.sh ==="

# Node project
mkdir -p "$TMPDIR/node-proj"
echo '{"name":"test"}' >"$TMPDIR/node-proj/package.json"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/node-proj" | grep -q "node"; then
    ok "detects node from package.json"
else
    fail "detects node from package.json"
fi

# TypeScript project
mkdir -p "$TMPDIR/ts-proj"
echo '{"name":"test","devDependencies":{"typescript":"5.0"}}' >"$TMPDIR/ts-proj/package.json"
echo '{}' >"$TMPDIR/ts-proj/tsconfig.json"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/ts-proj" | grep -q "typescript"; then
    ok "detects typescript from tsconfig.json"
else
    fail "detects typescript from tsconfig.json"
fi

# Python project
mkdir -p "$TMPDIR/py-proj"
echo '[project]' >"$TMPDIR/py-proj/pyproject.toml"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/py-proj" | grep -q "python"; then
    ok "detects python from pyproject.toml"
else
    fail "detects python from pyproject.toml"
fi

# Go project
mkdir -p "$TMPDIR/go-proj"
echo 'module example.com/test' >"$TMPDIR/go-proj/go.mod"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/go-proj" | grep -q "go"; then
    ok "detects go from go.mod"
else
    fail "detects go from go.mod"
fi

# Rust project
mkdir -p "$TMPDIR/rust-proj"
echo '[package]' >"$TMPDIR/rust-proj/Cargo.toml"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/rust-proj" | grep -q "rust"; then
    ok "detects rust from Cargo.toml"
else
    fail "detects rust from Cargo.toml"
fi

# Terraform project
mkdir -p "$TMPDIR/tf-proj"
echo 'resource "aws_instance" "test" {}' >"$TMPDIR/tf-proj/main.tf"
if "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/tf-proj" | grep -q "terraform"; then
    ok "detects terraform from .tf files"
else
    fail "detects terraform from .tf files"
fi

# Multi-stack project
mkdir -p "$TMPDIR/multi-proj/scripts"
echo '{"name":"test"}' >"$TMPDIR/multi-proj/package.json"
echo '{}' >"$TMPDIR/multi-proj/tsconfig.json"
echo '' >"$TMPDIR/multi-proj/Dockerfile"
echo '#!/bin/bash' >"$TMPDIR/multi-proj/scripts/deploy.sh"
STACKS="$("$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/multi-proj")"
COUNT="$(echo "$STACKS" | wc -l | tr -d ' ')"
if [[ "$COUNT" -ge 3 ]]; then
    ok "detects multiple stacks ($COUNT found)"
else
    fail "detects multiple stacks (expected >=3, got $COUNT)"
fi

# Empty directory
mkdir -p "$TMPDIR/empty-proj"
if ! "$SCRIPT_DIR/detect-stack.sh" "$TMPDIR/empty-proj" 2>/dev/null; then
    ok "exits 1 for unknown stack"
else
    fail "exits 1 for unknown stack"
fi

# --- parse-config.sh tests ---
echo ""
echo "=== parse-config.sh ==="

# Create test config
cat >"$TMPDIR/test-config.yml" <<'EOF'
watch_paths:
  - ~/work
  - ~/projects

repos:
  ~/work/api:
    stack: python
    ci:
      - pytest -x
      - mypy src/

defaults:
  python:
    - pytest
    - ruff check .
  go:
    - go vet ./...
    - go test ./...

settings:
  check_on_commit: true
  timeout: 60
  fail_fast: false
  lint_on_save: true
EOF

export CI_CONFIG_FILE="$TMPDIR/test-config.yml"
source "$SCRIPT_DIR/parse-config.sh"

if ci_config_load; then
    ok "loads config file"
else
    fail "loads config file"
fi

# Watch paths
PATHS="$(ci_config_watch_paths)"
if echo "$PATHS" | grep -q "$HOME/work" && echo "$PATHS" | grep -q "$HOME/projects"; then
    ok "parses watch_paths"
else
    fail "parses watch_paths"
fi

# Repo commands
REPO_CMDS="$(ci_config_repo_commands "$HOME/work/api")"
if echo "$REPO_CMDS" | grep -q "pytest -x" && echo "$REPO_CMDS" | grep -q "mypy src/"; then
    ok "parses per-repo ci commands"
else
    fail "parses per-repo ci commands"
fi

# Default commands
DEFAULT_CMDS="$(ci_config_default_commands "python")"
if echo "$DEFAULT_CMDS" | grep -q "pytest" && echo "$DEFAULT_CMDS" | grep -q "ruff check"; then
    ok "parses default commands for stack"
else
    fail "parses default commands for stack"
fi

# Settings
if [[ "$(ci_config_setting timeout 120)" == "60" ]]; then
    ok "reads timeout setting"
else
    fail "reads timeout setting"
fi

if [[ "$(ci_config_setting fail_fast true)" == "false" ]]; then
    ok "reads fail_fast setting"
else
    fail "reads fail_fast setting"
fi

if [[ "$(ci_config_setting nonexistent default_val)" == "default_val" ]]; then
    ok "returns default for missing setting"
else
    fail "returns default for missing setting"
fi

# --- ci-local.sh tests ---
echo ""
echo "=== ci-local.sh ==="

# Create a fake "watched" project with a passing check
mkdir -p "$TMPDIR/work/passing-proj/scripts"
echo '#!/bin/bash' >"$TMPDIR/work/passing-proj/scripts/test.sh"

cat >"$TMPDIR/ci-config-watched.yml" <<EOF
watch_paths:
  - $TMPDIR/work

defaults:
  shell:
    - echo "lint passed"

settings:
  check_on_commit: true
  fail_fast: true
  timeout: 10
EOF

export CI_CONFIG_FILE="$TMPDIR/ci-config-watched.yml"

# Check --check-only for watched path
if "$SCRIPT_DIR/ci-local.sh" --check-only "$TMPDIR/work/passing-proj" >/dev/null 2>&1; then
    ok "check-only returns 0 for watched path"
else
    fail "check-only returns 0 for watched path"
fi

# Check --check-only for unwatched path
if ! "$SCRIPT_DIR/ci-local.sh" --check-only "$TMPDIR/empty-proj" >/dev/null 2>&1; then
    ok "check-only returns non-zero for unwatched path"
else
    fail "check-only returns non-zero for unwatched path"
fi

# Run passing CI
OUTPUT="$("$SCRIPT_DIR/ci-local.sh" "$TMPDIR/work/passing-proj" 2>&1)" || true
if echo "$OUTPUT" | grep -q "PASS"; then
    ok "reports passing CI"
else
    fail "reports passing CI (got: $OUTPUT)"
fi

# --- ci-precommit.sh hook tests ---
echo ""
echo "=== ci-precommit.sh hook ==="

# Non-git command should be allowed
RESULT="$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$SCRIPT_DIR/../../.claude/hooks/ci-precommit.sh" 2>/dev/null)" || true
if echo "$RESULT" | grep -q '"allow"'; then
    ok "allows non-git commands"
else
    fail "allows non-git commands (got: $RESULT)"
fi

# git commit in unwatched dir should be allowed
export CLAUDE_PROJECT_DIR="$TMPDIR/empty-proj"
RESULT="$(echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' | bash "$SCRIPT_DIR/../../.claude/hooks/ci-precommit.sh" 2>/dev/null)" || true
if echo "$RESULT" | grep -q '"allow"'; then
    ok "allows git commit in unwatched dir"
else
    fail "allows git commit in unwatched dir (got: $RESULT)"
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "All tests passed."
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
