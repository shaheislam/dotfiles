#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.opencode/plugins/entire.ts"

if ! command -v bun >/dev/null 2>&1; then
	echo "FAIL bun is required for Entire hook validation" >&2
	exit 1
fi

if [ ! -f "$PLUGIN" ]; then
	echo "FAIL missing plugin: $PLUGIN" >&2
	exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

HARNESS="$TMPDIR/harness.mjs"
cat >"$HARNESS" <<'EOF'
const pluginUrl = new URL(`file://${process.env.OPENCODE_ENTIRE_PLUGIN}`)
const { EntirePlugin } = await import(pluginUrl.href)

function fail(message) {
  console.error(`FAIL ${message}`)
  process.exit(1)
}

const calls = []

function hookNameFromCommand(cmd) {
  const shellCommand = Array.isArray(cmd) ? cmd.at(-1) : String(cmd)
  return shellCommand.trim().split(/\s+/).at(-1)
}

async function payloadFromStdin(stdin) {
  if (!stdin) return {}
  if (typeof stdin.text === "function") return JSON.parse(await stdin.text())
  return JSON.parse(new TextDecoder().decode(stdin))
}

Bun.spawn = (cmd, options = {}) => ({
  exited: (async () => {
    calls.push([hookNameFromCommand(cmd), await payloadFromStdin(options.stdin)])
    return 0
  })(),
})

Bun.spawnSync = (cmd, options = {}) => {
  calls.push([hookNameFromCommand(cmd), JSON.parse(new TextDecoder().decode(options.stdin))])
  return { exitCode: 0 }
}

const hooks = await EntirePlugin({
  directory: process.cwd(),
  worktree: process.cwd(),
  client: {},
  project: {},
  serverUrl: new URL("http://localhost"),
})

await hooks.event({ event: { type: "session.created", properties: { info: { id: "ses_1" } } } })
await hooks.event({ event: { type: "message.updated", properties: { info: { id: "msg_1", sessionID: "ses_1", role: "assistant", modelID: "gpt-5.4" } } } })
await hooks.event({ event: { type: "message.updated", properties: { info: { id: "msg_2", sessionID: "ses_1", role: "user" } } } })
await hooks.event({ event: { type: "message.part.updated", properties: { part: { messageID: "msg_2", type: "text", text: "hello" } } } })
await hooks.event({ event: { type: "session.status", properties: { sessionID: "ses_1", status: { type: "idle" } } } })
await hooks.event({ event: { type: "session.compacted", properties: { sessionID: "ses_1" } } })
await hooks.event({ event: { type: "server.instance.disposed", properties: {} } })

const hookNames = calls.map(([name]) => name)
for (const expected of ["session-start", "turn-start", "turn-end", "compaction", "session-end"]) {
  if (!hookNames.includes(expected)) {
    fail(`missing hook ${expected}`)
  }
}

const turnStart = calls.find(([name]) => name === "turn-start")?.[1]
if (turnStart?.prompt !== "hello" || turnStart?.model !== "gpt-5.4") {
  fail("turn-start payload missing prompt or model")
}

const turnEnd = calls.find(([name]) => name === "turn-end")?.[1]
if (turnEnd?.session_id !== "ses_1") {
  fail("turn-end payload missing session_id")
}

const sessionEnd = calls.find(([name]) => name === "session-end")?.[1]
if (sessionEnd?.session_id !== "ses_1") {
  fail("session-end payload missing session_id")
}

console.log("PASS entire session hooks")
console.log("PASS entire turn hooks")
console.log("PASS entire compaction hooks")
console.log("PASS entire hook validation complete")
EOF

OPENCODE_ENTIRE_PLUGIN="$PLUGIN" bun "$HARNESS"
