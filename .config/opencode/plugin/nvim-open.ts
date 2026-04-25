import type { Plugin } from "@opencode-ai/plugin"

declare const process: { env: Record<string, string | undefined> }

const SKIP = [
  /[\\/]node_modules[\\/]/,
  /[\\/]dist[\\/]/,
  /[\\/]\.git[\\/]/,
  /[\\/]\.beads[\\/]/,
  /[\\/]__pycache__[\\/]/,
  /[\\/]\.direnv[\\/]/,
  /[\\/]\.next[\\/]/,
  /[\\/]\.cache[\\/]/,
  /\.(lock|pyc)$/,
  /[\\/]package-lock\.json$/,
]

const HANDLED = new Set(["write", "edit", "multiedit"])

const NvimOpenPlugin: Plugin = async ({ $ }) => ({
  "tool.execute.after": async (input) => {
    if (!process.env.TMUX) return
    if (!HANDLED.has(input.tool.toLowerCase())) return

    const a = input.args ?? {}
    const filePath: string | undefined = a.filePath ?? a.file_path ?? a.path
    if (!filePath || SKIP.some((re) => re.test(filePath))) return

    const home = process.env.HOME
    if (!home) return

    try {
      const sockets = (await $`ls /tmp/nvim.*/[0-9]*/0 2>/dev/null`.quiet().nothrow().text())
        .split("\n").filter(Boolean)
      for (const sock of sockets) {
        const mode = (await $`nvim --server ${sock} --remote-expr 'mode()'`
          .quiet().nothrow().text()).trim()
        if (mode.startsWith("i")) return
      }
    } catch {}

    await $`bash ${home}/dotfiles/scripts/nvim-open-file.sh ${filePath}`.quiet().nothrow()
  },
})

export default NvimOpenPlugin
