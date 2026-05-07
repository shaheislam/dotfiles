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

const HANDLED = new Set(["write", "edit", "multiedit", "patch", "apply_patch", "apply-patch"])

function extractPatchPaths(value: unknown) {
  if (typeof value !== "string") return []

  const paths: string[] = []
  const re = /^\*\*\* (?:(?:Add|Update) File: (.+)|Move to: (.+))$/gm
  for (const match of value.matchAll(re)) {
    const filePath = match[1] ?? match[2]
    if (filePath) paths.push(filePath)
  }
  return paths
}

function changedPaths(args: Record<string, unknown>) {
  const paths = [args.filePath, args.file_path, args.path].filter(
    (value): value is string => typeof value === "string" && value.length > 0,
  )

  paths.push(
    ...extractPatchPaths(args.patchText),
    ...extractPatchPaths(args.patch_text),
    ...extractPatchPaths(args.patch),
  )

  return [...new Set(paths)]
}

const NvimOpenPlugin: Plugin = async ({ $ }) => ({
  "tool.execute.after": async (input) => {
    if (!process.env.TMUX) return
    if (!HANDLED.has(input.tool.toLowerCase())) return

    const a = input.args ?? {}
    const filePaths = changedPaths(a).filter((filePath) => !SKIP.some((re) => re.test(filePath)))
    if (filePaths.length === 0) return

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

    for (const filePath of filePaths) {
      await $`bash ${home}/dotfiles/scripts/nvim-open-file.sh ${filePath}`.quiet().nothrow()
    }
  },
})

export default NvimOpenPlugin
