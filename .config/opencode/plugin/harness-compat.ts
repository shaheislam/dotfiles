import { createHash } from "node:crypto"
import { existsSync, mkdirSync, mkdtempSync, rmSync, statSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
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
const PLAN_WATCH_DEBOUNCE_MS = 5000
const STARTUP_FAST_TIMEOUT_MS = 500
const STARTUP_CONTEXT_TIMEOUT_MS = 2500
const MAINTENANCE_TTL_MS = 24 * 60 * 60 * 1000

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
    case "patch":
    case "apply_patch":
    case "apply-patch":
      return "ApplyPatch"
    case "grep":
      return "Grep"
    case "glob":
      return "Glob"
    default:
      return tool
  }
}

function isWriteTool(tool: string) {
  return ["write", "edit", "multiedit", "patch", "apply_patch", "apply-patch"].includes(tool.toLowerCase())
}

export const HarnessCompatPlugin: Plugin = async ({ directory, worktree }) => {
  const projectDir = worktree || directory
  const sessionContext = new Set<string>()
  const transientContext: string[] = []
  const messageRoles = new Map<string, string>()
  const messageTexts = new Map<string, string>()
  const messageOrder: string[] = []
  const seenPromptMessages = new Set<string>()
  let currentSessionID: string | null = null
  let shutdownHandled = false
  let bridgeReviewRunning = false
  let lastBridgeReviewedAssistant = ""
  let currentOpenCodeModel = process.env.OPENCODE_PRIMARY_MODEL || process.env.OPENCODE_MODEL || ""
  let lastPlanWatchAt = 0
  let planWatchRunning: Promise<void> | null = null

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

  async function runScript(
    script: string,
    payload?: Record<string, unknown>,
    extraEnv: Record<string, string> = {},
    timeoutMs = 0,
  ): Promise<HookResult> {
    if (!existsSync(script)) {
      return { stdout: "", stderr: "", exitCode: 0 }
    }

    const proc = Bun.spawn([script], {
      cwd: projectDir,
      env: {
        ...process.env,
        ...extraEnv,
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
      waitForProcess(proc, timeoutMs),
    ])

    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode }
  }

  async function runCommand(
    command: string,
    args: string[] = [],
    payload?: Record<string, unknown>,
    timeoutMs = 0,
  ): Promise<HookResult> {
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
      waitForProcess(proc, timeoutMs),
    ])

    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode }
  }

  async function waitForProcess(proc: { exited: Promise<number>; kill: () => void }, timeoutMs: number) {
    if (timeoutMs <= 0) {
      return proc.exited
    }

    let timer: ReturnType<typeof setTimeout> | undefined
    const timedOut = new Promise<number>((resolve) => {
      timer = setTimeout(() => {
        try {
          proc.kill()
        } catch {
          // Process may have exited between the timeout firing and kill.
        }
        resolve(124)
      }, timeoutMs)
    })

    try {
      return await Promise.race([proc.exited, timedOut])
    } finally {
      if (timer) {
        clearTimeout(timer)
      }
    }
  }

  function runScriptSync(
    script: string,
    payload?: Record<string, unknown>,
    extraEnv: Record<string, string> = {},
  ): HookResult {
    if (!existsSync(script)) {
      return { stdout: "", stderr: "", exitCode: 0 }
    }

    const proc = Bun.spawnSync([script], {
      cwd: projectDir,
      env: {
        ...process.env,
        ...extraEnv,
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

  function addContextResult(result: HookResult) {
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

  function maintenanceStampPath(name: string) {
    const projectHash = createHash("sha256").update(projectDir).digest("hex").slice(0, 16)
    return join(process.env.HOME || tmpdir(), ".cache", "opencode", "harness-compat-maintenance", projectHash, `${name}.stamp`)
  }

  function shouldRunMaintenance(name: string) {
    if (process.env.OPENCODE_MAINTENANCE_DISABLE === "1") {
      return false
    }

    const stampPath = maintenanceStampPath(name)
    try {
      if (Date.now() - statSync(stampPath).mtimeMs < MAINTENANCE_TTL_MS) {
        return false
      }
    } catch {
      // Missing or unreadable stamps should not prevent self-healing.
    }

    try {
      mkdirSync(dirname(stampPath), { recursive: true })
      writeFileSync(stampPath, new Date().toISOString(), "utf8")
    } catch {
      // Cache writes are best-effort; still run the maintenance hook.
    }

    return true
  }

  async function runMaintenanceScript(name: string, script: string) {
    if (!shouldRunMaintenance(name)) {
      return { stdout: "", stderr: "", exitCode: 0 }
    }

    return runScript(script, undefined, {}, STARTUP_CONTEXT_TIMEOUT_MS)
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

  async function appendPlanWatch(payload: Record<string, unknown>, force = false) {
    if (process.env.OPENCODE_PLAN_WATCH_DISABLE === "1") {
      return
    }

    const now = Date.now()
    if (!force && now - lastPlanWatchAt < PLAN_WATCH_DEBOUNCE_MS) {
      return
    }
    if (planWatchRunning && !force) {
      return
    }

    lastPlanWatchAt = now
    planWatchRunning = appendHookMessage(hookPath("plan-watch.sh"), payload).finally(() => {
      planWatchRunning = null
    })
    await planWatchRunning
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

  function rememberMessage(id: string, role?: string, text?: string) {
    if (!messageOrder.includes(id)) {
      messageOrder.push(id)
    }
    if (role) {
      messageRoles.set(id, role)
    }
    if (text !== undefined) {
      messageTexts.set(id, text)
    }
  }

  function lastAssistantText() {
    for (let index = messageOrder.length - 1; index >= 0; index -= 1) {
      const id = messageOrder[index]
      if (messageRoles.get(id) !== "assistant") {
        continue
      }
      const text = messageTexts.get(id)?.trim()
      if (text) {
        return text
      }
    }
    return ""
  }

  function openCodeBridgeEnabled() {
    return process.env.OPENCODE_CROSS_PROVIDER_BRIDGE === "1" || process.env.CROSS_PROVIDER_BRIDGE === "1"
  }

  function startupContextMode() {
    const mode = process.env.OPENCODE_STARTUP_CONTEXT
    if (mode === "off" || mode === "full") {
      return mode
    }
    return "light"
  }

  function defaultOpenCodeReviewerModel() {
    const executorModel = currentOpenCodeModel || process.env.OPENCODE_PRIMARY_MODEL || process.env.OPENCODE_MODEL || "openai/gpt-5.5"
    if (executorModel.startsWith("anthropic/")) {
      return process.env.OPENCODE_BRIDGE_OPENAI_MODEL || "openai/gpt-5.5"
    }
    return process.env.OPENCODE_BRIDGE_ANTHROPIC_MODEL || "anthropic/claude-opus-4-6"
  }

  function openCodeBridgeEnv() {
    const env: Record<string, string> = {
      CROSS_PROVIDER_BRIDGE: "1",
    }

    if (!process.env.CROSS_PROVIDER_ORDER) {
      env.CROSS_PROVIDER_ORDER = process.env.OPENCODE_BRIDGE_ORDER || "opencode"
    }
    if (process.env.OPENCODE_BRIDGE_MODE && !process.env.CROSS_PROVIDER_MODE) {
      env.CROSS_PROVIDER_MODE = process.env.OPENCODE_BRIDGE_MODE
    }
    if (!process.env.CROSS_PROVIDER_OPENCODE_MODEL && !process.env.CROSS_PROVIDER_MODELS) {
      env.CROSS_PROVIDER_OPENCODE_MODEL = process.env.OPENCODE_BRIDGE_MODEL || defaultOpenCodeReviewerModel()
    }
    if (process.env.OPENCODE_BRIDGE_TIMEOUT && !process.env.CROSS_PROVIDER_TIMEOUT) {
      env.CROSS_PROVIDER_TIMEOUT = process.env.OPENCODE_BRIDGE_TIMEOUT
    }
    if (process.env.OPENCODE_BRIDGE_LOG && !process.env.CROSS_PROVIDER_LOG) {
      env.CROSS_PROVIDER_LOG = process.env.OPENCODE_BRIDGE_LOG
    }

    return env
  }

  function parseBridgeDecision(stdout: string) {
    if (!stdout) {
      return ""
    }

    try {
      const parsed = JSON.parse(stdout) as { decision?: string; reason?: string }
      if (parsed.decision === "block" && parsed.reason) {
        return parsed.reason
      }
    } catch {
      // Non-JSON bridge output is still useful context if the script emitted it.
    }

    return stdout
  }

  async function runOpenCodeBridgeReview() {
    if (!openCodeBridgeEnabled() || bridgeReviewRunning) {
      return
    }

    const assistantText = lastAssistantText()
    if (!assistantText || assistantText === lastBridgeReviewedAssistant) {
      return
    }

    bridgeReviewRunning = true
    const bridgeDir = mkdtempSync(join(tmpdir(), "opencode-bridge-"))
    const transcriptPath = join(bridgeDir, "transcript.jsonl")

    try {
      writeFileSync(transcriptPath, `${JSON.stringify({ role: "assistant", content: assistantText })}\n`, "utf8")
      const result = await runScript(
        hookPath("cross-provider-bridge.sh"),
        {
          session_id: currentSessionID ?? "opencode",
          stop_hook_active: false,
          transcript_path: transcriptPath,
        },
        openCodeBridgeEnv(),
      )
      lastBridgeReviewedAssistant = assistantText

      const review = parseBridgeDecision(result.stdout)
      if (review) {
        addTransientContext(
          `OpenCode adversarial bridge review returned concerns:\n\n${review}\n\nAddress these concerns before considering the task complete.`,
        )
        handleNotification("Adversarial bridge review returned concerns", "OpenCode Bridge", "warning")
      }
    } finally {
      rmSync(bridgeDir, { recursive: true, force: true })
      bridgeReviewRunning = false
    }
  }

  async function collectSessionStartContext() {
    const mode = startupContextMode()
    if (mode === "off") {
      return
    }

    const startupTasks = [
      runMaintenanceScript("fix-hookify-imports", join(DOTFILES_ROOT, "scripts", "fix-hookify-imports.sh")),
      runMaintenanceScript("plugin-chmod-fix", hookPath("plugin-chmod-fix.sh")),
    ]

    if (mode === "full" && process.env.OPENCODE_DREAM_DISABLE !== "1") {
      startupTasks.push(runScript(dreamPath("count-session.sh"), undefined, {}, STARTUP_CONTEXT_TIMEOUT_MS))
    }

    if (mode === "full" && process.env.OPENCODE_BD_PRIME_DISABLE !== "1") {
      startupTasks.push(
        runCommand("bd", ["prime"], undefined, STARTUP_CONTEXT_TIMEOUT_MS).catch(() => ({ stdout: "", stderr: "", exitCode: 0 })),
      )
    }

    await Promise.all(startupTasks)

    const contextScripts = [
      hookPath("work-detect.sh"),
      hookPath("lsp-status.sh"),
    ]
    if (process.env.OPENCODE_PLAN_RESUME_DISABLE !== "1") {
      contextScripts.push(hookPath("plan-resume.sh"))
    }
    if (process.env.OPENCODE_CHANGELOG_RESUME_DISABLE !== "1") {
      contextScripts.push(hookPath("changelog-resume.sh"))
    }

    const contextResults = await Promise.all(
      contextScripts.map((script) => runScript(script, undefined, {}, STARTUP_CONTEXT_TIMEOUT_MS)),
    )
    for (const result of contextResults) {
      addContextResult(result)
    }
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
          messageTexts.clear()
          messageOrder.length = 0
          lastBridgeReviewedAssistant = ""
          await runScript(tmuxHookPath("tmux-agent-start.sh"), undefined, {}, STARTUP_FAST_TIMEOUT_MS)
          void collectSessionStartContext().catch(() => {})
          break
        }

        case "message.updated": {
          const info = event.properties.info as { id?: string; role?: string; modelID?: string }
          if (info?.id) {
            rememberMessage(info.id, info.role)
          }
          if (typeof info?.modelID === "string" && info.modelID) {
            currentOpenCodeModel = info.modelID
          }
          break
        }

        case "message.part.updated": {
          const { part } = event.properties
          if (part.type !== "text") {
            break
          }

          rememberMessage(part.messageID, undefined, part.text ?? "")

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
            runScript(hookPath("log-skill-invocation.py"), {
              hook_type: "UserPromptSubmit",
              session_id: currentSessionID ?? undefined,
              prompt,
              cwd: projectDir,
            }, { SKILL_INVOCATION_HARNESS: "opencode" }),
            appendPromptContext(prompt),
            appendPlanWatch({
              session_id: currentSessionID ?? undefined,
              tool_name: "UserPromptSubmit",
              tool_input: { prompt },
              prompt,
              cwd: projectDir,
            }, true),
          ])
          break
        }

        case "session.status": {
          if (event.properties.status.type === "idle") {
            await runScript(tmuxHookPath("tmux-agent-stop.sh"))
            await runOpenCodeBridgeReview()
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

        case "session.deleted": {
          handleShutdown()
          break
        }

        case "server.instance.disposed": {
          // Do not run Claude's tmux end hook for transient OpenCode server
          // disposal events; the wrapper cleanup handles real TUI exit.
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

      if (tool === "skill") {
        await runScript(hookPath("log-skill-invocation.py"), payload, { SKILL_INVOCATION_HARNESS: "opencode" })
      }

      if (isWriteTool(tool)) {
        await appendHookMessage(hookPath("auto-format.py"), payload)
        await appendHookMessage(hookPath("file-modified.sh"), payload)
        await appendHookMessage(hookPath("ci-lint-on-save.sh"), payload)
        await appendPlanWatch(payload, true)
      } else {
        await appendPlanWatch(payload)
      }
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

export default HarnessCompatPlugin
