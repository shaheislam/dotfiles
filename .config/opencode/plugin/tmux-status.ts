// OpenCode plugin: push session metadata into tmux environment variables.
// tmux status bar segments can read these via #{E:OPENCODE_SESSION_ID}, etc.
// Requires tmux to be running — degrades silently if not.
import type { Plugin } from "@opencode-ai/plugin"

export const TmuxStatusPlugin: Plugin = async ({ $, directory }) => {
  let currentSessionID: string | null = null
  let currentModel: string | null = null
  const tmuxPane = process.env.TMUX_PANE

  const scopedKeys = {
    OPENCODE_SESSION_ID: "@opencode_session_id",
    OPENCODE_STATUS: "@opencode_status",
    OPENCODE_MODEL: "@opencode_model",
    OPENCODE_DIR: "@opencode_dir",
  } as const

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
    if (!tmuxPane) return
    const option = scopedKeys[key]
    try {
      await $`tmux set-option -p -t ${tmuxPane} ${option} ${value}`.quiet().nothrow()
      await $`tmux set-window-option -t ${tmuxPane} ${option} ${value}`.quiet().nothrow()
    } catch {
      // tmux may not support scoped user options in older sessions — ignore
    }
  }

  async function unsetTmuxScoped(key: keyof typeof scopedKeys) {
    if (!tmuxPane) return
    const option = scopedKeys[key]
    try {
      await $`tmux set-option -p -u -t ${tmuxPane} ${option}`.quiet().nothrow()
      await $`tmux set-window-option -u -t ${tmuxPane} ${option}`.quiet().nothrow()
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

  function setTmuxScopedSync(key: keyof typeof scopedKeys, value: string) {
    if (!tmuxPane) return
    const option = scopedKeys[key]
    try {
      Bun.spawnSync(["tmux", "set-option", "-p", "-t", tmuxPane, option, value], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
      Bun.spawnSync(["tmux", "set-window-option", "-t", tmuxPane, option, value], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
    } catch {
      // ignore
    }
  }

  function unsetTmuxScopedSync(key: keyof typeof scopedKeys) {
    if (!tmuxPane) return
    const option = scopedKeys[key]
    try {
      Bun.spawnSync(["tmux", "set-option", "-p", "-u", "-t", tmuxPane, option], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
      Bun.spawnSync(["tmux", "set-window-option", "-u", "-t", tmuxPane, option], {
        cwd: directory,
        stdout: "ignore",
        stderr: "ignore",
      })
    } catch {
      // ignore
    }
  }

  async function setOpenCodeMetadata(key: keyof typeof scopedKeys, value: string) {
    await setTmuxEnv(key, value)
    await setTmuxScoped(key, value)
  }

  function setOpenCodeMetadataSync(key: keyof typeof scopedKeys, value: string) {
    setTmuxEnvSync(key, value)
    setTmuxScopedSync(key, value)
  }

  function unsetOpenCodeMetadataSync(key: keyof typeof scopedKeys) {
    unsetTmuxEnvSync(key)
    unsetTmuxScopedSync(key)
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
            setOpenCodeMetadataSync("OPENCODE_STATUS", statusType)
          }
          break
        }

        case "session.deleted":
        case "server.instance.disposed": {
          currentSessionID = null
          currentModel = null
          unsetOpenCodeMetadataSync("OPENCODE_SESSION_ID")
          unsetOpenCodeMetadataSync("OPENCODE_STATUS")
          unsetOpenCodeMetadataSync("OPENCODE_MODEL")
          unsetOpenCodeMetadataSync("OPENCODE_DIR")
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
