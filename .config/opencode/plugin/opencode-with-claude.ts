import { existsSync } from "node:fs"
import type { Plugin } from "@opencode-ai/plugin"

type ClaudePluginModule = {
  ClaudeMaxPlugin: Plugin
}

let sharedPluginPromise: Promise<Awaited<ReturnType<Plugin>>> | null = null

function seedMeridianProfile(home: string) {
  if (process.env.MERIDIAN_PROFILES) {
    return
  }

  const profilesFile = `${home}/.config/meridian/profiles.json`
  if (existsSync(profilesFile)) {
    return
  }

  process.env.MERIDIAN_PROFILES = JSON.stringify([
    {
      id: "default",
      claudeConfigDir: `${home}/.claude`,
    },
  ])

  if (!process.env.MERIDIAN_DEFAULT_PROFILE) {
    process.env.MERIDIAN_DEFAULT_PROFILE = "default"
  }
}

async function loadSharedPlugin(input: Parameters<Plugin>[0]) {
  if (!sharedPluginPromise) {
    sharedPluginPromise = (async () => {
      const home = process.env.HOME
      if (!home) {
        throw new Error("HOME is required to load opencode-with-claude")
      }

      seedMeridianProfile(home)

      // OpenCode can initialize plugins multiple times in one process while it
      // bootstraps worker/session phases. Reuse a single upstream plugin
      // instance so Meridian only starts one Claude proxy per run.
      const modulePath = `${home}/.bun/install/global/node_modules/opencode-with-claude/dist/index.js`
      const { ClaudeMaxPlugin } = (await import(modulePath)) as ClaudePluginModule
      return ClaudeMaxPlugin(input)
    })().catch((error) => {
      sharedPluginPromise = null
      throw error
    })
  }

  return sharedPluginPromise
}

const OpencodeWithClaudePlugin: Plugin = async (input) => {
  return loadSharedPlugin(input)
}

export default OpencodeWithClaudePlugin
