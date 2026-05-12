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

commands = await runCase({ tool: "apply_patch", args: { patchText: `*** Begin Patch
*** Add File: /tmp/project/created-from-patch.txt
+hello
*** Update File: /tmp/project/updated-from-patch.txt
@@
-old
+new
*** Delete File: /tmp/project/deleted-from-patch.txt
*** End Patch` } })
if (!openCommands(commands).some((command) => command.includes("/tmp/project/created-from-patch.txt"))) {
  fail("apply_patch tool did not open added file from patchText")
}
if (!openCommands(commands).some((command) => command.includes("/tmp/project/updated-from-patch.txt"))) {
  fail("apply_patch tool did not open updated file from patchText")
}
if (openCommands(commands).some((command) => command.includes("/tmp/project/deleted-from-patch.txt"))) {
  fail("apply_patch tool should not open deleted file from patchText")
}

commands = await runCase({ tool: "patch", args: { patch: `*** Begin Patch
*** Update File: /tmp/project/old-name.txt
*** Move to: /tmp/project/new-name.txt
@@
-old
+new
*** End Patch` } })
if (!openCommands(commands).some((command) => command.includes("/tmp/project/new-name.txt"))) {
  fail("patch tool did not open moved file from patch payload")
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

OPEN_SCRIPT="$ROOT/scripts/nvim-open-file.sh"
FAKEBIN="$TMPDIR/fakebin"
TMUX_LOG="$TMPDIR/tmux.log"
export TMUX_LOG
mkdir -p "$FAKEBIN"

cat >"$FAKEBIN/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
if [ "$#" -gt 0 ]; then
	shift
fi

printf '%s\n' "$cmd $*" >>"$TMUX_LOG"

case "$cmd" in
display-message)
	target=""
	format=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-t)
			target="$2"
			shift 2
			;;
		-p)
			shift
			;;
		*)
			format="$1"
			shift
			;;
		esac
	done

	case "$format" in
	*session_name*)
		if [ "$target" = "%ai-pane" ]; then
			printf 'ai-session:7\n'
		else
			printf 'active-session:3\n'
		fi
		;;
	*pane_id*) printf '%s\n' "${target:-%active-pane}" ;;
	*pane_width*) printf '120\n' ;;
	*pane_height*) printf '30\n' ;;
	esac
	;;
list-panes | split-window) ;;
*) ;;
esac
EOF
chmod +x "$FAKEBIN/tmux"

cat >"$FAKEBIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKEBIN/pgrep"

: >"$TMUX_LOG"
PATH="$FAKEBIN:$PATH" \
    TMUX="/tmp/tmux-test,1,0" \
    TMUX_PANE="%ai-pane" \
    "$OPEN_SCRIPT" "$TMPDIR/created.txt" >/dev/null

if ! grep -Fq -- 'display-message -p -t %ai-pane #{session_name}:#{window_index}' "$TMUX_LOG"; then
    echo "FAIL nvim opener did not derive target window from TMUX_PANE" >&2
    exit 1
fi

if grep -Fq -- 'display-message -p #{session_name}:#{window_index}' "$TMUX_LOG"; then
    echo "FAIL nvim opener fell back to the active tmux window despite TMUX_PANE" >&2
    exit 1
fi

if ! grep -Fq -- 'split-window -h -c #{pane_current_path} -t %ai-pane' "$TMUX_LOG"; then
    echo "FAIL nvim opener did not split from the AI session pane" >&2
    exit 1
fi

echo "PASS OpenCode Neovim tmux target validation complete"
