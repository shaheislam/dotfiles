---
name: block-neovim-edits
enabled: true
event: file
action: block
tool_matcher: Edit|Write|MultiEdit
conditions:
  - field: file_path
    operator: regex_match
    pattern: (?:^|/)neovim/
---

🚫 **Neovim config lives in the separate `~/neovim` repo.**

- This dotfiles worktree must not edit files inside `~/neovim`; make changes from that repo instead so symlinks remain consistent.
- If you truly need to touch Neovim here, pause and move to the dedicated worktree, then document the context in Beads/plan before resuming.
