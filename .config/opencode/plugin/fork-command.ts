import type { Plugin } from "@opencode-ai/plugin"

const FORK_COMMAND = "fork"
const FORKGWTT_COMMAND = "forkgwtt"
const LEGACY_GWT_FORK_COMMAND = "gwtfork"
const FORKPANE_COMMAND = "forkpane"
const TUI_FORK_COMMAND = "session_fork"
const HANDLED_FORK = "__OPENCODE_FORK_HANDLED__"
const HANDLED_FORKGWTT = "__OPENCODE_FORKGWTT_HANDLED__"
const HANDLED_FORKPANE = "__OPENCODE_FORKPANE_HANDLED__"

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
  return line?.trim() || "fork launched"
}

const ForkCommandPlugin: Plugin = async ({ client, directory }) => ({
  config: async (input) => {
    input.command ??= {}
    input.command[FORK_COMMAND] ??= {
      description: "Fork the current OpenCode session in this worktree",
      template: "Fork the current OpenCode session in this worktree.",
    }
    input.command[FORKGWTT_COMMAND] ??= {
      description: "Fork the current OpenCode session into a new gwtt worktree and tmux window",
      template: "Fork the current OpenCode session into a new gwtt worktree and tmux window.",
    }
    input.command[LEGACY_GWT_FORK_COMMAND] ??= input.command[FORKGWTT_COMMAND]
    input.command[FORKPANE_COMMAND] ??= {
      description: "Fork the current OpenCode session into a new tmux split pane",
      template: "Fork the current OpenCode session into a new tmux split pane.",
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

    if (input.command === FORKPANE_COMMAND) {
      const args = parseArgs(input.arguments || "")
      const result = Bun.spawnSync(
        ["fish", "-c", 'opencode-forkpane --session "$OPENCODE_SESSION_ID" --dir "$OPENCODE_DIR" $argv', "--", ...args],
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
            title: "forkpane failed",
            message: summarizeOutput(output || `exit ${result.exitCode}`),
            variant: "error",
            duration: 10000,
          },
        })
        throw new Error(output || `forkpane failed with exit ${result.exitCode}`)
      }

      await client.tui.showToast({
        query: { directory },
        body: {
          title: "forkpane launched",
          message: summarizeOutput(output),
          variant: "success",
          duration: 8000,
        },
      })

      throw new Error(HANDLED_FORKPANE)
    }

    if (input.command !== FORKGWTT_COMMAND && input.command !== LEGACY_GWT_FORK_COMMAND) return

    const args = parseArgs(input.arguments || "")
    if (args.length === 0) {
      await client.tui.showToast({
        query: { directory },
        body: {
          title: "forkgwtt needs a name",
          message: "Usage: /forkgwtt <worktree-name> [note...]",
          variant: "error",
          duration: 6000,
        },
      })
      throw new Error("Usage: /forkgwtt <worktree-name> [note...]")
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
          title: "forkgwtt failed",
          message: summarizeOutput(output || `exit ${result.exitCode}`),
          variant: "error",
          duration: 10000,
        },
      })
      throw new Error(output || `forkgwtt failed with exit ${result.exitCode}`)
    }

    await client.tui.showToast({
      query: { directory },
      body: {
        title: "forkgwtt launched",
        message: summarizeOutput(output),
        variant: "success",
        duration: 8000,
      },
    })

    throw new Error(HANDLED_FORKGWTT)
  },
})

export default ForkCommandPlugin
