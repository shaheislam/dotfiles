---
name: deploy-check
description: Run pre-flight validation before shipping changes, using the repo's existing verification and release workflows.
argument-hint: "[--quick] [--no-commit]"
---

# Deploy Check

Compatibility wrapper for setups that expect `/deploy-check`.

In this dotfiles repo, deploy-style checking means validating configuration integrity before commit or push.

## What to run

1. Run targeted validation with `/verify`.
2. If the work is ready to land, use `/ship` for the full release workflow.
3. If validation fails, route to `/fix`.

## Mapping

- Pre-flight validation -> `/verify`
- Full release readiness -> `/ship`
- Repair failures -> `/fix`
