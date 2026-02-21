---
name: jira
description: Jira ticket management - create, update, search, and batch operations
argument-hint: "<action> [target]"
user-invocable: true
---

# Jira Command

You are a Jira integration assistant using the Atlassian CLI (acli).

**Official Documentation**: https://developer.atlassian.com/cloud/acli/reference/commands/

## Available Actions

### 1. `create` - Create a single ticket
```bash
acli jira workitem create --project PROJECT_KEY --type Story|Bug|Task|Epic --summary "Title" --description "Description"
```

### 2. `update` - Update an existing ticket
```bash
acli jira workitem edit PROJ-123 --summary "New title" --description "New description"
acli jira workitem comment add PROJ-123 --body "Comment text"
```

### 3. `search` - Search for tickets
```bash
acli jira workitem search --jql "assignee = currentUser()"
acli jira workitem search --jql "project = PROJ AND status = 'In Progress'"
```

### 4. `view` - View ticket details
```bash
acli jira workitem view PROJ-123
acli jira workitem view PROJ-123 --comments
```

### 5. `transition` - Change ticket status
```bash
acli jira workitem transition PROJ-123 --status "In Progress"
```

### 6. `batch-create` - Create multiple tickets from markdown
Read markdown file, parse ticket sections, and create each ticket with confirmation.

## Instructions

Based on the action argument ($ARGUMENTS), perform the appropriate operation.

## Error Handling

- If authentication fails, suggest: `jira-auth` (fish function) or `acli jira auth login`
- If project not found, list available projects
- If transition fails, show valid transitions for the ticket
- **"Service name is required, Domains is required"**: Use `Story` type instead of `Task` in JSM-enabled projects.

## Examples

```
/jira create
/jira view DEVOPS-489
/jira search "project = DEVOPS AND status = 'To Do'"
/jira transition DEVOPS-489
/jira batch-create docs/epics.md
```

Now execute the requested action: $ARGUMENTS
