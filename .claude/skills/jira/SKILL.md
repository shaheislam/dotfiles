---
name: jira
description: Jira ticket management - create, update, search, and batch operations
arguments:
  - name: action
    description: "Action to perform: create, update, search, view, transition, batch-create"
    required: true
  - name: target
    description: "Ticket key (PROJ-123), JQL query, or file path for batch operations"
    required: false
---

# Jira Command

You are a Jira integration assistant using the Atlassian CLI (acli).

**Official Documentation**: https://developer.atlassian.com/cloud/acli/reference/commands/

## Available Actions

### 1. `create` - Create a single ticket
Create a new Jira work item interactively or from provided details.

```bash
# Interactive
acli jira workitem create

# With parameters
acli jira workitem create \
  --project PROJECT_KEY \
  --type Story|Bug|Task|Epic \
  --summary "Title" \
  --description "Description"
```

### 2. `update` - Update an existing ticket
Update fields on an existing work item.

```bash
acli jira workitem edit PROJ-123 \
  --summary "New title" \
  --description "New description"

# Add a comment
acli jira workitem comment add PROJ-123 --body "Comment text"
```

### 3. `search` - Search for tickets
Search using JQL queries.

```bash
# My tickets
acli jira workitem search --jql "assignee = currentUser()"

# Project tickets
acli jira workitem search --jql "project = PROJ AND status = 'In Progress'"

# Recent updates
acli jira workitem search --jql "updated >= -7d ORDER BY updated DESC"
```

### 4. `view` - View ticket details
```bash
acli jira workitem view PROJ-123
acli jira workitem view PROJ-123 --comments
```

### 5. `transition` - Change ticket status
```bash
acli jira workitem transition PROJ-123 --status "In Progress"
acli jira workitem transition PROJ-123 --status "Done"
```

### 6. `batch-create` - Create multiple tickets from markdown

When the user provides a markdown file path, parse it and create tickets.

**Expected markdown format:**

```markdown
## Epic Name

### Ticket Title

| Field | Value |
|-------|-------|
| **Type** | Story |
| **Summary** | Short title |
| **Description** | Detailed description |
| **Labels** | label1, label2 |
| **Story Points** | 5 |

### Another Ticket Title
...
```

**Batch creation workflow:**

1. Read the markdown file using the Read tool
2. Parse each ticket section (### headers)
3. Extract fields from the table format
4. For each ticket:
   - Show the user what will be created
   - Ask for confirmation before creating
   - Create using: `acli jira workitem create --project PROJECT --type TYPE --summary "SUMMARY" --description "DESC"`
5. Report created ticket keys

## Instructions

Based on the action argument ($ARGUMENTS), perform the appropriate operation:

1. **If action is `create`**:
   - If target is provided, try to parse it as ticket details
   - Otherwise, ask the user for project, type, summary, description
   - Create the ticket and report the new key

2. **If action is `update`**:
   - Target should be a ticket key (e.g., DEVOPS-123)
   - Ask what fields to update
   - Perform the update

3. **If action is `search`**:
   - If target is provided, use it as JQL
   - Otherwise, search for user's assigned tickets
   - Display results in a readable format

4. **If action is `view`**:
   - Target should be a ticket key
   - Show full ticket details

5. **If action is `transition`**:
   - Target should be a ticket key
   - Ask for new status or use provided status
   - Transition the ticket

6. **If action is `batch-create`**:
   - Target should be a file path
   - Read and parse the markdown file
   - Show preview of tickets to create
   - Ask user to confirm project key
   - Create tickets one by one, reporting progress
   - Optionally link tickets to an epic

## Project Discovery

To find available projects:
```bash
acli jira project list
```

To find valid issue types for a project:
```bash
acli jira project view PROJECT_KEY
```

## Error Handling

- If authentication fails, suggest: `jira-auth` (fish function) or `acli jira auth login`
- If project not found, list available projects
- If transition fails, show valid transitions for the ticket
- **"Service name is required, Domains is required"**: This error occurs when using `Task` type in JSM-enabled projects. Use `Story` type instead for regular tickets.

## Examples

```
/jira create
/jira view DEVOPS-489
/jira search "project = DEVOPS AND status = 'To Do'"
/jira transition DEVOPS-489
/jira batch-create docs/bedrock-devops-epics.md
/jira update DEVOPS-489
```

Now execute the requested action: $ARGUMENTS
