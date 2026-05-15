import { existsSync } from "node:fs"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const DOCTOR_COMMAND = "doctor"
const WORKTREE_STATUS_COMMAND = "worktree-status"
const HANDLED_OPS_COMMAND = "__OPENCODE_OPS_COMMAND_HANDLED__"

const HOME = process.env.HOME || ""
const DOTFILES_ROOT = process.env.DOTFILES_ROOT || (HOME ? join(HOME, "dotfiles") : "")

function decodeOutput(output: Uint8Array | undefined) {
  if (!output) return ""
  return new TextDecoder().decode(output).trim()
}

function firstLine(output: string) {
  return output.split("\n").find((line) => line.trim().length > 0)?.trim() || "No output"
}

function countLines(output: string) {
  if (!output.trim()) return 0
  return output.split("\n").filter((line) => line.trim().length > 0).length
}

function run(command: string[], cwd: string) {
  const result = Bun.spawnSync(command, {
    cwd,
    env: process.env,
    stdout: "pipe",
    stderr: "pipe",
  })
  const stdout = decodeOutput(result.stdout)
  const stderr = decodeOutput(result.stderr)
  return {
    exitCode: result.exitCode,
    output: [stdout, stderr].filter(Boolean).join("\n"),
  }
}

const OpsCommandPlugin: Plugin = async ({ client, directory }) => {
  async function toast(title: string, message: string, variant: "info" | "success" | "warning" | "error") {
    try {
      await client.tui.showToast({
        query: { directory },
        body: { title, message, variant, duration: variant === "error" ? 10000 : 7000 },
      })
    } catch {
      // Headless runs are fine; command interception still prevents model use.
    }
  }

  async function runDoctor() {
    const doctorScript = DOTFILES_ROOT ? join(DOTFILES_ROOT, "scripts", "opencode", "doctor.sh") : ""
    if (!doctorScript || !existsSync(doctorScript)) {
      await toast("OpenCode doctor", "Doctor script not found under DOTFILES_ROOT", "error")
      throw new Error("OpenCode doctor script not found")
    }

    const result = run(["bash", doctorScript, "--quick"], DOTFILES_ROOT || directory)
    if (result.exitCode === 0) {
      await toast("OpenCode doctor", "Quick doctor passed", "success")
    } else {
      await toast("OpenCode doctor failed", firstLine(result.output || `exit ${result.exitCode}`), "error")
    }
  }

  async function runWorktreeStatus() {
    const branch = run(["git", "-c", "core.fsmonitor=false", "branch", "--show-current"], directory).output || "detached"
    const status = run(["git", "-c", "core.fsmonitor=false", "status", "--short"], directory).output
    const worktrees = run(["git", "worktree", "list", "--porcelain"], directory).output
    const tmuxSessions = run(["bash", "-lc", "tmux list-sessions 2>/dev/null || true"], directory).output
    const beads = run(["bash", "-lc", "if command -v bd >/dev/null 2>&1; then bd list --status=in_progress 2>/dev/null || true; fi"], directory).output

    const worktreeCount = worktrees.split("\n").filter((line) => line.startsWith("worktree ")).length
    const message = `${branch.trim() || "detached"} · ${worktreeCount} worktrees · ${countLines(tmuxSessions)} tmux · ${countLines(beads)} active beads · ${countLines(status)} changes`
    await toast("Worktree status", message, status.trim() ? "warning" : "success")
  }

  return {
    config: async (input) => {
      input.command ??= {}
      input.command[DOCTOR_COMMAND] ??= {
        description: "Run the repo's OpenCode doctor without a model call",
        template: "Run the repo's OpenCode doctor without a model call.",
      }
      input.command[WORKTREE_STATUS_COMMAND] ??= {
        description: "Show current worktree and agent orchestration status without a model call",
        template: "Show current worktree and agent orchestration status without a model call.",
      }
    },

    "command.execute.before": async (input) => {
      if (input.command === DOCTOR_COMMAND) {
        await runDoctor()
        throw new Error(HANDLED_OPS_COMMAND)
      }

      if (input.command === WORKTREE_STATUS_COMMAND) {
        await runWorktreeStatus()
        throw new Error(HANDLED_OPS_COMMAND)
      }
    },
  }
}

export default OpsCommandPlugin
