#!/usr/bin/env bun
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import assert from "node:assert/strict"
import { OpencodeSseRecorderPlugin } from "../../.opencode/plugins/sse-recorder"

async function run() {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "opencode-sse-test-"))
  process.env.OPENCODE_SSE_ROOT = tmp
  process.env.OPENCODE_SSE_DISABLE_ENTIRE = "1"

  const plugin = await OpencodeSseRecorderPlugin({ directory: tmp } as any)

  const diffEvent = {
    type: "message.patch.created",
    timestamp: "2025-01-01T00:00:00.000Z",
    properties: {
      sessionID: "session-123",
      messageID: "msg-1",
      path: "src/example.ts",
      patch: [
        "diff --git a/src/example.ts b/src/example.ts",
        "index 1111111..2222222 100644",
        "--- a/src/example.ts",
        "+++ b/src/example.ts",
        "@@",
        "-console.log('old')",
        "+console.log('new')",
      ].join("\n"),
    },
  }

  const statusEvent = {
    type: "session.status",
    properties: {
      sessionID: "session-123",
      status: { type: "idle" },
    },
  }

  await plugin.event({ event: diffEvent } as any)
  await plugin.event({ event: statusEvent } as any)

  const logPath = path.join(tmp, ".entire", "opencode", "sse", "events.jsonl")
  const logContent = await readFile(logPath, "utf8")
  const lines = logContent.trim().split("\n")
  assert.equal(lines.length, 2, "SSE log should contain two entries")

  const diffDir = path.join(tmp, ".entire", "opencode", "sse", "diffs")
  const diffFiles = (await readdir(diffDir)).filter((file) => file.endsWith(".patch"))
  assert.ok(diffFiles.length >= 1, "Diff directory should contain at least one snapshot")
  const diffPath = path.join(diffDir, diffFiles[0])
  const patchContent = await readFile(diffPath, "utf8")
  assert.ok(patchContent.includes("console.log"), "Diff snapshot should contain patch text")

  const meta = JSON.parse(await readFile(`${diffPath}.json`, "utf8"))
  assert.equal(meta.target, "src/example.ts")
  assert.equal(meta.session_id, "session-123")

  console.log("PASS sse-recorder plugin harness")
  await rm(tmp, { recursive: true, force: true })
}

run().catch((error) => {
  console.error("FAIL sse-recorder plugin harness")
  console.error(error)
  process.exitCode = 1
})
