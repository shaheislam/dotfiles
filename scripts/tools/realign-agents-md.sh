#!/usr/bin/env bash
# Realign AGENTS.md hierarchy and ignore policy across personal and work repos.
set -euo pipefail

APPLY=false
LIST_REPOS=false
TARGET_ALL=true
TARGET_PERSONAL=false
TARGET_WORK=false
REPO_ARGS=()

DOTFILES_REPO="$HOME/dotfiles"
NEOVIM_REPO="$HOME/neovim"
WORK_ROOT="$HOME/work"

changed_count=0
checked_count=0

usage() {
	cat <<'EOF'
Usage: scripts/tools/realign-agents-md.sh [options]

Realigns AGENTS.md hierarchy and ignore policy across repos.

Modes:
  --dry-run        Show proposed changes without writing files (default)
  --apply          Write changes
  --list-repos     Print target repositories only, one per line
  --all            Target ~/dotfiles, ~/neovim, and ~/work/* repos (default)
  --personal       Target personal tracked repos only: ~/dotfiles and ~/neovim
  --work           Target work repos only: ~/work/*
  --repo PATH      Target one repo; can be repeated
  --agentic        Accepted for skill compatibility; orchestration happens in the skill
  --batch-size N   Accepted for skill compatibility; batching happens in the skill
  --help, -h       Show this help

Policy:
  - ~/dotfiles and ~/neovim keep committed AGENTS.md files.
  - ~/work/* keeps AGENTS.md local-only via .git/info/exclude.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		APPLY=false
		shift
		;;
	--apply)
		APPLY=true
		shift
		;;
	--list-repos)
		LIST_REPOS=true
		shift
		;;
	--all)
		TARGET_ALL=true
		TARGET_PERSONAL=false
		TARGET_WORK=false
		shift
		;;
	--personal)
		TARGET_ALL=false
		TARGET_PERSONAL=true
		shift
		;;
	--work)
		TARGET_ALL=false
		TARGET_WORK=true
		shift
		;;
	--repo)
		[[ -n "${2:-}" ]] || {
			printf 'ERROR: --repo requires a path\n' >&2
			exit 2
		}
		TARGET_ALL=false
		REPO_ARGS+=("$2")
		shift 2
		;;
	--agentic)
		shift
		;;
	--batch-size)
		[[ -n "${2:-}" ]] || {
			printf 'ERROR: --batch-size requires a number\n' >&2
			exit 2
		}
		shift 2
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		printf 'ERROR: unknown option: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
done

log() {
	printf '%s\n' "$*"
}

is_git_repo() {
	[[ -d "$1/.git" ]]
}

mark_checked() {
	checked_count=$((checked_count + 1))
}

mark_changed() {
	changed_count=$((changed_count + 1))
}

write_file() {
	local path="$1"
	local content="$2"
	local dir
	dir="$(dirname "$path")"

	if [[ -f "$path" ]] && [[ "$(<"$path")" == "$content" ]]; then
		return 0
	fi

	mark_changed
	if [[ "$APPLY" == true ]]; then
		mkdir -p "$dir"
		printf '%s\n' "$content" >"$path"
		log "  updated $path"
	else
		log "  would update $path"
	fi
}

ensure_line() {
	local path="$1"
	local line="$2"
	local label="$3"

	if [[ -f "$path" ]] && grep -qxF "$line" "$path"; then
		return 0
	fi

	mark_changed
	if [[ "$APPLY" == true ]]; then
		mkdir -p "$(dirname "$path")"
		if [[ ! -f "$path" ]]; then
			: >"$path"
		fi
		printf '%s\n' "$line" >>"$path"
		log "  added $label: $line"
	else
		log "  would add $label: $line"
	fi
}

ensure_gitignore_unignore_agents() {
	local repo="$1"
	local gitignore="$repo/.gitignore"

	ensure_line "$gitignore" '!AGENTS.md' '.gitignore unignore'
	ensure_line "$gitignore" '!**/AGENTS.md' '.gitignore unignore'
}

ensure_gitattributes_agents() {
	local repo="$1"
	local attrs="$repo/.gitattributes"

	ensure_line "$attrs" 'AGENTS.md merge=union-doc' '.gitattributes merge driver'
	ensure_line "$attrs" '**/AGENTS.md merge=union-doc' '.gitattributes merge driver'
}

