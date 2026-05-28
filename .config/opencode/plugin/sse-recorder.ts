// OpenCode plugin: capture SSE events for Entire + Diffview integration
// Writes a JSONL log for all events and persists diff snapshots so
// Diffview (inside Neovim) can replay or inspect AI edits later.
// Also mirrors summarized payloads into Entire hooks for checkpoints.
import type { Plugin } from "@opencode-ai/plugin"
import path from "node:path"
import { mkdir, appendFile, writeFile } from "node:fs/promises"
import { spawn } from "node:child_process"
import crypto from "node:crypto"

type OpencodeEvent = {
  type?: string
  timestamp?: string
  properties?: Record<string, any>
}

type NormalizedEvent = {
  type: string
  timestamp: string
  session_id: string | null
  message_id: string | null
  model: string | null
  summary: Record<string, unknown>
}

const DIFF_KEYS = [
  "patch",
  "diff",
  "content",
  "text",
  "body",
  "hunks",
]

const DEFAULT_RECORDED_PREFIXES = [
  "session.",
  "tool.",
  "permission.",
  "message.patch.",
  "file.",
]

const DEFAULT_RECORDED_EVENTS = new Set([
  "message.updated",
  "server.instance.disposed",
  "tui.toast.show",
])

function looksLikeDiff(candidate: unknown): candidate is string {
  if (typeof candidate !== "string") return false
  const trimmed = candidate.trimStart()
  if (!trimmed) return false
  return (
    trimmed.startsWith("diff --git") ||
    trimmed.startsWith("@@") ||
    trimmed.startsWith("--- ") ||
    trimmed.includes("\n@@")
  )
}

function searchForDiff(value: unknown): string | null {
  if (!value) return null
  if (looksLikeDiff(value)) return value
  if (Array.isArray(value)) {
    for (const entry of value) {
      const diff = searchForDiff(entry)
      if (diff) return diff
    }
    return null
  }
  if (typeof value === "object") {
    for (const key of Object.keys(value as Record<string, unknown>)) {
      if (!DIFF_KEYS.includes(key) && typeof (value as any)[key] !== "object") {
        continue
      }
      const diff = searchForDiff((value as any)[key])
      if (diff) return diff
    }
  }
  return null
}

function sanitizeProperties(props: Record<string, unknown> | undefined) {
  if (!props) return {}
  const clone = JSON.parse(JSON.stringify(props))
  const diff = searchForDiff(clone)
  if (diff && diff.length > 2048) {
    ;(clone as any).diff_preview = `${diff.slice(0, 1024)}…`
  }
  return clone
}

function extractTarget(props: Record<string, unknown> | undefined): string | null {
  if (!props) return null
  const candidates = [
    props.path,
    props.file,
    props.filepath,
    props.target,
    props.targetPath,
    props.location,
    props?.info?.path,
    props?.info?.file,
  ]
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim().length > 0) {
      return candidate
    }
  }
  return null
}

function slugify(value: string | null) {
  if (!value) return "workspace"
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40) || "workspace"
}

async function writeJsonl(filePath: string, payload: NormalizedEvent) {
  await appendFile(filePath, `${JSON.stringify(payload)}\n`, "utf8")
}

function callEntireHook(hook: string, payload: Record<string, unknown>) {
  if (process.env.OPENCODE_SSE_DISABLE_ENTIRE === "1" || process.env.OPENCODE_SSE_ENTIRE !== "1") {
    return Promise.resolve()
  }
  return new Promise<void>((resolve) => {
    let child: ReturnType<typeof spawn> | null = null
    try {
      child = spawn("entire", ["hooks", "opencode", hook], {
        stdio: ["pipe", "ignore", "ignore"],
      })
    } catch {
      resolve()
      return
    }
    child.on("error", () => resolve())
    if (!child.stdin) {
      resolve()
      return
    }
    child.stdin.write(`${JSON.stringify(payload)}\n`)
    child.stdin.end()
    child.on("close", () => resolve())
  })
}

function shouldRecordEvent(type: string) {
  if (process.env.OPENCODE_SSE_FULL === "1") return true
  if (DEFAULT_RECORDED_EVENTS.has(type)) return true
  return DEFAULT_RECORDED_PREFIXES.some((prefix) => type.startsWith(prefix))
}

function normalizeEvent(event: OpencodeEvent): NormalizedEvent {
  const props = event.properties ?? {}
  const timestamp = event.timestamp ?? new Date().toISOString()
  const sessionID =
    props.sessionID ??
    props.info?.sessionID ??
    props.permission?.sessionID ??
    props.request?.sessionID ??
    null
  const model =
    props.modelID ??
    props.info?.modelID ??
    props.meta?.model ??
    null
  const messageID =
    props.messageID ??
    props.info?.id ??
    props.permission?.messageID ??
    null

  return {
    type: event.type ?? "unknown",
    timestamp,
    session_id: sessionID,
    message_id: messageID,
    model,
    summary: sanitizeProperties(props),
  }
}

async function writeDiffSnapshot(
  baseDir: string,
  event: NormalizedEvent,
  diff: string,
  fileHint: string | null,
) {
  await mkdir(baseDir, { recursive: true })
  const slug = slugify(fileHint)
  const stamp = event.timestamp.replace(/[:.]/g, "-")
  const id = crypto.randomUUID().slice(0, 8)
  const filename = `${stamp}-${slug}-${id}.patch`
  const diffPath = path.join(baseDir, filename)
  const metaPath = `${diffPath}.json`
  await writeFile(diffPath, diff, "utf8")
  await writeFile(
    metaPath,
    JSON.stringify(
      {
        type: event.type,
        timestamp: event.timestamp,
        session_id: event.session_id,
        message_id: event.message_id,
        model: event.model,
        target: fileHint,
      },
      null,
      2,
    ),
    "utf8",
  )
  await callEntireHook("sse-diff", {
    session_id: event.session_id,
    message_id: event.message_id,
    file: fileHint,
    diff_path: diffPath,
  })
}

export const OpencodeSseRecorderPlugin: Plugin = async ({ directory }) => {
  const rootOverride = process.env.OPENCODE_SSE_ROOT
  const repoRoot = rootOverride ? path.resolve(rootOverride) : directory
  const logDir = path.join(repoRoot, ".entire", "opencode", "sse")
  const diffDir = path.join(logDir, "diffs")
  const eventLogPath = path.join(logDir, "events.jsonl")
  await mkdir(diffDir, { recursive: true })

  return {
    event: async ({ event }) => {
      if (!event) return
      const eventType = (event as OpencodeEvent).type ?? "unknown"
      if (!shouldRecordEvent(eventType)) return

      const normalized = normalizeEvent(event as OpencodeEvent)
      await writeJsonl(eventLogPath, normalized)
      await callEntireHook("sse-event", normalized)

      const diff = searchForDiff(event.properties)
      if (diff) {
        const target = extractTarget(event.properties)
        await writeDiffSnapshot(diffDir, normalized, diff, target)
      }
    },
  }
}
