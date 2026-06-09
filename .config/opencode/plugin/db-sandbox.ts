import { existsSync, readFileSync } from "node:fs"
import { basename, join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const HOME = process.env.HOME || ""
const DOTFILES_ROOT = process.env.DOTFILES_ROOT || (HOME ? `${HOME}/dotfiles` : "")
const DB_SCRIPT = join(DOTFILES_ROOT, "scripts", "db-sandbox.sh")
const STATE_ROOT = join(HOME, ".claude", "db-sandbox")

function sanitizeName(raw: string) {
  return basename(raw)
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48)
}

function parseEnvFile(path: string) {
  const env: Record<string, string> = {}
  if (!existsSync(path)) return env

  for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
    if (!line || line.startsWith("#")) continue
    const index = line.indexOf("=")
    if (index <= 0) continue
    env[line.slice(0, index)] = line.slice(index + 1)
  }
  return env
}

function markerEngines(projectRoot: string) {
  const direct = process.env.DB_SANDBOX
  if (direct) return direct

  const marker = join(projectRoot, ".db-sandbox.toml")
  if (!existsSync(marker)) return ""

  const text = readFileSync(marker, "utf8")
  const match = text.match(/^\s*engines\s*=\s*(.+)$/m)
  if (!match) return "postgres,redis"
  return match[1].replace(/["'\[\]\s]/g, "") || "postgres,redis"
}

async function runDbSandbox(projectRoot: string, args: string[]) {
  if (!existsSync(DB_SCRIPT)) return
  const proc = Bun.spawn([DB_SCRIPT, ...args], {
    cwd: projectRoot,
    env: {
      ...process.env,
      DB_SANDBOX_CWD: projectRoot,
    },
    stdout: "ignore",
    stderr: "ignore",
  })
  await proc.exited
}

export const DbSandboxPlugin: Plugin = async ({ directory, worktree }) => {
  const projectRoot = worktree || directory
  const context = sanitizeName(process.env.DB_SANDBOX_NAME || projectRoot)
  const envFile = join(STATE_ROOT, context, ".env.db")
  const ensured = new Set<string>()

  return {
    event: async ({ event }) => {
      if (event.type !== "session.deleted") return
      if (process.env.DB_SANDBOX_STOP_ON_EXIT !== "1") return
      await runDbSandbox(projectRoot, ["down"])
    },
    "shell.env": async (_input, output) => {
      const engines = markerEngines(projectRoot)
      if (engines && !ensured.has(context)) {
        ensured.add(context)
        await runDbSandbox(projectRoot, ["up", engines])
      }

      Object.assign(output.env, parseEnvFile(envFile))
    },
  }
}

export default DbSandboxPlugin
