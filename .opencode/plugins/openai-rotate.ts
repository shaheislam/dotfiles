import { existsSync } from "node:fs"
import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises"
import { join } from "node:path"
import type { Part, UserMessage } from "@opencode-ai/sdk"
import type { Plugin } from "@opencode-ai/plugin"

type OpenAIAuth = {
  access?: string
  accountId?: string
  expires?: number
}

type AuthFile = {
  openai?: OpenAIAuth
  [key: string]: unknown
}

export type PromptState = {
  messageID: string
  agent: string
  model: {
    providerID: string
    modelID: string
  }
  format?: UserMessage["format"]
  system?: string
  tools?: UserMessage["tools"]
  variant?: string
  parts: Part[]
}

type RotationResult =
  | { ok: true; name: string }
  | { ok: false; reason: string }

const HOME = process.env.HOME || ""
const DOTFILES_ROOT = process.env.DOTFILES_ROOT || join(HOME, "dotfiles")
const AUTH_FILE = process.env.OPENCODE_AUTH_FILE || join(HOME, ".local", "share", "opencode", "auth.json")
const ACCOUNTS_DIR = process.env.OPENCODE_ACCOUNTS_DIR || join(HOME, ".opencode", "accounts")
const ACCOUNTS_FILE = join(ACCOUNTS_DIR, ".accounts")
const CURRENT_FILE = join(ACCOUNTS_DIR, ".current")
const USAGE_CHECK_SCRIPT = process.env.OPENCODE_USAGE_CHECK_SCRIPT || join(DOTFILES_ROOT, "scripts", "opencode", "usage-check.sh")
const DEBUG_LOG = process.env.OPENCODE_ROTATE_DEBUG_LOG

async function debugLog(message: string) {
  if (!DEBUG_LOG) {
    return
  }

  await appendFile(DEBUG_LOG, `${message}\n`)
}

function isOpenAIUsageLimit(error: unknown) {
  if (!error || typeof error !== "object") {
    return false
  }

  const candidate = error as {
    name?: string
    message?: string
    statusCode?: number
    url?: string
    responseBody?: string
    data?: {
      statusCode?: number
      message?: string
      providerID?: string
      responseBody?: string
    }
  }

  const text = [candidate.message, candidate.responseBody, candidate.data?.message, candidate.data?.responseBody]
    .filter(Boolean)
    .join("\n")
    .toLowerCase()
  const providerID = candidate.data?.providerID
  const statusCode = candidate.statusCode ?? candidate.data?.statusCode

  if (candidate.name === "ProviderAuthError" && providerID !== "openai") {
    return false
  }

  if (providerID && providerID !== "openai") {
    return false
  }

  if (candidate.url && !candidate.url.includes("/v1/")) {
    return false
  }

  if (statusCode === 429) {
    return true
  }

  return /(usage\.limit|rate_limit|limit.*reached|exceeded.*quota|insufficient_quota|too many requests)/.test(text)
}

function authKey(auth?: OpenAIAuth) {
  if (!auth) {
    return ""
  }
  return auth.accountId || auth.access || ""
}

function sanitizeAccountName(name: string) {
  return name.replace(/[^a-zA-Z0-9_-]/g, "-")
}

async function readJsonFile<T>(filePath: string): Promise<T | null> {
  if (!existsSync(filePath)) {
    return null
  }

  try {
    return JSON.parse(await readFile(filePath, "utf8")) as T
  } catch {
    return null
  }
}

async function writeJsonFile(filePath: string, value: unknown) {
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8")
}

async function readAccountNames() {
  if (!existsSync(ACCOUNTS_FILE)) {
    return [] as string[]
  }

  const raw = await readFile(ACCOUNTS_FILE, "utf8")
  return raw
    .split(/\r?\n/)
    .map((entry) => entry.trim())
    .filter(Boolean)
}

