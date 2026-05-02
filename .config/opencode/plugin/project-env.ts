import type { Plugin } from "@opencode-ai/plugin"

export const ProjectEnvPlugin: Plugin = async ({ directory, worktree }) => {
  return {
    "shell.env": async (input, output) => {
      const projectRoot = input.cwd || worktree || directory

      output.env.PROJECT_ROOT = projectRoot
      output.env.REPO_ROOT = projectRoot
      output.env.DOTFILES_ROOT = projectRoot
      output.env.CLAUDE_PROJECT_DIR = projectRoot
    },
  }
}
