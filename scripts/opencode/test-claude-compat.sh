#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.config/opencode/plugin/claude-compat.ts"

if ! command -v bun >/dev/null 2>&1; then
	echo "FAIL bun is required for Claude compat validation" >&2
	exit 1
fi

if [ ! -f "$PLUGIN" ]; then
	echo "FAIL missing plugin: $PLUGIN" >&2
	exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'if [ "${OPENCODE_TEST_DEBUG:-0}" = "1" ]; then echo "DEBUG tmpdir preserved at $TMPDIR" >&2; else rm -rf "$TMPDIR"; fi' EXIT

TEST_HOME="$TMPDIR/home"
TEST_PROJECT="$TMPDIR/project"
mkdir -p "$TEST_HOME" "$TEST_PROJECT/scripts/harness" "$TEST_PROJECT/.claude" "$TEST_HOME/obsidian" "$TMPDIR/bin"
mkdir -p "$TEST_HOME/.claude"
mkdir -p "$TMPDIR/jfdi/scripts"
printf '{}\n' >"$TEST_HOME/.claude/settings.json"
cat >"$TEST_PROJECT/.plan.md" <<'EOF'
## Objective
Validate OpenCode shutdown synthesis.

## Progress
- Synthetic harness setup complete.
EOF
cat >"$TEST_PROJECT/.claude/CHANGELOG.md" <<'EOF'
# Session Changelog

[2026-03-30T00:00:00Z] DISCOVERY: OpenCode changelog parity test entry.
EOF
ln -s "$ROOT" "$TEST_HOME/dotfiles"

cat >"$TEST_PROJECT/scripts/harness/session-report.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '{"ok":true}\n' >"${TEST_SESSION_REPORT_OUTPUT:?}"
EOF
chmod +x "$TEST_PROJECT/scripts/harness/session-report.sh"

cat >"$TMPDIR/jfdi/scripts/sync-sessions.ts" <<'EOF'
// stub
EOF
cat >"$TMPDIR/jfdi/scripts/sync-obsidian.ts" <<'EOF'
// stub
EOF
cat >"$TMPDIR/jfdi/scripts/extract-memories.ts" <<'EOF'
// stub
EOF
cat >"$TMPDIR/jfdi/scripts/weekly-synthesis.ts" <<'EOF'
// stub
EOF

cat >"$TMPDIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'MARKDOWN'
---
type: session-synthesis
session_id: test-session
date: 2026-03-30
project: test-project
title: Test Session
---

# Session
Synthetic output
MARKDOWN
EOF
chmod +x "$TMPDIR/bin/claude"

cat >"$TMPDIR/bin/bunx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TEST_JFDI_OUTPUT:?}"
EOF
chmod +x "$TMPDIR/bin/bunx"

cat >"$TMPDIR/bin/osascript" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TEST_OSASCRIPT_OUTPUT:?}"
EOF
chmod +x "$TMPDIR/bin/osascript"

cat >"$TMPDIR/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "run" ]; then
	shift
	model=""
	if [ "${1:-}" = "--model" ]; then
		model="${2:-}"
		shift 2
	fi
	printf '%s\n' "$model" >"${TEST_OPENCODE_BRIDGE_MODEL_OUTPUT:?}"
	printf 'CONCERNS: synthetic bridge concern from %s\n' "$model"
	exit 0
fi
printf 'unexpected opencode invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$TMPDIR/bin/opencode"

cat >"$TMPDIR/bin/opencode-preflight" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$TMPDIR/bin/opencode-preflight"

cat >"$TMPDIR/bin/timeout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift
exec "$@"
EOF
chmod +x "$TMPDIR/bin/timeout"

HARNESS="$TMPDIR/harness.mjs"
cat >"$HARNESS" <<'EOF'
const pluginUrl = new URL(`file://${process.env.OPENCODE_CLAUDE_COMPAT_PLUGIN}`)
const { ClaudeCompatPlugin } = await import(pluginUrl.href)

function fail(message) {
  console.error(`FAIL ${message}`)
  process.exit(1)
}

const projectDir = process.env.OPENCODE_TEST_PROJECT

const hooks = await ClaudeCompatPlugin({
  directory: projectDir,
  worktree: projectDir,
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
    { tool: "write", args: { filePath: `${process.env.HOME}/.claude/settings.json` } },
    { args: { filePath: `${process.env.HOME}/.claude/settings.json` } },
  )
} catch (error) {
  settingsBlocked = String(error.message || error).toLowerCase().includes("settings")
}

if (!settingsBlocked) {
  fail("settings redirect hook did not block direct writes")
}

let protectedBlocked = false
try {
  await hooks["tool.execute.before"](
    { tool: "write", args: { filePath: `${projectDir}/package-lock.json` } },
    { args: { filePath: `${projectDir}/package-lock.json` } },
  )
} catch (error) {
  protectedBlocked = String(error.message || error).toLowerCase().includes("protected file")
}

if (!protectedBlocked) {
  fail("protect-files hook did not block protected writes")
}

let protectedPatchBlocked = false
try {
  await hooks["tool.execute.before"](
    { tool: "apply_patch", args: { patchText: `*** Begin Patch
*** Update File: ${projectDir}/package-lock.json
@@
-{}
+{"blocked":true}
*** End Patch` } },
    { args: { patchText: `*** Begin Patch
*** Update File: ${projectDir}/package-lock.json
@@
-{}
+{"blocked":true}
*** End Patch` } },
  )
} catch (error) {
  protectedPatchBlocked = String(error.message || error).toLowerCase().includes("protected file")
}

