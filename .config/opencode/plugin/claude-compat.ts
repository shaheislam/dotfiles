import { existsSync } from "node:fs"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

type HookResult = {
  stdout: string
  stderr: string
  exitCode: number
}

type ToolPayload = {
  tool_name: string
  tool_input: Record<string, unknown>
  tool_output?: string
  error?: string
  session_id?: string
}

const DOTFILES_ROOT = join(process.env.HOME || "", "dotfiles")
const CLAUDE_HOOKS_DIR = join(DOTFILES_ROOT, ".claude", "hooks")
const TMUX_HOOKS_DIR = join(DOTFILES_ROOT, "scripts", "tmux", "hooks")
const DREAM_DIR = join(DOTFILES_ROOT, ".claude", "skills", "dream")

function normalizeMessage(text: string) {
  return text.trim()
}

function hookPath(...parts: string[]) {
  return join(CLAUDE_HOOKS_DIR, ...parts)
}

function tmuxHookPath(name: string) {
  return join(TMUX_HOOKS_DIR, name)
}

function dreamPath(name: string) {
  return join(DREAM_DIR, name)
}

function opencodeToolName(tool: string) {
  switch (tool) {
    case "bash":
      return "Bash"
    case "read":
      return "Read"
    case "write":
      return "Write"
    case "edit":
      return "Edit"
    case "multiedit":
      return "MultiEdit"
    case "grep":
      return "Grep"
    case "glob":
      return "Glob"
    default:
      return tool
  }
}

function isWriteTool(tool: string) {
  return ["write", "edit", "multiedit"].includes(tool.toLowerCase())
}

