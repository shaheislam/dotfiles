Check CI status for the current branch or a specific PR.

## Steps
1. If a PR number is given, check that PR. Otherwise find the PR for the current branch.
2. Run `gh pr checks` to see CI status
3. If any checks failed:
   - Show the failed check names and URLs
   - Fetch the log for the first failure: `gh run view <run-id> --log-failed`
   - Suggest a fix if the error is clear
4. If all checks pass, confirm success
5. If no PR exists, inform the user and suggest creating one

## Output Format
- Use a table for check statuses when there are multiple
- Highlight failures prominently
- Include direct links to failed runs