dotfiles_root_agents() {
	cat <<'EOF'
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
EOF
}

neovim_root_agents() {
	cat <<'EOF'
# Neovim Agent Guide

Global rules for `~/neovim`. Read any deeper `AGENTS.md` in the directory you are editing.

## Scope

- This is the personal Neovim config repo, separate from `~/dotfiles`.
- It is symlinked to `~/.config/nvim` and should remain commit-worthy across devices.
- LSPs are Nix-managed; never add Mason or `mason-lspconfig`.
- Preserve transparent UI behavior unless the task explicitly changes the theme model.

## Subdirectory Guidance

- `lua/AGENTS.md` covers Lua module style and runtime conventions.
- `lua/config/AGENTS.md` covers core config, keymaps, autocmds, and agent bridges.
- `lua/plugins/AGENTS.md` covers lazy.nvim plugin specs.
- `lua/plugins/git/AGENTS.md` covers Git plugin integrations.
- `lua/git/AGENTS.md` covers custom Git workflow modules.
- `lua/parley/AGENTS.md` covers Parley review tooling.
- `tests/AGENTS.md` covers headless Neovim tests.

## Workflow Contract

- Read `.claude/context/workflows.md` before changing AI-tooling workflows.
- Treat `.plan.md` as the control plane for the current task.
- Use `opencode.nvim` as the primary Neovim bridge into OpenCode.
- Treat diagnostics, quickfix, and git diff as the review plane before handoff.

## Beads

- This project uses `bd` for issue tracking; run `bd onboard` for full context.
- Use `bd ready`, `bd show <id>`, `bd update <id> --status in_progress`, and `bd close <id>` for task lifecycle.

## Validation

- Run `nvim --headless +qa` for startup validation.
- Run `nvim --headless "+checkhealth nvim_mini" +qa` for project health.
- Run `nvim --headless -l tests/parley_review_spec.lua` when review tooling changes.

## Session Completion

- If code changed, run relevant validation before finishing.
- Push bead state with `bd dolt push` when issue state changed.
- Work is not complete until commits and `git push` succeed when the task reaches session-completion scope.
EOF
}

