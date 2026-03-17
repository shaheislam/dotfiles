Check CI status for the current branch or a specific PR.

## Steps
1. If a PR number is given, check that PR. Otherwise find the PR for the current branch.
2. Run `gh pr checks` to see CI status
3. If any checks failed:
   - Show the failed check names and URLs
   - Fetch the log for the first failure: `gh run view <run-id> --log-failed`
   - Suggest a fix if the error is clear
   - If a beads issue exists for this work, add a comment: `bd comments add <ID> "CI failure: <summary>"`
4. If all checks pass, confirm success
5. If no PR exists, check if this is an ephemeral worktree branch (no upstream) — if so, run local validation instead:
   - Fish syntax check: `fish --no-execute .config/fish/functions/*.fish` for any changed fish files
   - Shell lint: `bash -n scripts/*.sh` for any changed bash scripts
   - Stow dry-run: `stow --simulate --restow .` if dotfiles changed

## Output Format
- Use a table for check statuses when there are multiple
- Highlight failures prominently
- Include direct links to failed runs
