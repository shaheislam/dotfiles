import type { Plugin } from "@opencode-ai/plugin"

type ClaudePluginModule = {
  ClaudeMaxPlugin: Plugin
}

const OpencodeWithClaudePlugin: Plugin = async (input) => {
  const home = process.env.HOME
  if (!home) {
    throw new Error("HOME is required to load opencode-with-claude")
  }

  // OpenCode's npm plugin cache can omit files from nested dependencies; use
  // the Bun-global install managed by scripts/setup.sh instead.
  const modulePath = `${home}/.bun/install/global/node_modules/opencode-with-claude/dist/index.js`
  const { ClaudeMaxPlugin } = (await import(modulePath)) as ClaudePluginModule

  return ClaudeMaxPlugin(input)
}

export default OpencodeWithClaudePlugin
