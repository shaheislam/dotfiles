Create a pull request for the current branch.

## Steps
1. Run `git status` — all changes must be committed
2. Check for open beads: `bd list --status=in_progress` — close or note any that are done
3. Determine the base branch (usually `main`)
4. Run any available linters/tests before creating the PR
5. Generate a PR title from the branch name or recent commits
6. Write a PR description:
   - **What**: Summary of changes
   - **Why**: Motivation and context (reference beads IDs if applicable)
   - **How**: Implementation approach
   - **Testing**: How the changes were verified
7. Create the PR: `gh pr create --base main --title "type: description" --body "..."`
8. Output the PR URL

## Rules
- Never force-push without asking
- Never use emojis in the PR title
- Never reference AI assistants in the PR title or body
- Use conventional commit style: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`
- Keep PR title under 72 chars
- If there are multiple commits, summarize the overall change
- If this is an ephemeral worktree branch, note that it merges locally (no upstream push)
