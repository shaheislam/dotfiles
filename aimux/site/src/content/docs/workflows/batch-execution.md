---
title: Batch Execution
description: Queue multiple tickets and execute them with priority dispatch
---

## Overview

Batch execution is aimux's answer to the question: "I have 20 tasks. How do I get them all done without babysitting?" The queue system dispatches tickets respecting concurrency limits and cooldown periods.

## The workflow

### 1. Queue your tickets

```bash
aimux queue add PROJ-100 "Fix login page CSS" --priority 10
aimux queue add PROJ-101 "Add input validation to signup form" --priority 8
aimux queue add PROJ-102 "Refactor database queries for performance" --priority 5
aimux queue add PROJ-103 "Write unit tests for utils module" --priority 3 --provider codex
aimux queue add PROJ-104 "Update API documentation" --priority 1
```

Priority determines dispatch order: higher numbers go first. The `--provider` flag lets you assign different agents to different tasks.

### 2. Review the queue

```bash
aimux queue list
```

```
TICKET          PROVIDER     STATUS     PRI      ADDED                PROMPT
─────────────── ──────────── ────────── ──────── ──────────────────── ──────────────────────────────
PROJ-100        claude       queued     10       2026-03-14T10:00:00Z Fix login page CSS
PROJ-101        claude       queued     8        2026-03-14T10:00:01Z Add input validation to sig...
PROJ-102        claude       queued     5        2026-03-14T10:00:02Z Refactor database queries ...
PROJ-103        codex        queued     3        2026-03-14T10:00:03Z Write unit tests for utils...
PROJ-104        claude       queued     1        2026-03-14T10:00:04Z Update API documentation
```

### 3. Start the dispatcher

```bash
aimux queue start
```

The dispatcher:

- Checks capacity every `cooldown` seconds (default: 60)
- If fewer than `max_concurrent` (default: 3) tickets are running, dispatches the next highest-priority ticket
- Calls `aimux run` for each ticket, which creates a workspace and launches the agent
- Monitors state files to detect completed or failed runs
- Updates queue status as tickets progress through `dispatching` -> `running` -> `completed`/`failed`

### 4. Start the monitoring daemon

```bash
aimux daemon start
```

This provides real-time tmux window coloring and desktop notifications.

### 5. Walk away

The queue dispatcher and daemon run in the background. You will receive notifications as tickets complete.

### 6. Review results

```bash
# Overall status
aimux status
aimux queue status

# Check specific results
aimux log PROJ-100
aimux attach proj-100
git diff
```

## Configuration

Tune queue behavior in `~/.aimux/config.toml`:

```toml
[queue]
max_concurrent = 3     # Run up to 3 agents simultaneously
cooldown = 60          # Wait 60 seconds between dispatches
```

### Aggressive (high-throughput)

```toml
[queue]
max_concurrent = 6     # 6 simultaneous agents
cooldown = 30          # Dispatch every 30 seconds

[general]
stuck_timeout = 600    # Give agents 10 minutes before stuck detection
```

### Conservative (rate-limit safe)

```toml
[queue]
max_concurrent = 2     # Only 2 simultaneous agents
cooldown = 120         # Wait 2 minutes between dispatches

[general]
poll_interval = 30     # Poll less frequently
```

## Managing the queue

### Remove a ticket

```bash
aimux queue remove PROJ-104
```

### Clear completed/failed entries

```bash
aimux queue clear
```

This keeps queued and dispatching entries but removes completed and failed ones.

### Stop the dispatcher

```bash
aimux queue stop
```

Running tickets continue to execute; the dispatcher simply stops dispatching new ones.

### Check dispatcher status

```bash
aimux queue status
```

```
Queue Status
  Dispatcher: running (PID: 54321)
  Total:      5
  Queued:     1
  Running:    2
  Completed:  2
  Failed:     0
  Max conc:   3
  Cooldown:   60s
```

## Combining with webhooks

Get Slack or Discord notifications for each completed ticket:

```toml
[notifications]
channels = ["native", "webhook"]
webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Tips

- Start with `max_concurrent = 2` and increase if your system and API quotas can handle it
- Use higher priority numbers for tasks you want done first (priority 10 before priority 1)
- Queue lightweight tasks (docs, tests) at lower priority so they fill in gaps
- Monitor system resources with `htop` or `top` -- each agent process uses CPU and memory
- The dispatcher PID is stored in `/tmp/aimux-queue.pid`
