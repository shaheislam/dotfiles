---
title: aimux pr
description: Create a GitHub PR from a workspace
---

## Usage

```bash
aimux pr [options] [workspace]
```

## Description

Pushes the workspace branch and creates a GitHub Pull Request. Auto-commits any uncommitted changes first. If no workspace is specified, uses the current worktree's branch.

The perfect companion to `aimux run` -- run a ticket autonomously, then create a PR for review with one command.

## Options

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--title TEXT` | `-t` | PR title | auto-generated from branch name |
| `--body TEXT` | `-b` | PR body / description | empty |
| `--draft` | `-d` | Create as a draft PR | |
| `--base BRANCH` | | Target branch for the PR | `main` |
| `--reviewer USER` | `-r` | Request review from a GitHub user (repeatable) | |
| `--label NAME` | `-l` | Add a label to the PR (repeatable) | |
| `--delete` | | Delete the workspace after PR creation | |
| `--open` | `-o` | Open the PR URL in your browser | |
| `--help` | `-h` | Show help | |

## Examples

```bash
# Create a PR from a workspace
aimux pr feature-auth

# Create a draft PR with a title
aimux pr --draft --title "feat: session timeout handling" feature-auth

# Create PR, request review, and open in browser
aimux pr -r teammate1 -r teammate2 --open feature-auth

# Create PR with labels
aimux pr --label bug --label priority-high proj-123

# Create PR and clean up the workspace
aimux pr --delete proj-124

# Create PR against a non-default base branch
aimux pr --base develop feature-auth

# Use from inside the workspace (no branch argument needed)
cd /Users/me/projects/myapp-feature-auth
aimux pr --draft
```

## What happens

1. **Resolves workspace** -- finds the worktree by branch name, path, or current directory
2. **Auto-commits** any uncommitted changes with a generated commit message
3. **Pushes branch** to `origin` with `git push -u origin <branch>`
4. **Creates PR** via the `gh` CLI with the specified title, body, and options
5. **Applies labels** and **requests reviewers** if specified
6. **Opens browser** if `--open` is set
7. **Prints PR URL** to stdout
8. **Cleans up workspace** via `aimux kill` if `--delete` is set

## Auto-generated titles

When `--title` is not provided, aimux generates a PR title from the branch name:

| Branch | Generated title |
|--------|----------------|
| `feature-auth` | `feature auth` |
| `proj-123` | `PROJ-123` |
| `fix-session-timeout` | `fix session timeout` |

Ticket-style branches (containing a number after a prefix) are uppercased to match common issue tracker formats.

## Notes

- Requires the [`gh` CLI](https://cli.github.com/) to be installed and authenticated (`gh auth login`)
- If `gh` is not found, aimux exits with a clear error directing you to install it
- The `--reviewer` and `--label` flags can be repeated to add multiple reviewers or labels
- If the branch has already been pushed, the push step is a fast no-op
- When used with `--delete`, cleanup happens only after the PR is successfully created
- Combine with `aimux run` for a full autonomous workflow: run the ticket, then PR the result
