// OpenCode plugin: mirror session status to a per-directory state file.
// The tmux launcher owns tmux window options because only it reliably knows
// which tmux window hosts the attached TUI.
import type { Plugin } from "@opencode-ai/plugin"
import { createHash } from "node:crypto"
import { mkdir, rm, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"

export const TmuxStatusPlugin: Plugin = async ({ directory }) => {
  let currentSessionID: string | null = null
  let currentModel: string | null = null
  let lastStatus: string | null = null
  let pendingStatus: Promise<void> | null = null
  const statusDir = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "opencode", "tmux-status")
  const statusFile = join(statusDir, `${createHash("sha256").update(directory).digest("hex")}.status`)

  async function writeStatusFile(statusType: string) {
    try {
      await mkdir(statusDir, { recursive: true })
      await writeFile(statusFile, `${statusType}\n`, "utf8")
    } catch {
      // state-file mirroring is best-effort
    }
  }

  async function removeStatusFile() {
    try {
      await rm(statusFile, { force: true })
    } catch {
      // ignore
    }
  }

  function queueStatusUpdate(statusType: string) {
    if (lastStatus === statusType) return
    lastStatus = statusType
    pendingStatus = (pendingStatus ?? Promise.resolve())
      .then(async () => {
        await writeStatusFile(statusType)
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
          lastStatus = "idle"
          await writeStatusFile("idle")
          break
        }

        case "message.updated": {
          const msg = (event as any).properties?.info
          if (msg?.role === "assistant" && msg?.modelID) {
            currentModel = msg.modelID
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

        case "session.deleted": {
          currentSessionID = null
          currentModel = null
          lastStatus = null
          await removeStatusFile()
          break
        }

        case "server.instance.disposed": {
          // OpenCode can dispose transient server instances while the attached
          // TUI is still alive. The tmux launcher owns final color cleanup.
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
