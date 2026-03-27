---
name: todo
description: Quick ticket creation - auto-detects Linear (personal) or Jira (work)
arguments:
  - name: description
    description: "Ticket description (prefix with 'bug:' or 'fix:' for bug type)"
    required: true
---

# Todo Command

Create a ticket in the appropriate issue tracker based on the current repository context.

## Ticketing System Detection

Detect the ticketing system in this order:

1. **Check `.claude/settings.local.json`** for explicit config:
   ```json
   { "ticketing": { "system": "linear", "project": "ENG" } }
   ```

2. **Check for `.linear.toml`** in repo root → Linear

3. **Check git remote** for known patterns:
   - `petlab` in remote → Jira (PETLAB project)
   - `dfe-digital` in remote → Jira (DFE project)
   - `home-office` in remote → Jira (HO project)
   - Personal repos (github.com/shaheislam) → Linear

4. **If ambiguous**, ask user to choose.

## Instructions

Based on the description: $ARGUMENTS

### 1. Detect Type

Determine if this is a bug or a task:
- Contains "bug:", "fix:", "broken", "crash", "error" → Bug
- Otherwise → Task/Story

### 2. Parse Title and Description

- **Title**: First sentence or the full text if short (< 80 chars)
- **Description**: Full provided text

### 3. Detect Ticketing System

Run detection logic above. Check:

```bash
# Check for local settings
cat .claude/settings.local.json 2>/dev/null | jq -r '.ticketing.system // empty'

# Check for Linear config
test -f .linear.toml && echo "linear"

# Check git remote
git remote get-url origin 2>/dev/null
```

### 4. Create the Ticket

**For Linear:**
```bash
# Create issue (interactive will prompt for team if needed)
linear issue create --title "$TITLE" --description "$DESCRIPTION"

# Or with team specified
linear issue create --team ENG --title "$TITLE" --description "$DESCRIPTION"
```

**For Jira:**
```bash
# Determine project from context or settings
PROJECT=$(cat .claude/settings.local.json 2>/dev/null | jq -r '.ticketing.project // empty')

# Create issue
acli jira workitem create \
  --project "$PROJECT" \
  --type "$TYPE" \
  --summary "$TITLE" \
  --description "$DESCRIPTION"
```

### 5. Report Result

Output the created ticket key (e.g., ENG-123 or DEVOPS-456) and URL.

Example output:
```
Created: ENG-123 - Fix auth bug in session.ts
URL: https://linear.app/workspace/issue/ENG-123
```

## Examples

```
/todo Fix auth bug in session.ts
→ Creates Bug: "Fix auth bug in session.ts"

/todo Add pagination to users API
→ Creates Task: "Add pagination to users API"

/todo bug: Login fails after password reset
→ Creates Bug: "Login fails after password reset"
```

## Error Handling

- If Linear CLI not authenticated: `linear config` to authenticate
- If Jira not authenticated: `acli jira auth login`
- If project not found: List available projects and ask user to choose

Now create the ticket from: $ARGUMENTS