work_agents() {
	local repo_name="$1"
	cat <<EOF
# Work Repo Agent Guide

Local-only guidance for \`$repo_name\`. This file is intentionally ignored through \`.git/info/exclude\` and should not be committed unless the repository explicitly adopts a shared \`AGENTS.md\` contract.

## Source Of Truth

- Keep reusable personal workflows, scripts, prompts, and templates in \`~/dotfiles\`.
- Keep this file focused on repo-specific commands, constraints, and local workflow notes.
- Do not put company secrets, credentials, or private customer data in this file.

## Fill In Locally

- Project setup command:
- Test command:
- Lint/typecheck command:
- Deployment or release constraints:
- Important directories:
EOF
}

realign_dotfiles() {
	local repo="$1"
	mark_checked
	log "dotfiles: $repo"
	ensure_gitignore_unignore_agents "$repo"
	ensure_gitattributes_agents "$repo"
	write_file "$repo/AGENTS.md" "$(dotfiles_root_agents)"

	write_file "$repo/scripts/AGENTS.md" '# Scripts Agent Guide

Rules for `~/dotfiles/scripts`.

## Bash Style

- Scripts use Bash with `#!/usr/bin/env bash` and `set -euo pipefail` where practical.
- Quote variables and paths.
- Use snake_case function names.
- Never use `((var++))` with `set -e`; use `var=$((var + 1))`.
- Prefer shared helpers from `scripts/lib/` when an existing helper fits.

## Setup Script

- `scripts/setup.sh` is large and phase-based; read the relevant phase before editing.
- New CLI tools require `homebrew/Brewfile`, `scripts/setup.sh`, and shell PATH/config parity.
- Use `--dry-run` for setup changes when available.
- Do not install Homebrew packages directly from scripts; declare them in `homebrew/Brewfile`.

## Validation

- Run `bash -n <script>` for edited Bash scripts.
- Run `scripts/test-filter.sh setup-syntax` for setup-related changes.
- Run `scripts/test-filter.sh [group]` for targeted validation before broader suites.
- Use Docker tests under `scripts/docker/` for cross-platform changes when relevant.'

	write_file "$repo/.config/fish/AGENTS.md" '# Fish Agent Guide

Rules for `~/dotfiles/.config/fish`.

## Fish Syntax

- Fish is the primary interactive shell.
- Use Fish syntax, not Bash syntax: `set`, `test`, and `; and`.
- Do not suggest `unset`; use `set -e VAR` for interactive Fish guidance.
- `env -u VAR command` is acceptable for one-off command execution.
- Label Bash/Zsh-only snippets explicitly.

## File Layout

- Fish functions go in `.config/fish/functions/<name>.fish` as individual files.
- Do not add new functions inline in `config.fish`.
- Read the relevant `config.fish` section before editing; do not rewrite the whole file.
- Completions belong in `.config/fish/completions/` unless an existing function-local pattern is already used.

## Validation

- Run `fish -n .config/fish/config.fish` after config changes.
- Run `fish -n .config/fish/functions/<name>.fish` for edited functions.
- Test loadable functions with `fish -c '\''source .config/fish/functions/<name>.fish; functions -q <name>'\''`.
- Run `scripts/test-filter.sh fish` for Fish changes.'

	write_file "$repo/.config/opencode/AGENTS.md" '# OpenCode Agent Guide

Rules for `~/dotfiles/.config/opencode`.

## Scope

- Use OpenCode customization rules only for OpenCode config, agents, skills, plugins, MCP servers, and permission rules.
- Do not apply OpenCode customization patterns to normal application code.
- Keep durable OpenCode configuration in `~/dotfiles`; generated runtime surfaces can be materialized elsewhere.

## Configuration

- Keep plugin and harness behavior aligned with Claude-compatible hooks when relevant.
- Update docs when adding commands, agents, skills, or plugin behavior that agents need to know.
- Prefer small changes to existing plugin files over adding parallel mechanisms.

## Validation

- Run `scripts/test-filter.sh opencode` for OpenCode config changes.
- Run targeted syntax checks for edited TypeScript or JavaScript files when applicable.
- Check MCP parity with `scripts/test-filter.sh mcp` when MCP server wiring changes.'

	write_file "$repo/homebrew/AGENTS.md" '# Homebrew Agent Guide

Rules for `~/dotfiles/homebrew`.

## Brewfile

- Add Homebrew dependencies to `homebrew/Brewfile`; do not install them with ad hoc `brew install` commands.
- Preserve the existing grouping structure.
- Do not reorganize or sort the Brewfile broadly unless explicitly asked.
- GUI apps belong as casks when appropriate.

## Setup Parity

- New CLI tools must also be handled in `scripts/setup.sh`.
- PATH changes must be reflected in Fish config and setup-script Zsh compatibility where needed.
- MCP package additions must maintain Claude Desktop and Claude Code CLI parity.

## Validation

- Run `scripts/test-filter.sh brewfile` after Brewfile changes.
- Run `scripts/test-filter.sh setup-syntax` if setup wiring changed.'

	write_file "$repo/devcontainer/AGENTS.md" '# Devcontainer Agent Guide

Rules for `~/dotfiles/devcontainer`.

## Worktree Containers

- `devcon.fish` owns devcontainer lifecycle; do not create separate container managers.
- The devcon sandbox in `~/dotfiles/devcontainer/claude-code-plugins/` is built-in.
- Do not require projects to have their own `.devcontainer/` directory to use `devcon`.
- All tmux panes in devcontainer windows should run inside the container via `devcontainer exec`.
- When a container process exits, panes should re-enter the container shell rather than dropping to the host.

## Validation

- Run `scripts/devcontainer/test-claude-autologin.sh` for Claude credential or autologin changes.
- Run targeted Docker or devcontainer checks when lifecycle scripts change.'

	write_file "$repo/docs/AGENTS.md" '# Docs Agent Guide

Rules for `~/dotfiles/docs`.

## Documentation

- Keep docs direct and operational.
- Update existing docs before creating new docs when the topic already exists.
- Do not create README files unless explicitly requested.
- Keep examples Fish-compatible by default; label Bash/Zsh snippets explicitly.

## Cross-References

- Prefer links to durable dotfiles paths for reusable workflows.
- Do not make third-party repos the source of truth for user-owned templates or guidance.
- Keep references to `AGENTS.md`, `CLAUDE.md`, and setup scripts aligned when changing agent workflow docs.'
}

