---
name: warn-fish-config
enabled: true
event: file
tool_matcher: Edit|Write|MultiEdit
conditions:
  - field: file_path
    operator: regex_match
    pattern: (?:^|/)\.config/fish/config\.fish$
---

🐟 **Keep Fish config lean.**

- Put new functions in `.config/fish/functions/<name>.fish` instead of expanding `config.fish`; this keeps autoloads manageable.
- Any PATH changes you add here must also land in `scripts/setup.sh` (Zsh + Fish sections) so login shells and setup runs stay consistent.
- If this edit is intentional, reference the corresponding function file or setup changes in your notes before proceeding.
