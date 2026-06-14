---
description: Run SkillSpector to scan AI agent skill bundles for security issues.
---

Run SkillSpector to scan AI agent skill bundles for security issues.

## Steps
1. Pick the scan target based on user request:
   - "this repo" or no arg → `skillscan here`
   - "skills" → `skillscan skills` (dotfiles canonical) and `skillscan claude-skills` (materialized)
   - "plugins" → `skillscan plugins`
   - "mcp" → `skillscan mcp`
   - explicit path → `skillscan path <dir>`
2. Run the wrapper and capture the report directory it prints.
3. Summarize top findings (severity high+) from the markdown report.
4. If findings look like known false positives (PUA prompt-injection strings, intentional `curl|bash` in `scripts/setup.sh`, etc.) suggest adding them to `~/dotfiles/.skillspector/baseline.json`.
5. If real issues are found, file a `bd` issue for follow-up.

## Output Format
- One-line severity counts (critical / high / medium / low).
- Table of high+ findings: rule id, file, short description.
- Report paths (SARIF + Markdown) for further review.

## Notes
- Scanner uses local Ollama (`OPENAI_BASE_URL=http://localhost:11434/v1`) for semantic analyzers — start Ollama first if it's not running.
- Reports land in `~/.local/share/skillscan/<timestamp>/` (ephemeral, gitignored).
- Baseline lives at `~/dotfiles/.skillspector/baseline.json` (canonical, version-controlled).
