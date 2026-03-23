# CLAUDE.md Hierarchy and Inheritance

How Claude Code discovers, loads, and prioritizes CLAUDE.md instruction files.

## Quick Answer

- CLAUDE.md does **not** need to live inside a git repo
- A shared `~/work/CLAUDE.md` applies to **all** projects within `~/work/`
- `~/work/repoA/CLAUDE.md` takes **precedence** over `~/work/CLAUDE.md`
- All ancestor files are loaded (additive), with deeper files overriding conflicts

## Resolution Order (highest to lowest precedence)

```
1. Managed policy (org-enforced, cannot be excluded)
   macOS:     /Library/Application Support/ClaudeCode/CLAUDE.md
   Linux/WSL: /etc/claude-code/CLAUDE.md

2. User-level (personal, all projects)
   ~/.claude/CLAUDE.md
   ~/.claude/rules/*.md

3. Ancestor walk (from CWD upward)
   ./CLAUDE.md  OR  ./.claude/CLAUDE.md    (project root)
   ../CLAUDE.md OR  ../.claude/CLAUDE.md   (parent)
   ../../CLAUDE.md  ...                     (grandparent, etc.)

4. Subdirectory rules (loaded on-demand when files are accessed)
   ./.claude/rules/*.md
   ./subdir/CLAUDE.md
```

## How the Ancestor Walk Works

When you run `claude` in `/Users/shahe/work/repoA/src/`, Claude Code walks **up**:

```
/Users/shahe/work/repoA/src/CLAUDE.md     (if exists)
/Users/shahe/work/repoA/src/.claude/CLAUDE.md
/Users/shahe/work/repoA/CLAUDE.md         (project root)
/Users/shahe/work/repoA/.claude/CLAUDE.md
/Users/shahe/work/CLAUDE.md               <-- shared workspace rules
/Users/shahe/work/.claude/CLAUDE.md
/Users/shahe/CLAUDE.md
...up to /
```

All found files are loaded. When instructions conflict, **deeper (more specific) files win**.

## Practical Example: Shared Workspace

### Directory structure
```
~/work/
  CLAUDE.md              <-- shared rules (CLI shortcuts, coding standards)
  repoA/
    CLAUDE.md            <-- repoA-specific overrides
    .claude/
      CLAUDE.md          <-- equivalent to repoA/CLAUDE.md
      rules/
        api.md           <-- loaded on-demand when touching API files
  repoB/
    CLAUDE.md            <-- repoB-specific overrides
```

### ~/work/CLAUDE.md (shared across all repos)
```markdown
# Workspace Standards

## Common CLI Commands
- `make test` - run tests
- `make lint` - run linter
- `make build` - build project

## Coding Standards
- Use conventional commits: type(scope): description
- Always run tests before committing
- Prefer composition over inheritance
```

### ~/work/repoA/CLAUDE.md (project-specific)
```markdown
# RepoA - API Service

## Project Context
- Go microservice, uses Chi router
- Tests: `go test ./...`
- Lint: `golangci-lint run`

## Overrides
- Use table-driven tests (overrides generic "run tests" from parent)
```

When Claude Code runs in `~/work/repoA/`, it loads **both** files. The shared workspace
rules provide baseline standards, and repoA's CLAUDE.md adds project-specific context.
Where they conflict (e.g., test commands), repoA's instructions take precedence.

## The @import Syntax

CLAUDE.md files can reference other files with `@`:

```markdown
# .claude/CLAUDE.md
@PRINCIPLES.md
@RULES.md
@../shared/common-rules.md
```

- Paths are relative to the importing file's location
- Maximum **5 hops** of recursive imports
- Imported content is treated as part of the importing file

## Key Behaviors

| Behavior | Detail |
|----------|--------|
| Git repo required? | No |
| Ancestor walk | CWD up to `/`, loads all found files |
| Subdirectory loading | On-demand when files in that dir are accessed |
| Conflict resolution | Deeper (more specific) overrides shallower |
| Import depth limit | 5 recursive hops |
| Exclude files | `claudeMdExcludes` in settings (glob patterns) |
| Additional dirs | `--add-dir` flag + `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` |

## Excluding Files

If a parent CLAUDE.md is unwanted for a specific project, exclude it in settings:

```json
// .claude/settings.json or .claude/settings.local.json
{
  "claudeMdExcludes": [
    "/Users/shahe/work/CLAUDE.md"
  ]
}
```

Managed policy files (`/Library/Application Support/ClaudeCode/CLAUDE.md`) cannot be excluded.

## Tips

1. **Keep shared CLAUDE.md lean** - Common standards only, no project-specific details
2. **Use @import for modularity** - Split large instructions into focused files
3. **Use .claude/rules/ for conditional loading** - Rules with `paths` frontmatter only load when matching files are accessed
4. **Don't duplicate** - If it's in the parent, don't repeat it in the child
5. **Test with `--bare`** - The `--bare` flag skips auto-discovery, useful for debugging which CLAUDE.md is causing issues
