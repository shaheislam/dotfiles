---
name: audit
description: Audit the current setup or codebase using the repo's existing review, security, and context-audit workflows.
argument-hint: "[--focus AREA] [--save PATH]"
---

# Audit

Compatibility wrapper for setups that expect `/audit`.

## Mapping

- Broad review readiness audit -> `/autoplan`
- Security audit -> `/security-audit`
- Context or vault quality audit -> `/context-health`
- External comparison audit -> `/gap-analysis`
