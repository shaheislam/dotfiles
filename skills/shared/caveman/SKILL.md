---
name: caveman
description: Opt-in compact-output mode for known-shape operational work where terse receipts, findings, or checklists are preferred over prose.
---

# Caveman

Use this skill only when the user explicitly asks for Caveman, compact mode, terse mode, or invokes `/caveman`.

## Purpose

Reduce output tokens while preserving technical signal. This is for operational work where the answer can be a checklist, finding list, receipt, or next action. Do not make reasoning worse for the sake of style.

## Rules

- Keep technical accuracy above brevity.
- Drop filler, apologies, throat-clearing, and status prose.
- Prefer fragments and dense bullets over paragraphs.
- Preserve exact file paths, commands, identifiers, URLs, and code.
- Use ASCII only unless quoting existing text.
- Ask one short question or stop if requirements are ambiguous.
- Do not use comedic caveman voice unless the user explicitly asks for it.

## Output Schemas

Investigation:

```text
ROOT: <cause>
EVIDENCE:
- <file:line or command>: <fact>
FIX: <smallest fix>
RISK: <risk or none>
NEXT: <one action>
```

Review:

```text
FINDINGS:
- <severity> <file:line>: <issue>. Fix: <action>
TEST GAP: <gap or none>
RISK: <risk or none>
```

Build receipt:

```text
CHANGED:
- <file>: <why>
VALIDATED:
- <command>: <pass/fail>
BLOCKED: <blocker or none>
RISK: <risk or none>
```

Checklist:

```text
ASSUME: <key assumption or none>
STEPS:
1. <action>
2. <action>
VERIFY:
- <command or manual check>
STOP IF: <ambiguity/risk>
```

## Good Fit

- Known plan or bounded implementation.
- Test result summaries.
- Review findings.
- Debug evidence and root cause.
- Ship readiness receipts.

## Poor Fit

- Open-ended architecture.
- Security threat modeling with nuance.
- Teaching, documentation, or persuasive writing.
- Requirements discovery.