async function ensureCurrentAccountSaved(currentAuth: OpenAIAuth | undefined, accountNames: string[]) {
  if (!currentAuth) {
    return accountNames
  }

  const currentKey = authKey(currentAuth)
  if (!currentKey) {
    return accountNames
  }

  for (const name of accountNames) {
    const saved = await readJsonFile<OpenAIAuth>(join(ACCOUNTS_DIR, name, "openai-auth.json"))
    if (authKey(saved) === currentKey) {
      return accountNames
    }
  }

  const autoName = sanitizeAccountName(`auto-${Date.now()}`)
  const autoDir = join(ACCOUNTS_DIR, autoName)
  await mkdir(autoDir, { recursive: true })
  await writeJsonFile(join(autoDir, "openai-auth.json"), currentAuth)
  await writeFile(ACCOUNTS_FILE, `${[...accountNames, autoName].join("\n")}\n`, "utf8")
  return [...accountNames, autoName]
}

function rotateFrom(names: string[], currentName: string | null) {
  if (names.length === 0) {
    return names
  }

  if (!currentName) {
    return names
  }

  const index = names.indexOf(currentName)
  if (index === -1) {
    return names
  }

  return [...names.slice(index + 1), ...names.slice(0, index + 1)]
}

async function probeToken(token: string) {
  if (!existsSync(USAGE_CHECK_SCRIPT)) {
    return 2
  }

  const cwd = existsSync(DOTFILES_ROOT) ? DOTFILES_ROOT : HOME || "."

  const proc = Bun.spawn([USAGE_CHECK_SCRIPT, "--quiet", "--token", token], {
    cwd,
    stdout: "ignore",
    stderr: "ignore",
  })

  return await proc.exited
}

async function switchAccount(name: string, openai: OpenAIAuth) {
  const auth = (await readJsonFile<AuthFile>(AUTH_FILE)) || {}
  auth.openai = openai
  await writeJsonFile(AUTH_FILE, auth)

  const names = await readAccountNames()
  const index = names.indexOf(name)
  if (index >= 0) {
    await writeFile(CURRENT_FILE, `${index}\n`, "utf8")
  }
}

export function toPromptParts(parts: Part[]) {
  return parts.flatMap((part) => {
    switch (part.type) {
      case "text":
        return [{
          id: part.id,
          type: "text" as const,
          text: part.text,
        }]
      case "file":
        return [{
          id: part.id,
          type: "file" as const,
          mime: part.mime,
          filename: part.filename,
          url: part.url,
        }]
      case "agent":
        return [{
          id: part.id,
          type: "agent" as const,
          name: part.name,
        }]
      case "subtask":
        return [{
          id: part.id,
          type: "subtask" as const,
          prompt: part.prompt,
          description: part.description,
          agent: part.agent,
          model: part.model,
          command: part.command,
        }]
      default:
        return []
    }
  })
}

