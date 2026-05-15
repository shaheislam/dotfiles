import type { Plugin } from "@opencode-ai/plugin"

export const ProjectEnvPlugin: Plugin = async ({ directory, worktree }) => {
  const home = process.env.HOME || ""
  const dotfilesRoot = process.env.DOTFILES_ROOT || (home ? `${home}/dotfiles` : directory)

  return {
    "shell.env": async (input, output) => {
      const projectRoot = input.cwd || worktree || directory

      output.env.PROJECT_ROOT = projectRoot
      output.env.REPO_ROOT = projectRoot
      output.env.DOTFILES_ROOT = dotfilesRoot
      output.env.CLAUDE_PROJECT_DIR = projectRoot
    },
  }
}
