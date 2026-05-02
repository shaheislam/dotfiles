#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.config/opencode/plugin/nvim-open.ts"

if ! command -v bun >/dev/null 2>&1; then
	echo "FAIL bun is required for OpenCode Neovim opener validation" >&2
	exit 1
fi

if [ ! -f "$PLUGIN" ]; then
	echo "FAIL missing plugin: $PLUGIN" >&2
	exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'if [ "${OPENCODE_TEST_DEBUG:-0}" = "1" ]; then echo "DEBUG tmpdir preserved at $TMPDIR" >&2; else rm -rf "$TMPDIR"; fi' EXIT

HARNESS="$TMPDIR/harness.mjs"
cat >"$HARNESS" <<'EOF'
const pluginUrl = new URL(`file://${process.env.OPENCODE_NVIM_OPEN_PLUGIN}`)
const NvimOpenPlugin = (await import(pluginUrl.href)).default

function fail(message) {
  console.error(`FAIL ${message}`)
  process.exit(1)
}

function makeDollar({ sockets = "", mode = "" } = {}) {
  const commands = []
  const $ = (strings, ...values) => {
    const command = strings.reduce((acc, part, index) => `${acc}${part}${index < values.length ? values[index] : ""}`, "")
    commands.push(command)

    const chain = {
      quiet() {
        return chain
      },
      nothrow() {
        return chain
      },
      async text() {
        if (command.startsWith("ls /tmp/nvim.")) return sockets
        if (command.startsWith("nvim --server")) return mode
        return ""
      },
    }

    return chain
  }

  return { $, commands }
}

async function runCase(input, options = {}) {
  if (options.tmux === false) {
    delete process.env.TMUX
  } else {
    process.env.TMUX = "test-session"
  }

  const { $, commands } = makeDollar(options)
  const hooks = await NvimOpenPlugin({ $ })
  await hooks["tool.execute.after"](input)
  return commands
}

function openCommands(commands) {
  return commands.filter((command) => command.includes("scripts/nvim-open-file.sh"))
}

process.env.HOME = process.env.OPENCODE_TEST_HOME

let commands = await runCase({ tool: "write", args: { filePath: "/tmp/project/new.txt" } })
if (!openCommands(commands).some((command) => command.includes("/tmp/project/new.txt"))) {
  fail("write tool did not open created file")
}

commands = await runCase({ tool: "multiedit", args: { path: "/tmp/project/edited.txt" } })
if (!openCommands(commands).some((command) => command.includes("/tmp/project/edited.txt"))) {
  fail("multiedit tool did not open edited file from path arg")
}

commands = await runCase({ tool: "write", args: { filePath: "/tmp/project/skip/node_modules/pkg/index.js" } })
if (openCommands(commands).length !== 0) {
  fail("node_modules write should not open a Neovim buffer")
}

commands = await runCase({ tool: "edit", args: { file_path: "/tmp/project/insert-mode.txt" } }, {
  sockets: "/tmp/nvim.test/1/0\n",
  mode: "i",
})
if (openCommands(commands).length !== 0) {
  fail("insert-mode Neovim should not be interrupted")
}

commands = await runCase({ tool: "write", args: { filePath: "/tmp/project/no-tmux.txt" } }, { tmux: false })
if (commands.length !== 0) {
  fail("non-tmux OpenCode session should not try to open Neovim")
}

console.log("PASS OpenCode Neovim opener validation complete")
EOF

OPENCODE_NVIM_OPEN_PLUGIN="$PLUGIN" \
	OPENCODE_TEST_HOME="$TMPDIR/home" \
	bun "$HARNESS"