export const OpenAIRotatePlugin: Plugin = async ({ client, directory }) => {
  const pendingPrompts = new Map<string, PromptState>()
  const handledMessages = new Set<string>()
  const rotatingSessions = new Set<string>()

  async function showToast(message: string, variant: "info" | "success" | "warning" | "error") {
    try {
      await client.tui.showToast({
        query: { directory },
        body: {
          title: "OpenAI rotation",
          message,
          variant,
          duration: 6000,
        },
      })
    } catch {
      // Headless runs or unavailable TUI endpoints are fine.
    }
  }

  async function rotateAccount(): Promise<RotationResult> {
    await debugLog(`rotateAccount authFile=${AUTH_FILE}`)
    const auth = await readJsonFile<AuthFile>(AUTH_FILE)
    if (!auth?.openai) {
      return { ok: false, reason: "No active OpenAI auth found" }
    }

    await mkdir(ACCOUNTS_DIR, { recursive: true })
    await debugLog(`rotateAccount accountsDir=${ACCOUNTS_DIR}`)

    const accountNames = await ensureCurrentAccountSaved(auth.openai, await readAccountNames())
    await debugLog(`rotateAccount names=${accountNames.join(",")}`)
    if (accountNames.length === 0) {
      return { ok: false, reason: "No saved OpenAI accounts are available" }
    }

    const currentKey = authKey(auth.openai)

    let activeName: string | null = null
    for (const name of accountNames) {
      const saved = await readJsonFile<OpenAIAuth>(join(ACCOUNTS_DIR, name, "openai-auth.json"))
      if (authKey(saved) === currentKey) {
        activeName = name
        await debugLog(`rotateAccount active=${name}`)
        break
      }
    }

    for (const name of rotateFrom(accountNames, activeName)) {
      const saved = await readJsonFile<OpenAIAuth>(join(ACCOUNTS_DIR, name, "openai-auth.json"))
      if (!saved?.access || authKey(saved) === currentKey) {
        await debugLog(`rotateAccount skip=${name}`)
        continue
      }

      const status = await probeToken(saved.access)
      await debugLog(`rotateAccount probe=${name} status=${status}`)
      if (status !== 0) {
        continue
      }

      await switchAccount(name, saved)
      await debugLog(`rotateAccount switched=${name}`)
      return { ok: true, name }
    }

    return { ok: false, reason: "All saved OpenAI accounts are currently unavailable" }
  }

  function buildReplayBody(pending: PromptState) {
    return {
      parts: toPromptParts(pending.parts),
      ...(pending.agent ? { agent: pending.agent } : {}),
      ...(pending.model ? { model: pending.model } : {}),
      ...(pending.format ? { format: pending.format } : {}),
      ...(pending.system ? { system: pending.system } : {}),
      ...(pending.tools ? { tools: pending.tools } : {}),
      ...(pending.variant ? { variant: pending.variant } : {}),
    }
  }

  return {
    "chat.message": async (input, output) => {
      await debugLog(`chat.message provider=${output.message.model.providerID} message=${output.message.id}`)
      if (output.message.model.providerID !== "openai") {
        pendingPrompts.delete(input.sessionID)
        return
      }

      pendingPrompts.set(input.sessionID, {
        messageID: output.message.id,
        agent: output.message.agent,
        model: output.message.model,
        format: output.message.format,
        system: output.message.system,
        tools: output.message.tools,
        variant: output.message.variant,
        parts: structuredClone(output.parts),
      })
      handledMessages.delete(output.message.id)
    },

    event: async ({ event }) => {
      await debugLog(`event type=${event.type}`)
      if (event.type === "message.updated" && event.properties.info.role === "assistant") {
        await debugLog(`message.updated assistant error=${Boolean(event.properties.info.error)} parent=${event.properties.info.parentID || ""}`)
        if (!event.properties.info.error) {
          const pending = pendingPrompts.get(event.properties.info.sessionID)
          if (pending && pending.messageID === event.properties.info.parentID) {
            pendingPrompts.delete(event.properties.info.sessionID)
            handledMessages.delete(pending.messageID)
          }
        }
        return
      }

      if (event.type !== "session.error") {
        return
      }

      const sessionID = event.properties.sessionID
      if (!sessionID || rotatingSessions.has(sessionID)) {
        return
      }

      const pending = pendingPrompts.get(sessionID)
      await debugLog(`session.error pending=${Boolean(pending)} session=${sessionID}`)
      if (!pending || pending.model.providerID !== "openai") {
        return
      }

      if (handledMessages.has(pending.messageID)) {
        return
      }

      if (!isOpenAIUsageLimit(event.properties.error)) {
        await debugLog("session.error ignored by usage-limit detector")
        return
      }

      rotatingSessions.add(sessionID)

      try {
        const result = await rotateAccount()
        await debugLog(`rotation result ok=${result.ok}`)
        if (!result.ok) {
          handledMessages.add(pending.messageID)
          await showToast(`${result.reason}. Save another account with opencode-accounts.`, "error")
          return
        }

        handledMessages.add(pending.messageID)
        await showToast(`Switched to '${result.name}' and retrying the last prompt.`, "warning")

        const body = buildReplayBody(pending)

        await client.session.prompt({
          path: { sessionID },
          query: { directory },
          body,
        })
      } catch (error) {
        await debugLog(`rotation exception=${String(error)}`)
        throw error
      } finally {
        rotatingSessions.delete(sessionID)
      }
    },
  }
}
