---
name: verify
description: Run the relevant validation and test commands for the current dotfiles change before commit or release.
argument-hint: "[--quick] [--group NAME]"
---

# Verify

Compatibility wrapper for setups that expect `/verify`.

## Verification order

1. For focused checks, prefer `scripts/test-filter.sh --list` and then run the relevant group.
2. For quick repo validation, run `scripts/smoke-test.sh`.
3. For Claude-specific changes, run `scripts/test-claude-config.sh`.
4. For broader macOS validation, run `scripts/validate-macos.sh`.

If verification fails, route to `/fix`.
