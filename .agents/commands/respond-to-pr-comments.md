Address PR review comments for the current branch.

## Steps
1. Find the PR for the current branch: `gh pr view --json number,url`
2. List review comments: `gh pr view --comments`
3. For each unresolved comment:
   - Read the comment and understand the request
   - Check the referenced code
   - Make the requested change (or explain why not)
   - If the change is made, note it
4. Commit all changes with: `fix: address PR review feedback` (no emojis, no AI references)
5. Push the changes
6. If beads are tracking this work, add a comment: `bd comments add <ID> "Addressed PR feedback: <summary>"`
7. Summarize what was addressed and what needs discussion

## Rules
- Address all comments, don't cherry-pick
- If a comment is unclear, explain what you understood and what you did
- Don't force-push; create a new commit for review visibility
- If a comment requests a design change you disagree with, explain the trade-off but make the change unless it introduces a bug
- For Fish function changes: test with `fish --no-execute <file>` before committing
- For Bash script changes: test with `bash -n <file>` before committing
