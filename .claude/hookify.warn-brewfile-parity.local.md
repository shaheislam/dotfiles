---
name: warn-brewfile-parity
enabled: true
event: file
tool_matcher: Edit|Write|MultiEdit
conditions:
  - field: file_path
    operator: regex_match
    pattern: (?:^|/)homebrew/Brewfile$
---

🍺 **Brewfile edits require setup + shell parity.**

- When you add or remove a Homebrew formula/cask, update `scripts/setup.sh` so the automated installer stays aligned.
- New CLIs also need PATH exports in both Fish (`.config/fish/config.fish`) and the Zsh section of `scripts/setup.sh` to keep interactive shells consistent.
- Capture the paired updates in the plan or bead so reviewers know the dependency landed everywhere.
