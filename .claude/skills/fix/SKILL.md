---
name: fix
description: Use when something breaks in dotfiles (stow conflict, missing PATH, broken Fish function, stale hook), when /wrap-up validation fails, or when you want a health check of the dotfiles setup. Also use when seeing symptoms like "command not found", symlink errors, theme inconsistency, or MCP server failures.
---

# Fix — Diagnose, Repair, Verify

Triage-and-dispatch skill. Runs existing diagnostic scripts, routes to existing repair skills, verifies fixes. Does not contain repair logic — it connects diagnostics to repairs.

## Arguments

- `$ARGUMENTS` — Optional:
  - Symptom text: `/fix stow symlinks are broken` → keyword-match to relevant diagnostic
  - `--category CAT` — Run only one category: `stow|path|theme|shell|hooks|docs|mcp|otel|packages|state`
  - `--dry-run` — Diagnose only, no repairs

Bare `/fix` runs all diagnostics.

## Phase 1: Run Diagnostics

Run from the dotfiles root directory. Non-zero exit means "issues found" (expected), not "script broken."

```bash
# Strip ANSI color codes from output for parsing
scripts/harness/detect-drift.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
scripts/harness/test-architecture.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
scripts/harness/validate-docs.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
```

If `--category` was specified, run only the relevant script(s):

| Category | Script(s) |
|----------|-----------|
| `stow` | detect-drift.sh |
| `path` | detect-drift.sh |
| `theme` | detect-drift.sh |
| `packages` | detect-drift.sh |
| `otel` | detect-drift.sh + test-architecture.sh |
| `state` | detect-drift.sh |
| `shell` | test-architecture.sh |
| `hooks` | test-architecture.sh |
| `docs` | validate-docs.sh + test-architecture.sh |
| `mcp` | validate-docs.sh |

If symptom text provided instead of `--category`, keyword-match:
- "symlink", "stow", "link" → detect-drift.sh
- "fish", "function", "bash", "script", "shell" → test-architecture.sh
- "doc", "CLAUDE.md", "reference", "MCP", "parity" → validate-docs.sh
- Ambiguous → run all three

## Phase 2: Classify Issues

Parse output by prefix. Each script uses consistent prefixes:

| Prefix | Severity | Source |
|--------|----------|--------|
| `DRIFT:` | CRITICAL | detect-drift.sh |
| `FAIL` | HIGH | test-architecture.sh |
| `ISSUE:` | HIGH | validate-docs.sh |
| `WARN:` | MEDIUM | any |
| `SKIP` | LOW | test-architecture.sh |

Lines with `OK:` or `PASS` are healthy — skip them.

If no issues found: report "No issues found — dotfiles are healthy." and stop.

## Phase 3: Present Triage Table

```
--- FIX TRIAGE ---
#  Sev       Category    Issue
1  CRITICAL  stow        .tmux.conf symlink wrong target
2  HIGH      shell       gwt-dev.fish missing --description
3  MEDIUM    path        PATH '/opt/homebrew/bin' in Fish but not Zsh
---
```

If `--dry-run`, stop here.

If more than 5 issues, show top 5 and ask: "5 of N issues shown. Fix these first, or show all?"

## Phase 4: Route to Repair

For each issue, use this routing table. **Safe = auto-fix. Unsafe = show planned action, request approval.**

| Issue Pattern | Repair | Safe? |
|---|---|---|
| Stow symlink wrong/missing | Invoke `/dotfiles-sync` | No (--adopt can overwrite) |
| PATH in Fish but not Zsh | Edit `.zshrc` to add PATH | No (modifies file) |
| PATH in Zsh but not Fish | Add `fish_add_path` to config.fish | No (modifies file) |
| Script not executable | `chmod +x <script>` | Yes |
| OTEL container not running | `otel start` via Fish | Yes |
| Stale PID/state files | `rm <stale-file>` | Yes |
| Orphan processes | Flag for manual review | N/A |
| Fish config broken | Invoke `/fish-reload` | Yes |
| Git config issue | Invoke `/git-config-fix` | Yes |
| MCP parity gap | Invoke `/mcp-restart` + flag config sync needed | Partial |
| Missing shebang in script | Prepend `#!/usr/bin/env bash` | No (modifies file) |
| Hook script not executable | `chmod +x <hook>` | Yes |
| Hardcoded paths | Flag for manual review | N/A |
| Function name mismatch | Flag for manual review | N/A |
| Missing doc references | Flag for manual review | N/A |
| Brewfile/setup.sh parity | Flag for manual review | N/A |

## Phase 5: Verify Each Fix

After each repair, re-run the specific diagnostic script that found the issue. Parse for the same check.

- **FIXED**: Issue gone from re-run output
- **STILL_BROKEN**: Issue persists

If STILL_BROKEN and `.claude/CHANGELOG.md` exists, append:
```
[TIMESTAMP] FAILED: /fix could not resolve: <issue>. Attempted: <repair>. Manual intervention needed.
```

Do NOT retry STILL_BROKEN issues. Mark as failed and move to next.

## Phase 6: Summary

```
--- FIX SUMMARY ---
Total: 5 | Fixed: 3 | Manual: 1 | Failed: 1
Suggestion: Run /wrap-up to commit changes.
---
```

If fixes modified files, suggest `/wrap-up`. If all clean, done.

## Common Mistakes

- **Treating non-zero exit as script failure**: detect-drift.sh exits 1 when drift is found — that's the expected success case for `/fix`
- **Running repairs without dry-run first for stow**: Always `stow --simulate` before actual stow. `/dotfiles-sync` handles this.
- **Retrying STILL_BROKEN issues**: Dead ends are dead ends. Append FAILED to CHANGELOG and move on.
- **Fixing hardcoded paths automatically**: These require understanding intent. Always flag for manual review.
