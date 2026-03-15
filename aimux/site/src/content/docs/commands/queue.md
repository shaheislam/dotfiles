---
title: aimux queue
description: Ticket queue management with priority dispatch
---

## Usage

```bash
aimux queue <subcommand> [options]
```

**Alias:** `aimux q`

## Description

Manages a priority queue of tickets for batch execution. The dispatcher processes tickets by launching `aimux run` for each entry, respecting concurrency limits and cooldown periods.

## Subcommands

### queue add

Add a ticket to the queue.

```bash
aimux queue add [options] <ticket> [prompt...]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--provider NAME` | `-P` | AI provider to use | from config (`claude`) |
| `--priority N` | `-p` | Priority 1-10, higher number dispatched first | `5` |
| `--help` | `-h` | Show help | |

**Examples:**

```bash
aimux queue add PROJ-123 "Fix the authentication bug"
aimux queue add PROJ-124 "Add rate limiting" --provider codex
aimux queue add HOTFIX-001 "Fix production outage" --priority 10
aimux queue add PROJ-125 "Write unit tests" --provider codex --priority 3
```

### queue list

Display all queued tickets in a formatted table, sorted by priority.

```bash
aimux queue list
```

**Alias:** `aimux queue ls`

Example output:

```
TICKET          PROVIDER     STATUS     PRI      ADDED                PROMPT
─────────────── ──────────── ────────── ──────── ──────────────────── ──────────────────────────────
HOTFIX-001      claude       queued     10       2026-03-14T10:00:00Z Fix production outage
PROJ-123        claude       running    5        2026-03-14T09:00:00Z Fix the authentication bug
PROJ-124        codex        queued     5        2026-03-14T09:30:00Z Add rate limiting
PROJ-125        codex        completed  3        2026-03-14T09:45:00Z Write unit tests
```

Status values are color-coded:
- **Cyan** = queued (waiting)
- **Yellow** = dispatching (being launched)
- **Red** = running (agent active)
- **Green** = completed
- **Red** = failed

### queue start

Start the background dispatcher process.

```bash
aimux queue start
```

The dispatcher:
- Runs as a background process with its PID stored in `/tmp/aimux-queue.pid`
- Polls the queue every `cooldown` seconds (default: 60)
- Checks capacity: if fewer than `max_concurrent` (default: 3) tickets are running, dispatches the next one
- Selects the highest-priority queued entry
- Marks tickets as `dispatching` then `running` on success, or `failed` on dispatch failure
- Monitors state files to detect completed or failed runs

### queue stop

Stop the dispatcher process.

```bash
aimux queue stop
```

Sends SIGTERM to the dispatcher and removes the PID file. If the PID file references a dead process, it cleans up the stale file.

### queue status

Show dispatcher status and queue statistics.

```bash
aimux queue status
```

Example output:

```
Queue Status
  Dispatcher: running (PID: 12345)
  Total:      8
  Queued:     3
  Running:    2
  Completed:  2
  Failed:     1
  Max conc:   3
  Cooldown:   60s
```

### queue remove

Remove a specific ticket from the queue.

```bash
aimux queue remove <ticket>
```

**Alias:** `aimux queue rm`

Removes all entries matching the ticket key, regardless of status.

### queue clear

Clear completed and failed entries from the queue.

```bash
aimux queue clear
```

Keeps `queued` and `dispatching` entries intact, removing only `completed` and `failed` entries.

## Queue configuration

Settings in `~/.aimux/config.toml`:

```toml
[queue]
max_concurrent = 3   # Maximum simultaneous ticket executions
cooldown = 60        # Seconds between dispatch cycles
```

Or via environment variables:

```bash
export AIMUX_QUEUE_MAX_CONCURRENT=5
export AIMUX_QUEUE_COOLDOWN=30
```

## Queue file

The queue is persisted as a JSON array in `~/.aimux/queue.json`:

```json
[
  {
    "ticket": "PROJ-123",
    "prompt": "Fix the auth bug",
    "provider": "claude",
    "priority": 5,
    "status": "queued",
    "added_at": "2026-03-14T10:00:00Z",
    "started_at": null,
    "completed_at": null
  }
]
```

## Notes

- The dispatcher requires `jq` and `tmux` to be available
- Queue operations (`add`, `list`, `remove`, `clear`) require `jq`
- The dispatcher calls `aimux run` for each ticket, so all `run` options apply (witness, provider, etc.)
- If the dispatcher is already running, `queue start` is a no-op
- Priority uses higher-number-first ordering (priority 10 is dispatched before priority 1)
