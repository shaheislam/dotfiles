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

function makeCommand(strings, ...values) {
  const hookName = values[2]
  const payload = JSON.parse(values[0])
  return {
    quiet() { return this },
    nothrow: async () => {
      calls.push([hookName, payload])
    },
  }
}

const hooks = await EntirePlugin({
  directory: process.cwd(),
  worktree: process.cwd(),
  client: {},
  project: {},
  serverUrl: new URL("http://localhost"),
  $: makeCommand,
})

await hooks.event({ event: { type: "session.created", properties: { info: { id: "ses_1" } } } })
await hooks.event({ event: { type: "todo.updated", properties: { sessionID: "ses_1", todos: [{ content: "A", status: "pending", priority: "high" }] } } })
await hooks.event({ event: { type: "command.executed", properties: { sessionID: "ses_1", name: "review", arguments: "--fast", messageID: "msg_1" } } })
await hooks.event({ event: { type: "worktree.ready", properties: { name: "feat-test", branch: "feature/test" } } })
await hooks.event({ event: { type: "worktree.failed", properties: { message: "cleanup needed" } } })

await hooks["tool.execute.before"](
  { tool: "task", args: { description: "run subagent", prompt: "/check", subagent_type: "explore" } },
  { args: { description: "run subagent", prompt: "/check", subagent_type: "explore" } },
)

await hooks["tool.execute.after"](
  { tool: "task", args: { description: "run subagent", prompt: "/check", subagent_type: "explore" } },
  { output: "done" },
)

await hooks["tool.execute.after"](
  { tool: "todowrite", args: { todos: [{ content: "B", status: "completed", priority: "medium" }] } },
  { output: "ok" },
)

const hookNames = calls.map(([name]) => name)
for (const expected of ["session-start", "post-todo", "post-task", "worktree-create", "worktree-remove", "pre-task"]) {
  if (!hookNames.includes(expected)) {
    fail(`missing hook ${expected}`)
  }
}

const preTask = calls.find(([name]) => name === "pre-task")?.[1]
if (preTask?.subagent_type !== "explore") {
  fail("pre-task payload missing subagent_type")
}

const worktreeCreate = calls.find(([name]) => name === "worktree-create")?.[1]
if (worktreeCreate?.branch !== "feature/test") {
  fail("worktree-create payload missing branch")
}

const postTodoCalls = calls.filter(([name]) => name === "post-todo")
if (postTodoCalls.length < 2) {
  fail("expected post-todo to fire for todo.updated and todowrite")
}

console.log("PASS entire session hooks")
console.log("PASS entire todo hooks")
console.log("PASS entire task hooks")
console.log("PASS entire worktree hooks")
console.log("PASS entire hook validation complete")
EOF

OPENCODE_ENTIRE_PLUGIN="$PLUGIN" bun "$HARNESS"
