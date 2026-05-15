import type { Plugin } from "@opencode-ai/plugin"

const FORK_COMMAND = "fork"
const TUI_FORK_COMMAND = "session_fork"

const ForkCommandPlugin: Plugin = async ({ client, directory }) => ({
  config: async (input) => {
    input.command ??= {}
    input.command[FORK_COMMAND] ??= {
      description: "Fork the current OpenCode session in this worktree",
      template: "Fork the current OpenCode session in this worktree.",
    }
  },
  "command.execute.before": async (input) => {
    if (input.command !== FORK_COMMAND) return

    await client.tui.executeCommand({
      query: { directory },
      body: { command: TUI_FORK_COMMAND },
    })

    throw new Error("Command handled by OpenCode fork command plugin")
  },
})

export default ForkCommandPlugin
