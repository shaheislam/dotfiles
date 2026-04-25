---
name: handoff
description: Capture the current session state, what changed, and what should happen next for the next session.
argument-hint: "[--save PATH] [--quiet]"
---

# Handoff

Compatibility wrapper for setups that expect `/handoff`.

## Preferred workflow

1. Update `.plan.md` with progress, current state, decisions, and next steps.
2. Use `/session-review $ARGUMENTS` to generate a concise session summary.
3. Capture the handoff boundary in Obsidian:
   ```bash
   obsidian-session-sync --reason handoff --force 2>&1 | tail -3
   ```
   Bypasses the 60s dedup window so the note exists for the next session even if Stop just fired.
4. If the goal is interrupted-session recovery rather than handoff output, use `/continue-claude-work`.

## Mapping

- Session summary / handoff -> `/session-review` + `obsidian-session-sync --reason handoff --force`
- Recover prior interrupted work -> `/continue-claude-work`
