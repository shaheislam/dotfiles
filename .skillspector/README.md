# SkillSpector

Security scanner for AI agent skill bundles. See <https://github.com/NVIDIA/SkillSpector>.

## Wiring

| Surface | Location |
|---------|----------|
| Brew dep | `homebrew/Brewfile` (`yara` system lib) |
| Install | `scripts/setup.sh` (`pipx install skillspector`) |
| Env | `.config/fish/conf.d/skillspector.fish` — routes LLM analyzers to local Ollama |
| Wrapper | `.config/fish/functions/skillscan.fish` |
| Slash cmd | `.claude/commands/skill-scan.md` |
| Baseline | `.skillspector/baseline.json` (this dir, version-controlled) |

## Usage

```fish
skillscan here           # scan current directory
skillscan skills         # scan ~/dotfiles/skills
skillscan claude-skills  # scan ~/.claude/skills (materialized)
skillscan plugins        # scan installed marketplace plugins
skillscan mcp            # scan MCP server bundles
skillscan path <dir>     # scan an arbitrary path
```

Reports land in `~/.local/share/skillscan/<timestamp>/` (SARIF + Markdown).

## Baseline

After the first triage run, save accepted findings (known false positives — PUA prompt-injection strings, intentional `curl|bash` in `setup.sh`, etc.) to `baseline.json` here. Commit the baseline so every machine inherits the same suppression set.

To regenerate from scratch: delete `baseline.json`, run `skillscan skills`, triage, recommit.

## Tracking

- Version: `latest` (no pin). Run `pipx upgrade skillspector` to refresh.
- Diffs in scan output between releases land as baseline updates in PRs.
