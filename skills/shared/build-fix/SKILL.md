---
name: build-fix
description: Diagnose and repair failing checks, scripts, or setup steps using the repo's fix workflow.
argument-hint: "[failure text] [--category CAT]"
---

# Build Fix

Compatibility wrapper for setups that expect `/build-fix`.

Use this when validation, setup, or automation is failing and you want the existing dotfiles repair path.

## Mapping

- Dotfiles health and repair -> `/fix $ARGUMENTS`
- Release-blocking validation after repair -> `/verify`
