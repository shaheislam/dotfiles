# Gemini CLI Rules for Dotfiles

> Project context for Google Gemini CLI. Gemini follows `GEMINI.md` as its canonical instruction file. This is intentionally separate from `CLAUDE.md` because the tools have different capabilities, config surfaces, and instruction formats.

## Core Rules

### Setup Script Compatibility
- ALWAYS check if `scripts/setup.sh` needs modification when adding new tools
- ALWAYS verify new dependencies are in the Brewfile and setup script
- ALWAYS ensure PATH configs are added to both Fish and Zsh configs

### Instruction Source
- Gemini CLI follows `GEMINI.md`
- Claude Code follows `CLAUDE.md` plus `.claude/settings.json`
- OpenCode follows `AGENTS.md` plus `CLAUDE.md` via `.config/opencode/opencode.json`
- Shared skills are canonical in `skills/` and materialized into `.gemini/skills/` by `scripts/sync-skills-harnesses.sh`
- Do not assume Gemini should mirror Claude/OpenCode settings one-for-one; only align shared repo conventions and intentional operational defaults

### Fish Shell First
- Fish is the primary shell for this machine
- Do not suggest `unset` for interactive shell usage; use `set -e VAR`
- `env -u VAR command` is acceptable for one-off commands started from Fish
- If an example requires Bash or Zsh syntax, label it explicitly

### File Location Constraints
- NEVER create or modify files outside `~/dotfiles` (EXCEPT `~/neovim` for Neovim config)
- ALWAYS ensure tools/configs can be installed via stow or setup script
- CRITICAL: tmux config must ONLY exist at `~/dotfiles/.tmux.conf` — never `.config/tmux/`
- Neovim config lives in `~/neovim` (separate repo, NOT part of dotfiles)

### Symlink Management
- ALWAYS use GNU Stow for all configuration symlinking
- NEVER manually create symlinks or copy config files to home directory
- ALWAYS test stow operations before considering changes complete

## Project Overview

- **Purpose**: Personal macOS dev environment (dotfiles + stow + automated setup)
- **Shell**: Fish (primary), Zsh (secondary with Oh My Zsh)
- **Editor**: Neovim (LazyVim) at `~/neovim`, symlinked to `~/.config/nvim`
- **Terminal**: Ghostty, WezTerm, iTerm2 | **Multiplexer**: tmux with TPM
- **Packages**: Homebrew (`homebrew/Brewfile`) | **LSPs**: Nix-based (`nix/global/`)
- **Theme**: Tokyo Night consistent across all applications

### File Organization
- Application configs: `.config/` subdirectories
- Shell configs: dotfiles root level
- Scripts: `scripts/` directory
- Package management: `homebrew/` directory

### Adding New Tools
- **CLI Tools**: Brewfile → Fish PATH → setup.sh → aliases/functions → Zsh compatibility
- **GUI Apps**: Brewfile cask → setup.sh check → `.config/` subdirectory → Tokyo Night theme
- **Plugins**: Fish=Fisher, tmux=TPM, Neovim=LazyVim (in `~/neovim`)

## Development Standards

- ALWAYS add new packages to `homebrew/Brewfile`
- ALWAYS update `scripts/setup.sh` when adding new tools
- ALWAYS maintain consistent theming (Tokyo Night) across applications
- ALWAYS use Fish shell syntax for primary shell configurations
- ALWAYS include Zsh compatibility for broader system support
- PATH management: add new tool paths to both Fish and setup script

### Gemini CLI Runtime
- `gemini-cli` is managed as a repo dependency via `homebrew/Brewfile`
- `scripts/setup.sh` should verify that Gemini CLI is available after package installation
- Keep Gemini auth and machine-local state out of git; never commit API keys, OAuth tokens, or local Gemini caches
- This repo does not currently pin a Gemini default model in source control; when a workflow depends on a specific Gemini model, pass it explicitly on the command line instead of relying on ambient machine state
- If the repo later adds `.gemini/` config, treat it as Gemini-specific configuration rather than a copy of `.claude/`

### Core Fish Functions (`.config/fish/functions/`)

| Function | Alias | Description |
|----------|-------|-------------|
| `gwt-dev` | `gwtd` | Create worktree with isolated devcontainer |
| `gwt-ticket` | `gwtt` | Autonomous ticket execution (worktree + agent loop) |
| `gwt-status` | `gwts` | Show worktree + devcontainer status table |
| `gwt-cleanup` | `gwtclean` | Remove stale devcontainer instances |
| `pinchtab-ctl` | `ptctl` | PinchTab Chrome orchestrator management |

## Shell Code Style