realign_neovim() {
	local repo="$1"
	mark_checked
	log "neovim: $repo"
	ensure_gitignore_unignore_agents "$repo"
	ensure_gitattributes_agents "$repo"
	write_file "$repo/AGENTS.md" "$(neovim_root_agents)"

	write_file "$repo/lua/AGENTS.md" '# Lua Agent Guide

Rules for `~/neovim/lua`.

## Style

- Use Lua module style with `local M = {}` and `return M` for shared modules.
- Keep plugin specs under `lua/plugins/`; keep reusable runtime helpers under domain directories such as `lua/config`, `lua/git`, or `lua/parley`.
- Prefer `pcall()` around optional plugin or LSP integrations that can fail at startup.
- Use `vim.uv.new_timer()` for debounced async work.

## Validation

- Run `luac -p <file>.lua` for edited standalone Lua files when possible.
- Run `nvim --headless +qa` after startup-affecting changes.
- Run `nvim --headless "+checkhealth nvim_mini" +qa` after runtime or health changes.'

	write_file "$repo/lua/config/AGENTS.md" '# Config Agent Guide

Rules for `~/neovim/lua/config`.

## Core Config

- Global editor keymaps belong in `keymaps.lua`.
- Plugin-specific keymaps belong in that plugin'\''s spec file under `lua/plugins/`.
- Always include `desc` on keymaps for which-key discovery.
- Use project-prefixed augroups with `clear = true`.
- Skip expensive LSP operations in diff buffers when helpers such as `is_diff_buf()` are available.

## Agent Bridge

- `claude-bridge.lua` writes editor state to `/tmp/nvim-claude-bridge/`.
- `hotreload.lua` handles external edit reload behavior; avoid adding competing file watchers.
- Keep bridge and hotreload changes reviewed through diagnostics, quickfix, and git diff.

## Validation

- Run `nvim --headless +qa` after core config changes.
- Run `nvim --headless "+checkhealth nvim_mini" +qa` after bridge, LSP, or health changes.'

	write_file "$repo/lua/plugins/AGENTS.md" '# Plugins Agent Guide

Rules for `~/neovim/lua/plugins`.

## lazy.nvim Specs

- Use one plugin spec per file, except `core.lua` for shared dependencies.
- Use lazy.nvim spec format: `{ "owner/repo", opts = {}, config = function() end }`.
- Declare `dependencies` for load-order correctness.
- Default to `lazy = false`; use `event`, `ft`, `cmd`, or `keys` only when lazy-loading is intentional.
- Pin with `version = false` rather than tagged releases unless a plugin requires otherwise.

## Rules

- Never add Mason or `mason-lspconfig`; LSPs come from Nix.
- Preserve transparent backgrounds for floats and popups.
- Add `desc` to all keymaps.
- Check for keymap conflicts before adding bindings.

## Validation

- Run `luac -p lua/plugins/<file>.lua` for edited plugin specs.
- Run `nvim --headless -c "lua require('\''lazy'\'').health()" -c "qa"` after plugin spec changes.
- Run `nvim --headless +qa` for startup validation.'

	write_file "$repo/lua/plugins/git/AGENTS.md" '# Git Plugin Agent Guide

Rules for `~/neovim/lua/plugins/git`.

## Scope

- Keep plugin setup for Git UI integrations here.
- Keep reusable Git workflow logic in `lua/git/`.
- Do not duplicate keymaps already provided by broader Git plugin specs.

## Validation

- Run `luac -p lua/plugins/git/<file>.lua` for edited files.
- Run `nvim --headless +qa` after plugin setup changes.'

	write_file "$repo/lua/git/AGENTS.md" '# Git Workflow Agent Guide

Rules for `~/neovim/lua/git`.

## Scope

- This directory contains reusable Git workflow modules used by Neovim commands and plugins.
- Keep UI plugin setup in `lua/plugins/git/`; keep workflow logic here.
- Prefer small composable functions that can be exercised from headless Neovim.

## Validation

- Run `luac -p lua/git/<file>.lua` for edited files.
- Run `nvim --headless +qa` after workflow integration changes.'

	write_file "$repo/lua/parley/AGENTS.md" '# Parley Agent Guide

Rules for `~/neovim/lua/parley`.

## Review Tooling

- Preserve review marker parsing for `㊷[text]` and optional `{question}` blocks.
- Keep diagnostics and quickfix output aligned with `tests/parley_review_spec.lua`.
- Prefer pure collection/formatting functions that are easy to test headlessly.

## Validation

- Run `luac -p lua/parley/<file>.lua` for edited files.
- Run `nvim --headless -l tests/parley_review_spec.lua` after Parley changes.'

	write_file "$repo/tests/AGENTS.md" '# Tests Agent Guide

Rules for `~/neovim/tests`.

## Test Style

- Tests run under headless Neovim.
- Keep tests deterministic and independent of local UI state.
- Add focused tests near the behavior being changed rather than broad startup assertions.

## Validation

- Run `nvim --headless -l tests/parley_review_spec.lua` for Parley review tests.
- Run `nvim --headless +qa` for startup sanity.
- Run `nvim --headless "+checkhealth nvim_mini" +qa` for health checks.'
}

