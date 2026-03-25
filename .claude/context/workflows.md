# Common Workflows

Quick reference for standard operations in this dotfiles repo.

## Adding a New CLI Tool

1. Add to `homebrew/Brewfile`
2. Add PATH to `.config/fish/config.fish` (Fish)
3. Add PATH to `.zshrc` (Zsh compatibility)
4. Update `scripts/setup.sh` with installation check
5. Create Fish function/alias if needed (`.config/fish/functions/`)
6. Apply Tokyo Night theme if the tool has config
7. Run `stow --simulate .` to verify no conflicts
8. Run `stow .` to deploy

## Adding a New GUI App

1. Add as cask to `homebrew/Brewfile`
2. Add config directory under `.config/<app>/`
3. Apply Tokyo Night theme
4. Update `scripts/setup.sh` with post-install config
5. Stow deploy

## Creating a New Fish Function

1. Create `.config/fish/functions/<name>.fish`
2. Function name must match filename
3. Use `argparse` for options
4. Add alias in `.config/fish/config.fish` if needed
5. Test: `fish --no-execute .config/fish/functions/<name>.fish`

## Adding a New Claude Code Skill

1. Create `.claude/skills/<name>/SKILL.md`
2. Add YAML frontmatter (name, description, argument-hint)
3. Write execution steps
4. Skill auto-registers on next session

## Adding a New Claude Code Agent

1. Create `.claude/agents/<name>.md`
2. Add YAML frontmatter (name, description, tools, model)
3. Write system prompt
4. Update `.claude/AGENTS.md` reference

## Modifying tmux Config

- Config: `~/dotfiles/.tmux.conf` (NEVER `.config/tmux/`)
- After changes: `tmux source-file ~/.tmux.conf`
- Plugin changes: prefix + I to install via TPM
