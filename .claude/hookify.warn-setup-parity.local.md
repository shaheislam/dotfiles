---
name: warn-setup-parity
enabled: true
event: file
tool_matcher: Edit|Write|MultiEdit
conditions:
  - field: file_path
    operator: regex_match
    pattern: (?:^|/)scripts/setup\.sh$
---

⚙️ **`scripts/setup.sh` changes must stay in sync.**

- Every new CLI or PATH change belongs in both `scripts/setup.sh` *and* `homebrew/Brewfile` plus the Fish/Zsh PATH exports.
- If you are touching setup logic, schedule a matching Brewfile edit and ensure Fish config mirrors any PATH changes so shell sessions behave the same outside setup.
- Add a note to the plan/bead once the mirrored updates are in place to prove the parity requirement was satisfied.
