# Commit Conventions

## Format

```
type: brief description
```

## Types

| Type | When |
|------|------|
| `feat` | New tool, function, or configuration |
| `fix` | Bug fix in script or config |
| `refactor` | Restructuring without behavior change |
| `docs` | Documentation only |
| `chore` | Maintenance (Brewfile updates, version bumps) |
| `style` | Formatting, whitespace, theme changes |
| `test` | Adding or updating tests |

## Rules

- NO emojis in commit messages
- NO AI assistant references ("Claude", "Copilot", etc.)
- Keep subject line under 72 characters
- Focus on what changed and why, not who made the change
- Use imperative mood: "add feature" not "added feature"

## Examples

```
feat: add otel Fish wrapper function
fix: resolve stow conflict for ghostty config
refactor: extract Tokyo Night colors to context file
chore: update Brewfile with new CLI tools
docs: add conventions reference files
```

## Multi-File Changes

When a single logical change touches multiple files (e.g., adding a new tool):
- One commit for the complete change
- List affected areas in the description if helpful
