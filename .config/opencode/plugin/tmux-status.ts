// OpenCode plugin: push session metadata into tmux environment variables.
// tmux status bar segments can read these via #{E:OPENCODE_SESSION_ID}, etc.
// Requires tmux to be running — degrades silently if not.
import type { Plugin } from "@opencode-ai/plugin"

export const TmuxStatusPlugin: Plugin = async ({ $, directory }) => {
  let currentSessionID: string | null = null
  let currentModel: string | null = null

  async function setTmuxEnv(key: string, value: string) {
    try {
      await $`tmux set-environment -g ${key} ${value}`.quiet().nothrow()
    } catch {
      // tmux not running or not in a tmux session — ignore
    }
  }

  async function unsetTmuxEnv(key: string) {
    try {
      await $`tmux set-environment -g -u ${key}`.quiet().nothrow()
    } catch {
      // ignore
    }
  }

  function setTmuxEnvSync(key: string, value: string) {
    try {
      Bun.spawnSync(["tmux", "set-environment", "-g", key, value], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
    } catch {
      // ignore
    }
  }

  function unsetTmuxEnvSync(key: string) {
    try {
      Bun.spawnSync(["tmux", "set-environment", "-g", "-u", key], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
    } catch {
      // ignore
    }
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          const session = (event as any).properties?.info
          if (!session?.id) break
          currentSessionID = session.id
          await setTmuxEnv("OPENCODE_SESSION_ID", session.id)
          await setTmuxEnv("OPENCODE_STATUS", "active")
          await setTmuxEnv("OPENCODE_DIR", directory)
          break
        }

        case "message.updated": {
          const msg = (event as any).properties?.info
          if (msg?.role === "assistant" && msg?.modelID) {
            currentModel = msg.modelID
            await setTmuxEnv("OPENCODE_MODEL", msg.modelID)
          }
          break
        }

        case "session.status": {
          const props = (event as any).properties
          const statusType = props?.status?.type
          if (statusType) {
            setTmuxEnvSync("OPENCODE_STATUS", statusType)
          }
          break
        }

        case "session.deleted":
        case "server.instance.disposed": {
          currentSessionID = null
          currentModel = null
          unsetTmuxEnvSync("OPENCODE_SESSION_ID")
          unsetTmuxEnvSync("OPENCODE_STATUS")
          unsetTmuxEnvSync("OPENCODE_MODEL")
          unsetTmuxEnvSync("OPENCODE_DIR")
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
