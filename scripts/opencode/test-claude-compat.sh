#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.opencode/plugins/claude-compat.ts"

if ! command -v bun >/dev/null 2>&1; then
    echo "FAIL bun is required for Claude compat validation" >&2
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
const pluginUrl = new URL(`file://${process.env.OPENCODE_CLAUDE_COMPAT_PLUGIN}`)
const { ClaudeCompatPlugin } = await import(pluginUrl.href)

function fail(message) {
  console.error(`FAIL ${message}`)
  process.exit(1)
}

const hooks = await ClaudeCompatPlugin({
  directory: process.cwd(),
  worktree: process.cwd(),
  client: {},
  project: {},
  serverUrl: new URL("http://localhost"),
  $: undefined,
})

let npmBlocked = false
try {
  await hooks["tool.execute.before"](
    { tool: "bash", args: { command: "npm --version" } },
    { args: { command: "npm --version" } },
  )
} catch (error) {
  npmBlocked = String(error.message || error).includes("bun/bunx")
}

if (!npmBlocked) {
  fail("npm command was not blocked")
}

let settingsBlocked = false
try {
  await hooks["tool.execute.before"](
    { tool: "write", args: { filePath: `${process.cwd()}/.claude/settings.json` } },
    { args: { filePath: `${process.cwd()}/.claude/settings.json` } },
  )
} catch (error) {
  settingsBlocked = String(error.message || error).toLowerCase().includes("settings")
}

if (!settingsBlocked) {
  fail("settings redirect hook did not block direct writes")
}

await hooks["tool.execute.after"](
  { tool: "read", args: { filePath: `${process.cwd()}/fake.py` } },
  { output: "print('hello')" },
)

const transformOutput = { system: [] }
await hooks["experimental.chat.system.transform"]({}, transformOutput)

if (!transformOutput.system.some((entry) => entry.toLowerCase().includes("deepwiki"))) {
  fail("read hook did not inject DeepWiki guidance")
}

console.log("PASS npm guard")
console.log("PASS settings guard")
console.log("PASS read context injection")
console.log("PASS claude compat validation complete")
EOF

OPENCODE_CLAUDE_COMPAT_PLUGIN="$PLUGIN" bun "$HARNESS"
