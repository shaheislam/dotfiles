import type { Plugin } from "@opencode-ai/plugin"

const GOAL_COMMAND = "goal"
const CONFIRM_PLAN_COMPLETION_COMMAND = "confirm-plan-completion"

const GoalCommandPlugin: Plugin = async () => ({
  config: async (input) => {
    input.command ??= {}
    input.command[GOAL_COMMAND] ??= {
      description: "Set or inspect the living plan goal and success criteria",
      template:
        "Use `.plan.md` as the only durable goal state. If `$ARGUMENTS` is empty, first re-read `.plan.md` from disk and do not rely on earlier context; then summarize the current `## Objective`, `## Success Criteria`, `## Current State`, and `## Next Steps`, then run `scripts/plan-validate-criteria.sh --summary` if it exists. If `$ARGUMENTS` is provided, update `.plan.md` so `## Objective` captures the requested goal and `## Success Criteria` contains concrete checks; add bash/sh fenced criteria when an objective test is practical. Then continue with the next step toward the goal. $ARGUMENTS",
    }
    input.command[CONFIRM_PLAN_COMPLETION_COMMAND] ??= {
      description: "Check the worktree plan before accepting that a task is done",
      template:
        "Review `.plan.md` in the current worktree and run `scripts/plan-validate-criteria.sh --summary` if it exists. If executable success criteria fail, written criteria remain incomplete, or unresolved next steps remain, continue the work or explain exactly what remains. Do not claim completion until the plan, validator output, and current repository state agree.",
    }
  },
})

export default GoalCommandPlugin
