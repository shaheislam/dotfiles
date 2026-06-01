// OpenCode plugin: expose session metadata to shell commands.
// Tmux window colors are pane-local and owned by scripts/opencode/tmux-open.sh.
import type { Plugin } from "@opencode-ai/plugin"

export const SessionEnvPlugin: Plugin = async () => {
  let currentSessionID: string | null = null
  let currentModel: string | null = null

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          const session = (event as any).properties?.info
          if (!session?.id) break
          currentSessionID = session.id
          break
        }

        case "message.updated": {
          const msg = (event as any).properties?.info
          if (msg?.role === "assistant" && msg?.modelID) {
            currentModel = msg.modelID
          }
          break
        }

        case "session.deleted": {
          currentSessionID = null
          currentModel = null
          break
        }

        case "server.instance.disposed": {
          // OpenCode can dispose transient server instances while the attached
          // TUI is still alive. Session metadata is cleared only on deletion.
          break
        }
      }
    },
    "shell.env": async (input, output) => {
      const sessionID = input.sessionID ?? currentSessionID
      if (sessionID) {
        currentSessionID = sessionID
        output.env.OPENCODE_SESSION_ID = sessionID
      }
      if (currentModel) {
        output.env.OPENCODE_MODEL = currentModel
      }
    },
  }
}

export default SessionEnvPlugin