### Fish Shell (Primary)
- Functions in `.config/fish/functions/` — one function per file
- Function filename must match function name
- Use `argparse` for flag parsing, `set -l` for locals, `set -gx` for exports
- Use `set` not `export`. Use `; and` not `&&`. Use `test` not `[[ ]]`
- String operations: prefer Fish builtins (`string match`, `string replace`)
- Error output: `echo "Error: message" >&2`
- `config.fish` is 2800+ lines. Read the relevant section first, do not rewrite the entire file

### Bash Scripts
- Scripts in `scripts/` directory
- Shebang: `#!/usr/bin/env bash`
- Always `set -euo pipefail` at the top
- Quote all variable expansions: `"$var"` not `$var`
- Functions: lowercase with underscores

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Fish function | kebab-case | `gwt-dev`, `otel-start` |
| Fish alias | short lowercase | `gwtd`, `ptctl` |
| Bash function | snake_case | `install_package` |
| Script file | kebab-case | `setup-mobile-coding.sh` |
| Config dir | lowercase | `.config/ghostty/` |

## Git Commit Standards

- Use conventional commit format: `type: brief description`
- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`
- NO emojis in commit messages
- NO AI assistant references in commits
- Imperative mood: "add feature" not "added feature"
- Keep subject line under 72 characters

## Testing & Validation

- Fish syntax check: `fish --no-execute <file>`
- Bash syntax check: `bash -n <file>`
- Bash lint: `shellcheck <file>`
- Stow dry-run: `stow --simulate --verbose .`
- Smoke test: `scripts/smoke-test.sh`
- macOS validation: `scripts/validate-macos.sh`
- Filtered tests: `scripts/test-filter.sh [group]` (run `--list` for groups)
- Gemini-specific checks: `scripts/test-filter.sh gemini`
- Full validation: `scripts/validate-comprehensive.sh`
- For Fish functions, test by sourcing: `source .config/fish/functions/<name>.fish`
- There are no unit test frameworks for shell scripts — test by execution
- Cross-platform testing via Docker containers (`scripts/docker/`). Start Colima first

## Setup Script

- `scripts/setup.sh` is 1500+ lines with 11 phases. Read the relevant phase before editing.
- Profiles: minimal, standard, comprehensive, dev, ops
- New tool additions require: Brewfile entry + setup.sh phase + Fish/Zsh PATH config
- Gemini CLI is installed from Homebrew (`brew "gemini-cli"`) and should be verified during setup
- Test with `--dry-run` flag first

### Git Worktree Functions

- The `gwt-*` functions in `.config/fish/functions/` are the core worktree system
- `gwt-dev.fish` creates worktrees with devcontainer isolation
- `gwt-ticket.fish` is the autonomous ticket executor — read it before modifying
- `devcon.fish` handles all devcontainer lifecycle — do not create separate container management
- The devcon sandbox (`~/dotfiles/devcontainer/claude-code-plugins/`) is a built-in container config. Projects do NOT need their own `.devcontainer/` directory to use it
- All tmux panes in devcontainer windows must run inside the container (via `devcontainer exec`)

### Peripheral Tools

- **Self-Hosted LLM**: Ollama + Open WebUI. Setup: `scripts/setup-selfhost-llm.sh`. Fish: `llm`, `llm-code`, `llm-chat`, `llm-status`
- **Mobile Coding**: Mosh + Tailscale (`scripts/setup-mobile-coding.sh`)
- **Pi-hole**: `scripts/pihole/`, Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

- **K8s Manifests**: ALWAYS in `scripts/manifests/` with README updates

## Common Mistakes to Avoid

- Do not create files outside `~/dotfiles` (exception: `~/neovim`)
- Do not add emojis to commit messages
- Do not use `npx` — use `bunx` instead
- Do not manually create symlinks — use stow

- Do not sort/reorganize Brewfile — maintain existing grouping
- Do not create README.md files unless explicitly asked
- Do not add Tokyo Night theme configs without checking all tools for consistency
- tmux plugins are managed by TPM, not stow
- LazyVim config lives in `~/neovim`, not here

## Quality Assurance

### Before Committing
- Verify setup script works, stow completes, theme consistency maintained
- Validate Fish and Zsh configurations work correctly

### Troubleshooting
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Session Completion

When ending a work session, complete ALL steps:

1. **Run quality gates** (if code changed) — tests, linters, syntax checks
2. **Commit changes** — use conventional commit format
3. **Push to remote** — work is NOT complete until `git push` succeeds:
   ```
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
4. **Verify** — all changes committed AND pushed

Do not stop before pushing — that leaves work stranded locally.
