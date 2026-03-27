---
name: ticket-execute
description: Execute a ticket autonomously using devcontainer + ralph-loop
arguments:
  - name: ticket
    description: "Ticket key (ENG-123 or PROJ-123) or leave empty for fzf picker"
    required: false
allowed-tools: ["Bash(~/dotfiles/scripts/ticket-execute.sh:*)"]
---

# Ticket Execute Command

Autonomously execute a ticket using a dedicated worktree, devcontainer, and ralph-loop.

## Architecture

```
/ticket-execute [ENG-123]
        │
        ▼
┌───────────────────────────────────────────┐
│  tmux: <repo-name>                        │
│  ┌─────────────────────────────────────┐  │
│  │ Worktree: ../repo-eng-123-fix-auth │  │
│  │ Devcontainer running               │  │
│  │ Ralph loop (20 iterations max)     │  │
│  │ → Auto PR on completion            │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

## Instructions

Based on the ticket argument: $ARGUMENTS

### 1. Detect Ticketing System

Same detection as `/todo`:
- Check `.claude/settings.local.json` for explicit config
- Check for `.linear.toml` → Linear
- Check git remote for known patterns
- If unclear, ask user

### 2. Get Ticket Key

**If ticket provided:**
Use the provided key directly (e.g., ENG-123, DEVOPS-456).

**If no ticket provided:**
Use fzf to pick from backlog:

**For Linear:**
```bash
# List my issues in current team
linear issue list --mine | fzf --preview 'linear issue view {1}'
```

**For Jira:**
```bash
# List assigned issues
acli jira workitem search --jql "assignee = currentUser() AND status != Done" --output table | fzf
```

### 3. Fetch Ticket Details

**For Linear:**
```bash
linear issue view $TICKET_KEY
```
Extract: title, description, state

**For Jira:**
```bash
acli jira workitem view $TICKET_KEY
```
Extract: summary, description, status

### 4. Transition to In Progress

**For Linear:**
```bash
linear issue start $TICKET_KEY
```

**For Jira:**
```bash
acli jira workitem transition $TICKET_KEY --status "In Progress"
```

### 5. Launch Autonomous Execution

Execute the orchestration script:

```bash
~/dotfiles/scripts/ticket-execute.sh "$TICKET_KEY" "$TITLE" "$DESCRIPTION" --max 20 --system "$SYSTEM"
```

Where:
- `$TICKET_KEY` is the issue key (ENG-123)
- `$TITLE` is the issue title/summary
- `$DESCRIPTION` is the full description
- `--max 20` sets ralph-loop iterations (configurable)
- `--system` is "linear" or "jira"

### 6. Report Status

```
Ticket ENG-123 is now being executed autonomously.

Monitoring:
  tmux attach -t <repo-name>
  tmux select-window -t <repo-name>:ENG-123

Post-completion:
  - PR will be created automatically
  - Ticket will transition to Review/Done
```

## Options

- `--max N`: Set max iterations (default: 20)
- `--command C`: Slash command to use (default: /ralph-loop:ralph-loop)
- `--prompt-template F`: Custom prompt template file
- `--prompt-prefix P`: Text to prepend to prompt
- `--prompt-suffix S`: Text to append to prompt
- `--session S`: Tmux session name (default: repo name)
- `--system S`: Ticketing system: linear or jira
- `--mount M`: Additional mount directory (repeatable)
- `--devcon`: Use devcontainer for isolation (default: local)
- `--dry-run`: Show what would be executed without running

## Prompt Template Variables

Custom templates support these variables:
- `{{ISSUE_KEY}}`: Issue key (e.g., ENG-123)
- `{{TITLE}}`: Issue title
- `{{DESCRIPTION}}`: Issue description
- `{{WORKTREE_PATH}}`: Path to worktree
- `{{COMPLETION_PROMISE}}`: Completion string (e.g., TICKET_ENG-123_COMPLETE)

## Examples

```
/ticket-execute ENG-123
→ Fetches ENG-123, creates worktree, launches ralph-loop

/ticket-execute
→ Opens fzf picker to select from backlog

/ticket-execute DEVOPS-456 --max 10
→ Execute with 10 iteration limit
```

## Error Handling

- If ticket not found: Show error and suggest searching
- If worktree exists: Reuse existing worktree
- If devcontainer fails: Fall back to local environment
- If tmux session exists: Add new window, don't recreate

Now execute ticket: $ARGUMENTS
