---
description: Check the worktree plan before accepting that a task is done.
---

Review `.plan.md` in the current worktree and run `scripts/plan-validate-criteria.sh --summary` if it exists. If executable success criteria fail, written criteria remain incomplete, or unresolved next steps remain, continue the work or explain exactly what remains. Do not claim completion until the plan, validator output, and current repository state agree.
