---
name: warn-dangerous-bash
enabled: true
event: bash
conditions:
  - field: command
    operator: regex_match
    pattern: (rm\s+-rf|git\s+clean\s+-fdx|sudo\s+rm|dd\s+if=|mkfs)
---

⚠️ **Potentially destructive Bash command detected.**

- Double-check the target path and confirm you have backups before running destructive commands like `rm -rf`, `git clean -fdx`, raw disk writers, or filesystem formatters.
- Consider running a read-only dry run (e.g., `git clean -nfdx`) or scoping the path more narrowly if this is meant to operate within the repo.
- If you really intend to proceed, acknowledge the risk in your notes or bead comments so future readers know the data loss was intentional.
