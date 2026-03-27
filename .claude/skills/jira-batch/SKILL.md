---
name: jira-batch
description: Batch create Jira tickets from epic markdown files
arguments:
  - name: file
    description: "Path to markdown file containing epic/ticket definitions"
    required: true
  - name: project
    description: "Jira project key (e.g., DEVOPS) - overrides file setting"
    required: false
  - name: options
    description: "Options: --dry-run, --skip-epic, --labels label1,label2"
    required: false
---

# Jira Batch Create Command

Create Jira Epic and associated tickets from a structured markdown file.

## File Format

The command expects files with this structure:

```yaml
---
epic:
  summary: "Epic Title"
  type: Epic
  description: |
    Multi-line description...
  labels:
    - label1
    - label2
  priority: High
project: DEVOPS
---

# Epic Title

## Tickets

| id | type | summary | description | labels | points | dependencies |
|----|------|---------|-------------|--------|--------|--------------|
| XX-1 | Story | Title | Description text | label1,label2 | 5 | |
| XX-2 | Story | Title | Description text | label1 | 3 | XX-1 |
```

## Execution Workflow

### Step 1: Parse File

1. Read the file using the Read tool
2. Parse YAML frontmatter for epic metadata
3. Parse the ticket table in the ## Tickets section
4. Extract: id, type, summary, description, labels, points, dependencies

### Step 2: Display Preview

Show what will be created:

```
Epic: [summary]
Project: [project]
Priority: [priority]
Labels: [labels]

Tickets to create: X

| # | ID   | Type  | Summary                    | Points | Deps |
|---|------|-------|----------------------------|--------|------|
| 1 | AC-1 | Story | AgentCore Runtime Setup    | 8      | -    |
| 2 | AC-2 | Story | Agent Observability...     | 5      | AC-1 |
```

### Step 3: Confirm with User

Ask: "Create this epic and X tickets in project DEVOPS? (y/n)"

If --dry-run specified, stop here.

### Step 4: Create Epic (unless --skip-epic)

```bash
acli jira workitem create \
  --project PROJECT \
  --type Epic \
  --summary "Epic Summary" \
  --description "Epic description"
```

Capture the created epic key (e.g., DEVOPS-500).

### Step 5: Create Tickets

For each ticket in order:

```bash
acli jira workitem create \
  --project PROJECT \
  --type "Story" \
  --summary "Ticket summary" \
  --description "Ticket description" \
  --parent EPIC-KEY \
  --label "label1,label2"
```

Capture created key and build mapping: `local_id -> JIRA-KEY`

### Step 6: Create Dependency Links

For tickets with dependencies, after all tickets are created:

```bash
acli jira workitem link create \
  --out DEPENDENT-KEY \
  --in DEPENDENCY-KEY \
  --type "Blocks" \
  --yes
```

Use the mapping to resolve local IDs to Jira keys.

### Step 7: Report Results

```
Created Epic: DEVOPS-500 - Bedrock AgentCore Platform Foundation

Created Tickets:
| Local ID | Jira Key   | Summary                      | Linked |
|----------|------------|------------------------------|--------|
| AC-1     | DEVOPS-501 | AgentCore Runtime Setup      | ✓      |
| AC-2     | DEVOPS-502 | Agent Observability...       | ✓      |

Dependencies Created:
- DEVOPS-502 blocked by DEVOPS-501
- DEVOPS-503 blocked by DEVOPS-501

Total: 1 Epic, 8 Tickets, 7 Links
```

## Command Options

- `--dry-run`: Preview without creating
- `--skip-epic`: Create tickets only, provide existing epic key
- `--labels extra,labels`: Add additional labels to all items

## Error Handling

- If ticket creation fails, log error and continue
- Report failures at end with manual commands
- Dependency links only created if both tickets exist

## acli Commands Reference

```bash
# Create epic
acli jira workitem create --project PROJ --type Epic --summary "Title" --description "Desc"

# Create ticket with parent
acli jira workitem create --project PROJ --type Story --summary "Title" --parent EPIC-KEY

# Link tickets
acli jira workitem link create --out KEY-1 --in KEY-2 --type "Blocks" --yes
```

## Example Usage

```
/jira-batch docs/jira/epic-4-platform-foundation.md
/jira-batch docs/jira/epic-4-platform-foundation.md DEVOPS --dry-run
/jira-batch docs/jira/epic-1-cloudwatch-response.md DEVOPS
```

---

Now process: $ARGUMENTS