if (!protectedPatchBlocked) {
  fail("protect-files hook did not block protected apply_patch writes")
}

await hooks["tool.execute.after"](
  { tool: "read", args: { filePath: `${projectDir}/fake.py` } },
  { output: "print('hello')" },
)

const transformOutput = { system: [] }
await hooks["experimental.chat.system.transform"]({}, transformOutput)

if (!transformOutput.system.some((entry) => entry.toLowerCase().includes("deepwiki"))) {
  fail("read hook did not inject DeepWiki guidance")
}

await hooks.event({ event: { type: "session.created", properties: { info: { id: "ses_test" } } } })

const sessionTransform = { system: [] }
await hooks["experimental.chat.system.transform"]({}, sessionTransform)
if (!sessionTransform.system.some((entry) => entry.includes("OpenCode changelog parity test entry"))) {
  fail("session start did not inject changelog context")
}

const compactOutput = { context: [] }
await hooks["experimental.session.compacting"]({}, compactOutput)
if (!compactOutput.context.some((entry) => entry.includes("OpenCode changelog parity test entry"))) {
  fail("compaction did not persist changelog context")
}

await hooks["tool.execute.error"](
  { tool: "bash", args: { command: "false" } },
  { error: "synthetic tool failure" },
)

await hooks.event({ event: { type: "message.updated", properties: { info: { id: "assistant-1", role: "assistant", modelID: "openai/gpt-5.5" } } } })
await hooks.event({ event: { type: "message.part.updated", properties: { part: { type: "text", messageID: "assistant-1", text: "Implemented synthetic bridge target." } } } })
await hooks.event({ event: { type: "session.status", properties: { status: { type: "idle" } } } })

const bridgeTransform = { system: [] }
await hooks["experimental.chat.system.transform"]({}, bridgeTransform)
if (!bridgeTransform.system.some((entry) => entry.includes("synthetic bridge concern"))) {
  fail("OpenCode bridge did not inject adversarial review context")
}

await hooks.event({ event: { type: "tui.toast.show", properties: { title: "Test", message: "toast", variant: "info" } } })
await hooks.event({ event: { type: "server.instance.disposed", properties: {} } })

console.log("PASS npm guard")
console.log("PASS settings guard")
console.log("PASS protected file guard")
console.log("PASS read context injection")
console.log("PASS changelog context")
console.log("PASS tool failure logging")
console.log("PASS adversarial bridge context")
console.log("PASS shutdown hooks")
console.log("PASS claude compat validation complete")
EOF

OPENCODE_CLAUDE_COMPAT_PLUGIN="$PLUGIN" \
	OPENCODE_TEST_PROJECT="$TEST_PROJECT" \
	TEST_SESSION_REPORT_OUTPUT="$TMPDIR/session-report.json" \
	TEST_JFDI_OUTPUT="$TMPDIR/jfdi.log" \
	TEST_OSASCRIPT_OUTPUT="$TMPDIR/osascript.log" \
	TEST_OPENCODE_BRIDGE_MODEL_OUTPUT="$TMPDIR/opencode-bridge-model.log" \
	OPENCODE_JFDI_PROJECT_DIR="$TMPDIR/jfdi" \
	OPENCODE_CROSS_PROVIDER_BRIDGE=1 \
	OPENCODE_BRIDGE_TIMEOUT=5 \
	CROSS_PROVIDER_OPENCODE_PREFLIGHT="$TMPDIR/bin/opencode-preflight" \
	PATH="$TMPDIR/bin:$PATH" \
	HOME="$TEST_HOME" \
	bun "$HARNESS"

grep -q 'anthropic/claude-opus-4-6' "$TMPDIR/opencode-bridge-model.log" || {
	echo "FAIL OpenCode bridge did not choose Anthropic reviewer for OpenAI executor" >&2
	exit 1
}

grep -R -q 'synthetic tool failure' "$TEST_HOME/.claude/hooks/logs" || {
	echo "FAIL tool failure hook did not write failure log" >&2
	exit 1
}

grep -q 'display notification' "$TMPDIR/osascript.log" || {
	echo "FAIL macOS notification hook was not invoked" >&2
	exit 1
}

[ -f "$TMPDIR/session-report.json" ] || {
	echo "FAIL shutdown hook did not write session report" >&2
	exit 1
}

obsidian_count="$(find "$TEST_HOME/obsidian/Claude/Sessions" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
[ "$obsidian_count" -ge 1 ] || {
	echo "FAIL shutdown hook did not synthesize an Obsidian session note" >&2
	exit 1
}

grep -q 'tsx scripts/sync-sessions.ts' "$TMPDIR/jfdi.log" || {
	echo "FAIL shutdown hook did not trigger JFDI session sync" >&2
	exit 1
}

grep -q 'tsx scripts/extract-memories.ts --limit 3' "$TMPDIR/jfdi.log" || {
	echo "FAIL shutdown hook did not trigger JFDI memory extraction" >&2
	exit 1
}

grep -q 'tsx scripts/weekly-synthesis.ts --week ' "$TMPDIR/jfdi.log" || {
	echo "FAIL shutdown hook did not trigger weekly JFDI synthesis" >&2
	exit 1
}