ensure_work_repo_local_agents() {
	local repo="$1"
	local exclude_file="$repo/.git/info/exclude"
	local local_link="$repo/.gitignore_local"

	mark_checked
	log "work: $repo"
	ensure_line "$exclude_file" 'AGENTS.md' '.git/info/exclude local-only guide'

	if [[ -e "$local_link" || -L "$local_link" ]]; then
		if [[ -L "$local_link" && "$(readlink "$local_link")" == '.git/info/exclude' ]]; then
			:
		else
			mark_changed
			if [[ "$APPLY" == true ]]; then
				rm -f "$local_link"
				(cd "$repo" && ln -s .git/info/exclude .gitignore_local)
				log "  fixed .gitignore_local symlink"
			else
				log "  would fix .gitignore_local symlink"
			fi
		fi
	else
		mark_changed
		if [[ "$APPLY" == true ]]; then
			(cd "$repo" && ln -s .git/info/exclude .gitignore_local)
			log "  created .gitignore_local symlink"
		else
			log "  would create .gitignore_local symlink"
		fi
	fi

	if [[ ! -f "$repo/AGENTS.md" ]]; then
		write_file "$repo/AGENTS.md" "$(work_agents "$(basename "$repo")")"
	else
		log "  kept existing local AGENTS.md"
	fi
}

collect_repos() {
	if [[ ${#REPO_ARGS[@]} -gt 0 ]]; then
		printf '%s\n' "${REPO_ARGS[@]}"
		return 0
	fi

	if [[ "$TARGET_ALL" == true || "$TARGET_PERSONAL" == true ]]; then
		[[ -d "$DOTFILES_REPO" ]] && printf '%s\n' "$DOTFILES_REPO"
		[[ -d "$NEOVIM_REPO" ]] && printf '%s\n' "$NEOVIM_REPO"
	fi

	if [[ "$TARGET_ALL" == true || "$TARGET_WORK" == true ]]; then
		[[ -d "$WORK_ROOT" ]] || return 0
		find "$WORK_ROOT" -maxdepth 2 -type d -name .git -print 2>/dev/null | sed 's#/.git$##' | sort
	fi
}

classify_and_realign() {
	local repo="$1"
	local abs_repo
	abs_repo="$(cd "$repo" && pwd)"

	if ! is_git_repo "$abs_repo"; then
		log "skip non-git repo: $repo"
		return 0
	fi

	case "$abs_repo" in
	"$DOTFILES_REPO") realign_dotfiles "$abs_repo" ;;
	"$NEOVIM_REPO") realign_neovim "$abs_repo" ;;
	"$WORK_ROOT"/*) ensure_work_repo_local_agents "$abs_repo" ;;
	*)
		mark_checked
		log "custom repo: $abs_repo"
		ensure_work_repo_local_agents "$abs_repo"
		;;
	esac
}

if [[ "$LIST_REPOS" == true ]]; then
	collect_repos
	exit 0
fi

if [[ "$APPLY" == false ]]; then
	log 'Running in dry-run mode. Use --apply to write changes.'
fi

while IFS= read -r repo; do
	[[ -n "$repo" ]] || continue
	classify_and_realign "$repo"
done < <(collect_repos)

log ""
log "Repos checked: $checked_count"
if [[ "$APPLY" == true ]]; then
	log "Changes applied: $changed_count"
else
	log "Changes proposed: $changed_count"
fi
