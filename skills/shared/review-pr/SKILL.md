---
name: review-pr
description: Review the current branch or pull request using the repo's PR review workflows and plugins.
argument-hint: "[PR_NUMBER|BRANCH] [--focus AREA]"
---

# Review PR

Compatibility wrapper for setups that expect `/review-pr`.

## Preferred workflow

1. If a PR already exists, use the installed review tooling first.
2. Prefer `/code-review` when available for broad PR review.
3. For deeper structured analysis, use `/autoplan` or `/security-audit --focus ...` depending on the request.

## Mapping

- `/review-pr` -> `/code-review`
- Deep multi-angle review -> `/autoplan`
- Security-focused review -> `/security-audit`
