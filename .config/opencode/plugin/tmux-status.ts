// OpenCode plugin: push session metadata into tmux environment variables.
// tmux status bar segments can read these via #{E:OPENCODE_SESSION_ID}, etc.
// Requires tmux to be running — degrades silently if not.
import type { Plugin } from "@opencode-ai/plugin"

export const TmuxStatusPlugin: Plugin = async ({ $, directory }) => {
  let currentSessionID: string | null = null
  let currentModel: string | null = null
  const tmuxPane = process.env.TMUX_PANE
  const tmuxWindow = process.env.TMUX_AGENT_TARGET || tmuxPane
  const lastValues = new Map<string, string>()
  let pendingStatus: Promise<void> | null = null

  const scopedKeys = {
    OPENCODE_SESSION_ID: "@opencode_session_id",
    OPENCODE_STATUS: "@opencode_status",
    OPENCODE_MODEL: "@opencode_model",
    OPENCODE_DIR: "@opencode_dir",
    WNAME_STYLE: "@wname_style",
  } as const

  function statusStyle(statusType: string) {
    switch (statusType) {
      case "busy":
      case "running":
      case "thinking":
      case "streaming":
      case "error":
        return "#[fg=#f7768e]"
      case "idle":
        return "#[fg=#e0af68]"
      default:
        return "#[fg=#e0af68]"
    }
  }

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

  async function setTmuxScoped(key: keyof typeof scopedKeys, value: string) {
    const target = key === "WNAME_STYLE" ? tmuxWindow : tmuxPane
    if (!target) return
    const option = scopedKeys[key]
    try {
      if (key !== "WNAME_STYLE" && tmuxPane) {
        await $`tmux set-option -p -t ${tmuxPane} ${option} ${value}`.quiet().nothrow()
      }
      await $`tmux set-window-option -t ${target} ${option} ${value}`.quiet().nothrow()
    } catch {
      // tmux may not support scoped user options in older sessions — ignore
    }
  }

  async function unsetTmuxScoped(key: keyof typeof scopedKeys) {
    const target = key === "WNAME_STYLE" ? tmuxWindow : tmuxPane
    if (!target) return
    const option = scopedKeys[key]
    try {
      if (key !== "WNAME_STYLE" && tmuxPane) {
        await $`tmux set-option -p -u -t ${tmuxPane} ${option}`.quiet().nothrow()
      }
      await $`tmux set-window-option -u -t ${target} ${option}`.quiet().nothrow()
    } catch {
      // ignore
    }
  }

  async function setOpenCodeMetadata(key: keyof typeof scopedKeys, value: string) {
    if (lastValues.get(key) === value) return
    lastValues.set(key, value)
    await setTmuxEnv(key, value)
    await setTmuxScoped(key, value)
  }

  async function unsetOpenCodeMetadata(key: keyof typeof scopedKeys) {
    if (!lastValues.has(key)) return
    lastValues.delete(key)
    await unsetTmuxEnv(key)
    await unsetTmuxScoped(key)
  }

  function queueStatusUpdate(statusType: string) {
    if (lastValues.get("OPENCODE_STATUS") === statusType) return
    lastValues.set("OPENCODE_STATUS", statusType)
    pendingStatus = (pendingStatus ?? Promise.resolve())
      .then(async () => {
        await setTmuxEnv("OPENCODE_STATUS", statusType)
        await setTmuxScoped("OPENCODE_STATUS", statusType)
        await setTmuxScoped("WNAME_STYLE", statusStyle(statusType))
      })
      .catch(() => undefined)
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          const session = (event as any).properties?.info
          if (!session?.id) break
          currentSessionID = session.id
          await setOpenCodeMetadata("OPENCODE_SESSION_ID", session.id)
          await setOpenCodeMetadata("OPENCODE_STATUS", "active")
          await setOpenCodeMetadata("OPENCODE_DIR", directory)
          await setTmuxScoped("WNAME_STYLE", "#[fg=#e0af68]")
          break
        }

        case "message.updated": {
          const msg = (event as any).properties?.info
          if (msg?.role === "assistant" && msg?.modelID) {
            currentModel = msg.modelID
            await setOpenCodeMetadata("OPENCODE_MODEL", msg.modelID)
          }
          break
        }

        case "session.status": {
          const props = (event as any).properties
          const statusType = props?.status?.type
          if (statusType) {
            queueStatusUpdate(statusType)
          }
          break
        }

        case "session.deleted":
        case "server.instance.disposed": {
          currentSessionID = null
          currentModel = null
          await Promise.all([
            unsetOpenCodeMetadata("OPENCODE_SESSION_ID"),
            unsetOpenCodeMetadata("OPENCODE_STATUS"),
            unsetOpenCodeMetadata("OPENCODE_MODEL"),
            unsetOpenCodeMetadata("OPENCODE_DIR"),
            unsetTmuxScoped("WNAME_STYLE"),
          ])
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

export default TmuxStatusPlugin
