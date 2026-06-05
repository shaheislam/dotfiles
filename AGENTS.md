# Dotfiles Agent Guide

Global rules for `~/dotfiles`. Read any deeper `AGENTS.md` in the directory you are editing; those files add more specific guidance.

## Scope

- The durable source of truth for this machine setup is `~/dotfiles`.
- Neovim config is not in this repo. It lives at `~/neovim`; only edit it when the task explicitly includes Neovim.
- All dotfiles are symlinked via GNU Stow from `~/dotfiles` to `~`. Do not manually create symlinks.
- The tmux config is `~/dotfiles/.tmux.conf`; never create `.config/tmux/tmux.conf`.

## Cross-Device Persistence

- Before creating or improving any workflow, config, script, prompt, template, hook, skill, or integration, ask whether the improvement should persist across devices.
- If it should persist, implement the durable source of truth in `~/dotfiles` so it travels via git, stow, and setup scripts.
- Avoid one-off changes in `~`, third-party repos, local app state, or machine-specific paths unless they are runtime-only or explicitly temporary.
- If a runtime repo needs the improvement, generate or sync it from `~/dotfiles` rather than making that repo the source of truth.
- Treat external repos as disposable runtime engines that can be recloned and repopulated from `~/dotfiles`.

## Subdirectory Guidance

- `scripts/AGENTS.md` covers Bash scripts, setup phases, and validation tools.
- `.config/fish/AGENTS.md` covers Fish config, functions, completions, and syntax rules.
- `.config/opencode/AGENTS.md` covers OpenCode config, agents, skills, plugins, and permission rules.
- `.claude/AGENTS.md` covers Claude Code subagents and agent-system reference material.
- `homebrew/AGENTS.md` covers Brewfile and tool installation parity.
- `devcontainer/AGENTS.md` covers devcontainer and worktree container lifecycle rules.
- `docs/AGENTS.md` covers documentation conventions.

## Common Mistakes To Avoid

- Do not create files outside `~/dotfiles` except explicit runtime data or the separate `~/neovim` repo when requested.
- Do not use `npx`; use `bunx` for JavaScript package execution.
- Do not add emojis or AI-tool attribution to commit messages.
- Do not create README files unless explicitly asked.
- Do not add Tokyo Night theme configs without checking existing theme consistency.

## Validation

- Prefer `scripts/test-filter.sh [group]` for targeted validation; run `scripts/test-filter.sh --list` to see groups.
- Run `scripts/smoke-test.sh` for broad dotfiles integrity.
- Run `scripts/validate-macos.sh` for macOS-specific configuration checks.
- Use the subdirectory `AGENTS.md` for more specific validation commands.

## Session Completion

- If code changed, run relevant quality gates before finishing.
- File follow-up issues for remaining work.
- Work is not complete until commits and `git push` succeed when the task reaches session-completion scope.
