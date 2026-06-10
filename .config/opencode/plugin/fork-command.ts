import type { Plugin } from "@opencode-ai/plugin"

const FORK_COMMAND = "fork"
const GWT_FORK_COMMAND = "gwtfork"
const TUI_FORK_COMMAND = "session_fork"
const HANDLED_FORK = "__OPENCODE_FORK_HANDLED__"
const HANDLED_GWT_FORK = "__OPENCODE_GWTFORK_HANDLED__"

function parseArgs(input: string) {
  const args: string[] = []
  let current = ""
  let quote: "'" | '"' | null = null
  let escape = false

  for (const char of input) {
    if (escape) {
      current += char
      escape = false
      continue
    }
    if (char === "\\") {
      escape = true
      continue
    }
    if (quote) {
      if (char === quote) {
        quote = null
      } else {
        current += char
      }
      continue
    }
    if (char === "'" || char === '"') {
      quote = char
      continue
    }
    if (/\s/.test(char)) {
      if (current.length > 0) {
        args.push(current)
        current = ""
      }
      continue
    }
    current += char
  }

  if (escape) current += "\\"
  if (current.length > 0) args.push(current)
  return args
}

function decodeOutput(output: Uint8Array | undefined) {
  if (!output) return ""
  return new TextDecoder().decode(output).trim()
}

function summarizeOutput(output: string) {
  const line = output.split("\n").find((candidate) => candidate.trim().length > 0)
  return line?.trim() || "gwtfork launched"
}

const ForkCommandPlugin: Plugin = async ({ client, directory }) => ({
  config: async (input) => {
    input.command ??= {}
    input.command[FORK_COMMAND] ??= {
      description: "Fork the current OpenCode session in this worktree",
      template: "Fork the current OpenCode session in this worktree.",
    }
    input.command[GWT_FORK_COMMAND] ??= {
      description: "Fork the current OpenCode session into a new gwtt worktree and tmux window",
      template: "Fork the current OpenCode session into a new gwtt worktree and tmux window.",
    }
  },
  "command.execute.before": async (input) => {
    if (input.command === FORK_COMMAND) {
      await client.tui.executeCommand({
        query: { directory },
        body: { command: TUI_FORK_COMMAND },
      })

      throw new Error(HANDLED_FORK)
    }

    if (input.command !== GWT_FORK_COMMAND) return

    const args = parseArgs(input.arguments || "")
    if (args.length === 0) {
      await client.tui.showToast({
        query: { directory },
        body: {
          title: "gwtfork needs a name",
          message: "Usage: /gwtfork <worktree-name> [note...]",
          variant: "error",
          duration: 6000,
        },
      })
      throw new Error("Usage: /gwtfork <worktree-name> [note...]")
    }

    const result = Bun.spawnSync(
      ["fish", "-c", 'opencode-forkworktree --session "$OPENCODE_SESSION_ID" $argv', "--", ...args],
      {
        cwd: directory,
        env: {
          ...process.env,
          OPENCODE_SESSION_ID: input.sessionID,
          OPENCODE_DIR: directory,
        },
        stdout: "pipe",
        stderr: "pipe",
      },
    )

    const stdout = decodeOutput(result.stdout)
    const stderr = decodeOutput(result.stderr)
    const output = [stdout, stderr].filter(Boolean).join("\n")

    if (result.exitCode !== 0) {
      await client.tui.showToast({
        query: { directory },
        body: {
          title: "gwtfork failed",
          message: summarizeOutput(output || `exit ${result.exitCode}`),
          variant: "error",
          duration: 10000,
        },
      })
      throw new Error(output || `gwtfork failed with exit ${result.exitCode}`)
    }

    await client.tui.showToast({
      query: { directory },
      body: {
        title: "gwtfork launched",
        message: summarizeOutput(output),
        variant: "success",
        duration: 8000,
      },
    })

    throw new Error(HANDLED_GWT_FORK)
  },
})

export default ForkCommandPlugin
