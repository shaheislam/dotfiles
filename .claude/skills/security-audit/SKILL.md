---
name: security-audit
description: Structured security audit using OWASP Top 10 and STRIDE threat modeling. Produces severity-rated findings with remediation guidance.
argument-hint: "[--focus AREA] [--severity MIN] [--save PATH]"
---

# Security Audit

Perform a structured security audit of the current codebase using industry-standard frameworks. Inspired by gstack's /cso skill.

## Arguments

- `$ARGUMENTS` - Optional:
  - `--focus AREA` — Narrow to a specific area (e.g., `auth`, `api`, `config`, `infra`)
  - `--severity MIN` — Only report findings at or above this level: `critical`, `high`, `medium`, `low` (default: `low`)
  - `--save PATH` — Write the full report to a file

## Execution

### 1. Understand the codebase

Before auditing, understand what we're working with:

```bash
# Language/framework detection
ls package.json pyproject.toml Cargo.toml go.mod Gemfile *.csproj 2>/dev/null

# Find entry points
find . -maxdepth 3 -name "*.env*" -o -name "*secret*" -o -name "*credential*" -o -name "*auth*" -o -name "*token*" 2>/dev/null | grep -v node_modules | grep -v .git

# Find config files
find . -maxdepth 3 -name "*.config.*" -o -name "*.conf" -o -name "*.yml" -o -name "*.yaml" -o -name "*.toml" 2>/dev/null | grep -v node_modules | grep -v .git | head -20
```

Read key files to understand the application's architecture, data flow, and trust boundaries.

### 2. OWASP Top 10 Checklist

Systematically check each category. For each, search the codebase for relevant patterns:

| # | Category | What to Look For |
|---|----------|-----------------|
| A01 | Broken Access Control | Missing auth checks, IDOR, path traversal, CORS misconfig |
| A02 | Cryptographic Failures | Hardcoded secrets, weak hashing, plaintext storage, missing TLS |
| A03 | Injection | SQL injection, command injection, XSS, template injection |
| A04 | Insecure Design | Missing rate limiting, no input validation at boundaries |
| A05 | Security Misconfiguration | Debug mode in prod, default credentials, verbose errors |
| A06 | Vulnerable Components | Outdated dependencies, known CVEs |
| A07 | Auth Failures | Weak password rules, missing MFA, session fixation |
| A08 | Data Integrity | Unsigned updates, untrusted deserialization, CI/CD tampering |
| A09 | Logging Failures | Missing security logs, sensitive data in logs |
| A10 | SSRF | Unvalidated URLs, internal service access |

For each category:
1. Search for relevant code patterns using Grep
2. Read suspicious files
3. Classify findings by severity

### 3. STRIDE Threat Model

For the key components identified in step 1, analyze each STRIDE category:

| Threat | Question | Example |
|--------|----------|---------|
| **S**poofing | Can an attacker pretend to be someone else? | Auth bypass, token forgery |
| **T**ampering | Can data be modified in transit or at rest? | Unsigned payloads, writable configs |
| **R**epudiation | Can actions be denied after the fact? | Missing audit logs |
| **I**nformation Disclosure | Can sensitive data leak? | Error messages, debug endpoints |
| **D**enial of Service | Can the system be overwhelmed? | No rate limiting, resource exhaustion |
| **E**levation of Privilege | Can a user gain higher access? | Privilege escalation, role confusion |

### 4. Classify findings

For each finding, assign:

| Field | Values |
|-------|--------|
| **Severity** | Critical / High / Medium / Low |
| **Category** | OWASP code (A01-A10) or STRIDE letter (S/T/R/I/D/E) |
| **File** | Affected file path and line numbers |
| **Description** | What the vulnerability is |
| **Impact** | What an attacker could do |
| **Remediation** | How to fix it, with code example |
| **Confidence** | Confirmed / Likely / Possible |

### 5. Generate report

```markdown
# Security Audit Report

**Scope:** [repo name, focus area if specified]
**Date:** [today]
**Framework:** OWASP Top 10 (2021) + STRIDE

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High     | N |
| Medium   | N |
| Low      | N |

## Critical Findings

### [FINDING-1] [Title]
- **Severity:** Critical
- **Category:** A02 - Cryptographic Failures
- **Location:** `path/to/file.ts:42`
- **Description:** [what's wrong]
- **Impact:** [what an attacker could do]
- **Remediation:** [how to fix]
- **Confidence:** Confirmed

[... more findings ...]

## STRIDE Analysis

| Component | S | T | R | I | D | E |
|-----------|---|---|---|---|---|---|
| [Component 1] | OK/RISK | ... | ... | ... | ... | ... |
| [Component 2] | ... | ... | ... | ... | ... | ... |

## Recommendations

1. [Priority-ordered remediation steps]
2. ...

## Clean Areas

[Explicitly note areas that passed review — this builds confidence]
```

### 6. Output

- Display the report
- If `--save PATH` was provided, write it to the file
- If `--severity MIN` was specified, filter to only show findings at or above that level
