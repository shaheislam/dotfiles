#!/usr/bin/env bash
# setup-ci-hooks.sh — Set up per-device CI hooks configuration.
# Creates ~/.config/claude-ci/config.yml from template if not present.
# Safe to run multiple times (idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/claude-ci"
CONFIG_FILE="$CONFIG_DIR/config.yml"
TEMPLATE="$SCRIPT_DIR/config.example.yml"

echo "Setting up Claude Code CI hooks..."

# Create config directory
mkdir -p "$CONFIG_DIR"

# Copy template if config doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    if [[ -f "$TEMPLATE" ]]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
        echo "Created $CONFIG_FILE from template"
        echo "Edit this file to configure CI checks for your repos on this device."
    else
        echo "Warning: template not found at $TEMPLATE"
        echo "Creating minimal config..."
        cat >"$CONFIG_FILE" <<'EOF'
watch_paths:
  - ~/work

defaults:
  node:
    - npm test 2>/dev/null || true
  typescript:
    - npx tsc --noEmit
  python:
    - python -m pytest -x --tb=short 2>/dev/null || true
  go:
    - go vet ./...
    - go test ./...
  rust:
    - cargo check
    - cargo test
  shell:
    - shellcheck scripts/*.sh 2>/dev/null || true

settings:
  check_on_commit: true
  check_on_push: true
  lint_on_save: false
  timeout: 120
  fail_fast: true
  inject_context: true
EOF
        echo "Created minimal $CONFIG_FILE"
    fi
else
    echo "$CONFIG_FILE already exists — skipping."
fi

# Auto-detect repos in ~/work and show what would be checked
if [[ -d "$HOME/work" ]]; then
    echo ""
    echo "Repos detected in ~/work:"
    for dir in "$HOME/work"/*/; do
        [[ ! -d "$dir/.git" ]] && continue
        stacks="$("$SCRIPT_DIR/detect-stack.sh" "$dir" 2>/dev/null)" || stacks="(unknown)"
        stacks="$(echo "$stacks" | tr '\n' ', ' | sed 's/,$//')"
        echo "  $(basename "$dir"): $stacks"
    done
    echo ""
    echo "Add per-repo overrides to $CONFIG_FILE if defaults don't fit."
fi

echo "Done. CI hooks are active for repos under ~/work."
