# Dotfiles Agent Guide

This file documents specific behaviors and constraints for AI agents working on this repository. Each rule addresses a concrete mistake agents repeatedly make.

## File 

- The tmux config is at `~/dotfiles/.tmux.conf` in the repo root. NEVER create `.config/tmux/tmux.conf` - it will conflict with the stow symlink.
- Neovim config is NOT in this repo. It lives at `~/neovim` (separate repository). Do not create or modify nvim configs here.
- Fish functions go in `.config/fish/functions/<name>.fish` as individual files, not inline in `config.fish`.
- All dotfiles are symlinked via GNU Stow from `~/dotfiles` to `~`. Do not manually create symlinks.
- Keep user-owned canonical data, reusable templates, and integration scripts in `~/dotfiles`; do not move the source of truth into third-party repos.
- Treat external repos (for example `~/career-ops`) as disposable runtime engines that can be recloned and repopulated from `~/dotfiles` via sync scripts.
- Prefer env-driven sync/generation into external repos over cross-repo symlinks so the workflow stays portable across machines and worktrees.

## Shell Scripts

- Fish is the primary shell. Write new shell functions in Fish syntax, not Bash.
- When modifying `config.fish`, it is 2800+ lines. Read the relevant section first, do not rewrite the entire file.
- Fish shell uses `set` not `export`. Fish uses `; and` not `&&`. Fish uses `test` not `[[ ]]`.
- All new CLI tools must be added to BOTH `homebrew/Brewfile` AND `scripts/setup.sh`.
- PATH additions must go in both Fish config AND `scripts/setup.sh` (Zsh section) for compatibility.

## Package Management

- Use `bun`/`bunx` instead of `npm`/`npx`/`yarn`/`pnpm`. The `use_bun.py` hook will block npm commands.
- Homebrew packages go in `homebrew/Brewfile`, not installed via `brew install` in scripts.
- MCP servers must be configured in BOTH Claude Desktop config AND Claude Code CLI. Check both.

## Testing

- Run `scripts/smoke-test.sh` to validate basic dotfiles integrity.
- Run `scripts/validate-macos.sh` to check macOS-specific configurations.
- For Fish functions, test by sourcing the file: `source .config/fish/functions/<name>.fish`.
- There are no unit test frameworks for shell scripts - test by execution.
- Docker tests exist at `scripts/docker/` for Linux compatibility. Start Colima first.

## Available Tools for Agents

- `scripts/test-filter.sh [group]` - **Filtered test runner** (preferred for quick feedback). Run `--list` to see groups: fish, stow, claude, setup-syntax, brewfile, mcp, tmux, hooks, agents-md.
- `scripts/smoke-test.sh` - Quick validation of dotfiles setup.
- `scripts/validate-comprehensive.sh` - Full validation suite (slow).
- `scripts/test-lsp-inheritance.sh` - Verify LSP isolation works correctly.
- `scripts/pihole/test-pihole-setup.sh` - Test Pi-hole DNS setup.
- `scripts/devcontainer/test-claude-autologin.sh` - Test Claude autologin in devcontainers.
- `.claude/hooks/use_bun.py` - Enforces bun over npm (PreToolUse hook).
- `.claude/hooks/validate-bash.py` - Blocks dangerous bash commands (PreToolUse hook).
- `scripts/plan-validate.sh <plan.md>` - Validates plan markdown against DQS required sections (10 required, `--strict` for optional).

## Git Worktree Functions

- The `gwt-*` functions in `.config/fish/functions/` are the core worktree system.
- `gwt-dev.fish` creates worktrees with devcontainer isolation.
- `gwt-ticket.fish` is the autonomous ticket executor - read it before modifying.
- `devcon.fish` handles all devcontainer lifecycle - do not create separate container management.
- The devcon sandbox (`~/dotfiles/devcontainer/claude-code-plugins/`) is a built-in container config. Projects do NOT need their own `.devcontainer/` directory to use it. Never gate devcontainer usage on the project having `.devcontainer/`.
- All tmux panes in devcontainer windows must run inside the container (via `devcontainer exec`). When a container process exits (nvim, fish), the pane should re-enter the container shell, not drop to the host.

## Common Mistakes to Avoid

- Do not add emojis to commit messages.
- Do not reference AI tools in commit messages.
- Do not create files outside `~/dotfiles` (exception: `~/neovim`; exception: runtime logs/caches in `~/.claude/` — see below).
- Do not use `npx` for MCP commands in setup.sh - use `bunx`.
- Do not modify `.claude/settings.json` to manage **plugins** — use `claude plugin` commands.
- **Exception: Hooks** are configured directly in `.claude/settings.json` under the `"hooks"` key per [official docs](https://code.claude.com/docs/en/hooks). There is no CLI for hook registration. When wiring hooks, update settings.json in both `~/dotfiles/.claude/` (stow source) and verify `~/.claude/` (symlink target) reflects the change.
- **Exception: Runtime data** — Hook scripts may write runtime logs/caches to `~/.claude/hooks/logs/` and similar paths. This is expected behavior (same pattern as Beads `bd prime`, checkpoints, notification logs). These are runtime artifacts, not source configs, and must NOT be committed to the dotfiles repo.
- Do not create README.md files unless explicitly asked.
- Do not add Tokyo Night theme configs without checking all tools for consistency.

## Setup Script

- `scripts/setup.sh` is 1500+ lines with 11 phases. Read the relevant phase before editing.
- The setup script supports profiles: minimal, standard, comprehensive, dev, ops.
- New tool additions require: Brewfile entry + setup.sh phase + Fish/Zsh PATH config.
- Test setup changes with `--dry-run` flag first.

## When NOT to Use Agents for This Repo

- Karabiner-Elements config: use the GUI app, the JSON is complex and auto-generated.
- tmux plugin installation: TPM handles this, just add to `.tmux.conf`.
- Brewfile sorting/organization: maintain the existing grouping structure.
- LazyVim plugin config: this lives in `~/neovim`, not here.


## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
