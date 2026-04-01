---
name: warn-tmux-config
enabled: true
event: file
tool_matcher: Edit|Write|MultiEdit
conditions:
  - field: file_path
    operator: regex_match
    pattern: (?:^|/)\.tmux\.conf$
---

🌀 **tmux config must live at `~/dotfiles/.tmux.conf`.**

- Avoid creating `.config/tmux/tmux.conf` or alternate tmux config paths—the repo relies on GNU Stow linking the root `.tmux.conf`.
- After editing this file, double-check tmux plugins via TPM rather than dropping config fragments elsewhere.
- Mention in your plan/bead if the change requires `scripts/setup.sh` or TPM adjustments so reviewers know to look.
