# Personal Defaults

> Place this file at ~/.claude/CLAUDE.md (or symlink via stow).
> Applies to every project on every device. Project-level CLAUDE.md files
> override these where they conflict.
> Remove this blockquote and customize below.

## Imports

<!-- If you keep PRINCIPLES.md / RULES.md in ~/.claude/, import them: -->
<!-- @PRINCIPLES.md -->
<!-- @RULES.md -->

## Preferences

<!-- - Output style: concise, no preamble, lead with the answer -->
<!-- - Never add emojis unless asked -->
<!-- - Use conventional commits: type(scope): description -->
<!-- - Prefer fish shell syntax in examples -->

## Tools Available on All Devices

<!-- List tools Claude can always assume are installed -->
<!-- - Homebrew (brew) -->
<!-- - Fish shell (fish) -->
<!-- - GNU Stow (stow) -->
<!-- - Git, gh CLI -->
<!-- - Neovim (nvim) -->
<!-- - tmux with TPM -->
<!-- - Docker / Colima -->
<!-- - Nix (nix-shell, nix develop) -->

## Common Workflows

<!-- Shortcuts Claude should know about across all projects -->
<!-- - `stow -R .` from ~/dotfiles to re-stow configs -->
<!-- - `brew bundle --file=~/dotfiles/homebrew/Brewfile` to sync packages -->
<!-- - `fisher update` to update Fish plugins -->

## Coding Conventions

<!-- Personal defaults that apply unless a project overrides them -->
<!-- - Prefer standard library over external deps -->
<!-- - Fail fast with meaningful context -->
<!-- - Keep functions small and focused -->
<!-- - Tests live next to the code they test -->

## Things to Avoid

<!-- Behaviors you never want, regardless of project -->
<!-- - Don't add trailing summaries after completing work -->
<!-- - Don't create README.md files unless asked -->
<!-- - Don't over-engineer or add speculative abstractions -->
<!-- - Don't mock databases in integration tests -->
