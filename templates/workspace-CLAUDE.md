# Workspace Standards

> Place this file at your workspace root (e.g., ~/work/CLAUDE.md).
> All projects within this directory will inherit these rules.
> Project-specific CLAUDE.md files override these where they conflict.

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `make test` | Run project tests |
| `make lint` | Run linter |
| `make build` | Build project |
| `git log --oneline -20` | Recent commits |

## Coding Standards

- Use conventional commits: `type(scope): description`
- Always run tests before committing
- Keep functions focused and small
- Prefer standard library solutions over external dependencies

## Git Workflow

- Create feature branches from main/master
- Write descriptive commit messages explaining why, not just what
- Squash fixup commits before merging

## Code Review

- Check for security issues (injection, XSS, hardcoded secrets)
- Verify error handling is appropriate
- Ensure tests cover the change
