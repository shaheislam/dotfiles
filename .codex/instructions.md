# Shared Agent Commands

See `.agents/commands/` for shared command prompts:
- **ci-check**: Check CI status for the current branch or a specific PR.
- **create-pr**: Create a pull request for the current branch.
- **deslop**: Review recent changes and remove AI slop — unnecessary verbosity, over-engineering, and bloat.
- **respond-to-pr-comments**: Address PR review comments for the current branch.

## Local vs Shared Codex State

- `.codex/config.toml` and `.codex/instructions.md` are shared through dotfiles.
- `.codex/accounts/`, sessions, caches, sqlite files, plugins, and temp state are machine-local and intentionally gitignored.

## Codex App Open Destination On macOS

- `scripts/setup/install-codex-open-destination.sh` builds a small proxy app in `/Applications` from the tracked files in `.config/codex-open-destination/`.
- The default shared identity is `TextMate`, routed through `scripts/codex/open-tmux-nvim.sh`.
- The current shared behavior picks an existing tmux pane that is already running `nvim`, preferring the same window, then the same session, then another pane whose working directory best matches the file being opened.
- It does not create a new terminal or tmux window.
- If you already use the real spoofed editor app on a machine, change `.config/codex-open-destination/config.env` to another allowlisted identity before running setup.
- After setup, open Codex and select the configured app once in `Settings -> Default open destination`.
