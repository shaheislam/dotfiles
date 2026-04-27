---
name: careful
description: Enable destructive command warnings for the rest of this session. Warns before rm -rf, git reset --hard, DROP TABLE, force push, and similar dangerous operations.
---

# Careful Mode

You are now in **careful mode** for the remainder of this session. Inspired by gstack's /careful skill.

## Behavior

For ALL subsequent actions in this session, you MUST check every command and file operation against the destructive patterns below. If a match is found, you MUST warn the user and get explicit confirmation before proceeding.

### Destructive Command Patterns

**File system:**
- `rm -rf` or `rm -r` on directories
- `rm` on more than 3 files at once
- Any `rm` targeting home directory, root, or config directories
- `mv` that would overwrite existing files without backup
- `chmod -R` or `chown -R` on system directories

**Git:**
- `git reset --hard`
- `git push --force` or `git push -f`
- `git clean -fd` or `git clean -fdx`
- `git checkout -- .` (discard all changes)
- `git branch -D` (force delete branch)
- `git stash drop` or `git stash clear`
- `git rebase` on shared/pushed branches

**Database:**
- `DROP TABLE`, `DROP DATABASE`, `TRUNCATE`
- `DELETE FROM` without WHERE clause
- `UPDATE` without WHERE clause

**System:**
- `kill -9` on system processes
- `systemctl stop` on critical services
- `docker rm` or `docker system prune`
- Package removal (`brew uninstall`, `apt remove`, `pip uninstall`)

**Infrastructure:**
- `terraform destroy`
- `kubectl delete` on namespaces or deployments
- AWS resource deletion commands

### Warning Format

When a destructive pattern is detected, display:

```
CAREFUL MODE WARNING

  Command: [the destructive command]
  Risk:    [what could go wrong]
  Scope:   [what will be affected]

  Proceed? [y/N]
```

Wait for explicit user confirmation before executing.

### Exceptions

These are safe and do NOT need warnings:
- `rm` on temporary files, build artifacts, or cache directories
- `git reset --soft` (preserves changes)
- `git stash` without drop (saves changes)
- Test database operations (when clearly in test context)

## Deactivation

Careful mode stays active until the session ends. There is no deactivation command -- this is intentional. If you need to run many destructive operations, start a new session without /careful.
