# Scripts Agent Guide

Rules for `~/dotfiles/scripts`.

## Bash Style

- Scripts use Bash with `#!/usr/bin/env bash` and `set -euo pipefail` where practical.
- Quote variables and paths.
- Use snake_case function names.
- Never use `((var++))` with `set -e`; use `var=$((var + 1))`.
- Prefer shared helpers from `scripts/lib/` when an existing helper fits.

## Setup Script

- `scripts/setup.sh` is large and phase-based; read the relevant phase before editing.
- New CLI tools require `homebrew/Brewfile`, `scripts/setup.sh`, and shell PATH/config parity.
- Use `--dry-run` for setup changes when available.
- Do not install Homebrew packages directly from scripts; declare them in `homebrew/Brewfile`.

## Validation

- Run `bash -n <script>` for edited Bash scripts.
- Run `scripts/test-filter.sh setup-syntax` for setup-related changes.
- Run `scripts/test-filter.sh [group]` for targeted validation before broader suites.
- Use Docker tests under `scripts/docker/` for cross-platform changes when relevant.
