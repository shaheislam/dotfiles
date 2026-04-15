---
name: checkpoint
description: Save progress and make the current session resumable by updating the persistent plan and session state.
argument-hint: "[note]"
---

# Checkpoint

Compatibility wrapper for setups that expect `/checkpoint`.

## What to do

1. Update `.plan.md` with the latest progress, decisions, current state, and next steps.
2. Record any important dead ends under `## Failed Approaches`.
3. If you need recovery help from a prior interrupted session, use `/continue-claude-work`.
4. If you're finishing the session, pair this with `/handoff`.
