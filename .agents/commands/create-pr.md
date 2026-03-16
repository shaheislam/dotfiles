Create a pull request for the current branch.

## Steps
1. Check `git status` — all changes must be committed
2. Determine the base branch (usually `main`)
3. Run any available linters/tests before creating the PR
4. Generate a PR title from the branch name or recent commits
5. Write a PR description that includes:
   - **What**: Summary of changes
   - **Why**: Motivation and context
   - **How**: Implementation approach
   - **Testing**: How the changes were verified
6. Create the PR using `gh pr create`
7. Output the PR URL

## Rules
- Never force-push without asking
- Keep PR title concise (<72 chars)
- Use conventional commit style for the title (feat:, fix:, chore:, etc.)
- If there are multiple commits, summarize them; don't list each one