export const ClaudeCompatPlugin: Plugin = async ({ directory, worktree }) => {
  const projectDir = worktree || directory
  const sessionContext = new Set<string>()
  const transientContext: string[] = []
  const messageRoles = new Map<string, string>()
  const seenPromptMessages = new Set<string>()
  let currentSessionID: string | null = null
  let shutdownHandled = false

  function addSessionContext(text: string) {
    const normalized = normalizeMessage(text)
    if (normalized) {
      sessionContext.add(normalized)
    }
  }

  function addTransientContext(text: string) {
    const normalized = normalizeMessage(text)
    if (normalized) {
      transientContext.push(normalized)
    }
  }

  async function runScript(script: string, payload?: Record<string, unknown>): Promise<HookResult> {
    if (!existsSync(script)) {
      return { stdout: "", stderr: "", exitCode: 0 }
    }

    const proc = Bun.spawn([script], {
      cwd: projectDir,
      env: {
        ...process.env,
        CLAUDE_PROJECT_DIR: projectDir,
        PROJECT_ROOT: projectDir,
        REPO_ROOT: projectDir,
        DOTFILES_ROOT,
      },
      stdin: payload ? new TextEncoder().encode(`${JSON.stringify(payload)}\n`) : undefined,
      stdout: "pipe",
      stderr: "pipe",
    })

    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
      proc.exited,
    ])

    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode }
  }

  async function runCommand(command: string, args: string[] = [], payload?: Record<string, unknown>): Promise<HookResult> {
    const proc = Bun.spawn([command, ...args], {
      cwd: projectDir,
      env: {
        ...process.env,
        CLAUDE_PROJECT_DIR: projectDir,
        PROJECT_ROOT: projectDir,
        REPO_ROOT: projectDir,
        DOTFILES_ROOT,
      },
      stdin: payload ? new TextEncoder().encode(`${JSON.stringify(payload)}\n`) : undefined,
      stdout: "pipe",
      stderr: "pipe",
    })

    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
      proc.exited,
    ])

    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode }
  }

  function runScriptSync(script: string, payload?: Record<string, unknown>): HookResult {
    if (!existsSync(script)) {
      return { stdout: "", stderr: "", exitCode: 0 }
    }

    const proc = Bun.spawnSync([script], {
      cwd: projectDir,
      env: {
        ...process.env,
        CLAUDE_PROJECT_DIR: projectDir,
        PROJECT_ROOT: projectDir,
        REPO_ROOT: projectDir,
        DOTFILES_ROOT,
      },
      stdin: payload ? new TextEncoder().encode(`${JSON.stringify(payload)}\n`) : undefined,
      stdout: "pipe",
      stderr: "pipe",
    })

    return {
      stdout: Buffer.from(proc.stdout || []).toString("utf8").trim(),
      stderr: Buffer.from(proc.stderr || []).toString("utf8").trim(),
      exitCode: proc.exitCode ?? 0,
    }
  }

  function runCommandSync(command: string, args: string[] = [], payload?: Record<string, unknown>): HookResult {
    const proc = Bun.spawnSync([command, ...args], {
      cwd: projectDir,
      env: {
        ...process.env,
        CLAUDE_PROJECT_DIR: projectDir,
        PROJECT_ROOT: projectDir,
        REPO_ROOT: projectDir,
        DOTFILES_ROOT,
      },
      stdin: payload ? new TextEncoder().encode(`${JSON.stringify(payload)}\n`) : undefined,
      stdout: "pipe",
      stderr: "pipe",
    })

    return {
      stdout: Buffer.from(proc.stdout || []).toString("utf8").trim(),
      stderr: Buffer.from(proc.stderr || []).toString("utf8").trim(),
      exitCode: proc.exitCode ?? 0,
    }
  }

  async function runContextScript(script: string) {
    const result = await runScript(script)
    if (result.stdout) {
      addSessionContext(result.stdout)
    }
  }

  function normalizeToolOutput(output: unknown) {
    if (typeof output === "string") {
      return output
    }

    if (output === undefined || output === null) {
      return undefined
    }

    try {
      return JSON.stringify(output)
    } catch {
      return String(output)
    }
  }

  function buildToolPayload(tool: string, args: Record<string, unknown>, toolOutput?: string): ToolPayload {
    const filePath = args.filePath ?? args.file_path ?? args.path

    return {
      tool_name: opencodeToolName(tool),
      session_id: currentSessionID ?? undefined,
      tool_input: {
        ...args,
        ...(typeof filePath === "string"
          ? {
              file_path: filePath,
              filePath,
            }
          : {}),
      },
      ...(toolOutput ? { tool_output: toolOutput } : {}),
    }
  }

  function maybeBlock(result: HookResult) {
    if (result.exitCode === 0) {
      return
    }

    const message = [result.stdout, result.stderr].filter(Boolean).join("\n") || "Hook blocked tool execution"
    throw new Error(message)
  }

  async function handleBashPreTool(args: Record<string, unknown>) {
    const payload = buildToolPayload("bash", args)

    maybeBlock(await runScript(hookPath("use_bun.py"), payload))
    maybeBlock(await runScript(hookPath("validate-bash.py"), payload))

    const ciResult = await runScript(hookPath("ci-precommit.sh"), payload)
    if (!ciResult.stdout) {
      return
    }

    let parsed: { decision?: string; reason?: string } | null = null
    try {
      parsed = JSON.parse(ciResult.stdout) as { decision?: string; reason?: string }
    } catch {
      // Ignore malformed non-blocking output.
    }

    if (parsed?.decision === "block") {
      throw new Error(parsed.reason || "Command blocked by CI precommit hook")
    }
  }

  async function handleWritePreTool(tool: string, args: Record<string, unknown>) {
    const payload = buildToolPayload(tool, args)
    maybeBlock(await runScript(hookPath("settings-edit-redirect.py"), payload))
    maybeBlock(await runScript(hookPath("protect-files.py"), payload))
  }

  async function appendHookMessage(script: string, payload: Record<string, unknown>, useSessionContext = false) {
    const result = await runScript(script, payload)
    const text = result.stdout || result.stderr
    if (!text) {
      return
    }

    try {
      const parsed = JSON.parse(text) as { systemMessage?: string }
      if (parsed.systemMessage) {
        if (useSessionContext) {
          addSessionContext(parsed.systemMessage)
        } else {
          addTransientContext(parsed.systemMessage)
        }
        return
      }
    } catch {
      // Fall through to plain text handling.
    }

    if (useSessionContext) {
      addSessionContext(text)
    } else {
      addTransientContext(text)
    }
  }

  async function appendPromptContext(prompt: string) {
    const result = await runScript(hookPath("jfdi", "prompt-inject-context.py"), {
      hook_type: "UserPromptSubmit",
      session_id: currentSessionID ?? undefined,
      prompt,
      cwd: projectDir,
    })

    if (!result.stdout) {
      return
    }

    try {
      const parsed = JSON.parse(result.stdout) as { context?: string }
      if (parsed.context) {
        addTransientContext(parsed.context)
      }
    } catch {
      // The JFDI hook is JSON-only; ignore malformed output rather than injecting noise.
    }
  }

  async function logToolFailure(tool: string, args: Record<string, unknown>, error: unknown) {
    const payload = buildToolPayload(tool, args)
    try {
      payload.error = typeof error === "string" ? error : JSON.stringify(error ?? "Tool execution failed")
    } catch {
      payload.error = String(error ?? "Tool execution failed")
    }
    await runScript(hookPath("log-tool-failure.py"), payload)
  }

  async function collectSessionStartContext() {
    await Promise.all([
      runScript(join(DOTFILES_ROOT, "scripts", "fix-hookify-imports.sh")),
      runScript(hookPath("plugin-chmod-fix.sh")),
      runScript(tmuxHookPath("tmux-agent-start.sh")),
      runScript(dreamPath("count-session.sh")),
      runCommand("bd", ["prime"]).catch(() => ({ stdout: "", stderr: "", exitCode: 0 })),
    ])

    await runContextScript(hookPath("work-detect.sh"))
    await runContextScript(hookPath("lsp-status.sh"))
    await runContextScript(hookPath("plan-resume.sh"))
    await runContextScript(hookPath("changelog-resume.sh"))
  }

  function handleShutdown() {
    if (shutdownHandled) {
      return
    }
    shutdownHandled = true

    runScriptSync(tmuxHookPath("tmux-agent-end.sh"))
    runCommandSync("bash", [join(projectDir, "scripts", "harness", "session-report.sh"), "--json"])
    runCommandSync("bash", [join(DOTFILES_ROOT, "scripts", "obsidian", "session-synthesize.sh"), "--cwd", projectDir])
    runCommandSync("bash", [join(DOTFILES_ROOT, "scripts", "opencode", "jfdi-shutdown-sync.sh")])
    runScriptSync(dreamPath("dream-hook.sh"))
  }

  function handleNotification(message: string, title?: string, variant?: string) {
    const payload = {
      title: title || "OpenCode",
      message,
      variant: variant || "info",
      notification_type: variant || "info",
      session_id: currentSessionID ?? undefined,
    }

    runScriptSync(hookPath("log-notification.sh"), payload)
    runScriptSync(hookPath("macos_notification.py"), payload)
    runScriptSync(tmuxHookPath("tmux-agent-notify.sh"), payload)
  }

  function appendCompactContext(output: { context: string[] }, result: HookResult) {
    const text = result.stdout || result.stderr
    if (text) {
      output.context.push(text)
    }
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          currentSessionID = event.properties.info.id
          shutdownHandled = false
          sessionContext.clear()
          transientContext.length = 0
          seenPromptMessages.clear()
          messageRoles.clear()
          await collectSessionStartContext()
          break
        }

        case "message.updated": {
          messageRoles.set(event.properties.info.id, event.properties.info.role)
          break
        }

        case "message.part.updated": {
          const { part } = event.properties
          if (part.type !== "text") {
            break
          }

          if (messageRoles.get(part.messageID) !== "user") {
            break
          }

          if (seenPromptMessages.has(part.messageID)) {
            break
          }

          seenPromptMessages.add(part.messageID)
          const prompt = part.text ?? ""
          await Promise.all([
            runScript(tmuxHookPath("tmux-agent-prompt.sh")),
            appendHookMessage(hookPath("nvim-bridge.sh"), {
              session_id: currentSessionID ?? undefined,
              tool_name: "UserPromptSubmit",
              tool_input: { prompt },
              prompt,
              cwd: projectDir,
            }),
            appendPromptContext(prompt),
            appendHookMessage(hookPath("plan-watch.sh"), {
              session_id: currentSessionID ?? undefined,
              tool_name: "UserPromptSubmit",
              tool_input: { prompt },
              prompt,
              cwd: projectDir,
            }),
          ])
          break
        }

        case "session.status": {
          if (event.properties.status.type === "idle") {
            await runScript(tmuxHookPath("tmux-agent-stop.sh"))
          }
          break
        }

        case "tui.toast.show": {
          handleNotification(event.properties.message, event.properties.title, event.properties.variant)
          break
        }

        case "tool.execute.error":
        case "tool.execute.failed":
        case "tool.error": {
          const properties = event.properties as Record<string, unknown>
          const tool = String(properties.tool || properties.toolName || properties.name || "unknown")
          const args = (properties.args || properties.tool_input || properties.input || {}) as Record<string, unknown>
          await logToolFailure(tool, args, properties.error || properties.message || properties.reason || "Tool execution failed")
          break
        }

        case "server.instance.disposed":
        case "session.deleted": {
          handleShutdown()
          break
        }
      }
    },

    "tool.execute.before": async (input, output) => {
      const tool = input.tool.toLowerCase()
      const args = (output?.args || input.args || {}) as Record<string, unknown>

      if (tool === "bash") {
        await handleBashPreTool(args)
        return
      }

      if (isWriteTool(tool)) {
        await handleWritePreTool(tool, args)
      }
    },

    "tool.execute.after": async (input, output) => {
      const tool = input.tool.toLowerCase()
      const args = (input.args || {}) as Record<string, unknown>
      const payload = buildToolPayload(tool, args, normalizeToolOutput(output.output))

      if (tool === "read") {
        await appendHookMessage(hookPath("deepwiki-context.py"), payload)
      }

      if (isWriteTool(tool)) {
        await appendHookMessage(hookPath("auto-format.py"), payload)
        await appendHookMessage(hookPath("file-modified.sh"), payload)
        await appendHookMessage(hookPath("ci-lint-on-save.sh"), payload)
      }

      await appendHookMessage(hookPath("plan-watch.sh"), payload)
    },

    "tool.execute.error": async (input, output) => {
      const args = (input.args || output?.args || {}) as Record<string, unknown>
      await logToolFailure(input.tool.toLowerCase(), args, output?.error || output?.message || "Tool execution failed")
    },

    "experimental.chat.system.transform": async (_input, output) => {
      for (const text of sessionContext) {
        output.system.push(text)
      }

      while (transientContext.length > 0) {
        const next = transientContext.shift()
        if (next) {
          output.system.push(next)
        }
      }
    },

    "experimental.session.compacting": async (_input, output) => {
      try {
        appendCompactContext(output, runCommandSync("bd", ["prime"]))
      } catch {
        // bd may be unavailable in minimal test or bootstrap environments.
      }

      appendCompactContext(output, runScriptSync(hookPath("plan-persist.sh")))
      appendCompactContext(output, runScriptSync(hookPath("changelog-persist.sh")))
    },
  }
}
