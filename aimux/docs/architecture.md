# Architecture

aimux is a two-layer system: a bash CLI dispatcher for user interaction and a Go daemon for background monitoring and queue dispatch.

## Component Diagram

```
                       +---------+
                       |  User   |
                       +----+----+
                            |
                     aimux <command>
                            |
                  +---------v----------+
                  |   bin/aimux (bash)  |
                  |   CLI dispatcher    |
                  +--------+--------+--+
                           |        |
            +--------------+        +------------------+
            |                                          |
   +--------v---------+                    +-----------v-----------+
   | lib/aimux/*.sh   |                    |   aimuxd (Go binary)  |
   | Subcommand shell |                    |   Background daemon   |
   | scripts          |                    +-----------+-----------+
   +---+---------+----+                                |
       |         |                          +----------+----------+
       |         |                          |          |          |
  +----v---+ +---v----+              +------v---+ +----v---+ +---v------+
  | tmux   | | git    |              | Poller   | | Queue  | | Notifier |
  | windows| | worktree|             | (state   | | Dispatch| | (bell,  |
  | panes  | | branches|            |  monitor)| | er     | |  OSC,   |
  +--------+ +--------+              +---------+ +--------+ |  native,|
                                                             |  webhook)|
                                                             +---------+
```

## Data Flow

### User Command

```
aimux new feature-auth
  |
  v
bin/aimux -- parses command, sources lib/aimux/new.sh
  |
  +-> git worktree add ../repo-feature-auth feature-auth
  +-> tmux new-window -n feature-auth -c ../repo-feature-auth
  +-> state_write (JSON to ~/.aimux/state/repo-feature-auth.json)
  +-> log entry to ~/.aimux/aimux.log
```

### Agent Execution

```
aimux run PROJ-123 "Fix the bug"
  |
  v
bin/aimux -- sources lib/aimux/run.sh
  |
  +-> Creates workspace (reuses new.sh logic)
  +-> provider_launch_cmd("claude", worktree, prompt)
  |     |
  |     +-> Reads providers.claude.command and args from config
  |     +-> Returns: claude --effort max -p "Fix the bug"
  |
  +-> tmux send-keys to workspace window
  +-> Writes state file with ticket metadata
  +-> Logs execution start
```

### Daemon Polling

```
aimuxd (Go binary)
  |
  +-> Every N seconds (poll_interval):
  |     |
  |     +-> tmux list-panes -a  (enumerate all panes)
  |     +-> For each pane with an agent process:
  |     |     +-> tmux capture-pane (get terminal content)
  |     |     +-> provider.detect_state(content) -> working/idle/done/stuck
  |     |     +-> Update state file (atomic JSON write)
  |     |     +-> Set tmux window color via @wname_style
  |     |     +-> If done: trigger notification (deduplicated)
  |     |
  |     +-> Queue dispatcher tick:
  |           +-> Check capacity (running < max_concurrent)
  |           +-> Dequeue highest-priority entry
  |           +-> Shell out: aimux run <ticket> <prompt>
  |
  +-> Signal handling: SIGTERM/SIGINT -> cleanup PID file, exit
```

## State Management

Workspace state is persisted as individual JSON files in `~/.aimux/state/`.

```
~/.aimux/
  config.toml           # User configuration (overrides defaults)
  aimux.log             # CLI activity log
  aimuxd.log            # Daemon log
  aimuxd.pid            # Daemon PID file (flock-guarded)
  state/
    repo-feature-auth.json
    repo-bugfix-login.json
  queue.json            # Ticket execution queue
  logs/
    repo-feature-auth.log  # Per-workspace agent output
  providers/             # User-defined custom providers
    my-agent.sh
```

### State File Schema

```json
{
  "name": "repo-feature-auth",
  "status": "active",
  "branch": "feature-auth",
  "worktree": "/Users/dev/repo-feature-auth",
  "repo": "/Users/dev/repo",
  "provider": "claude",
  "ticket": "PROJ-123",
  "prompt": "Fix the authentication bug",
  "created_at": "2026-03-14T10:00:00Z",
  "started_at": "2026-03-14T10:00:05Z",
  "agent_state": "working",
  "attempts": 1,
  "last_output_change": "2026-03-14T10:05:30Z",
  "tmux_target": "main:3.0",
  "last_checksum": "a1b2c3d4"
}
```

## Config Hierarchy

Configuration is resolved in this order (later wins):

```
1. Compiled defaults (config.go Default())
2. Shipped defaults  (config/default.toml in repo)
3. User config       (~/.aimux/config.toml)
4. Environment vars  (AIMUX_POLL_INTERVAL, AIMUX_DEFAULT_PROVIDER, etc.)
```

The bash scripts use `_config.sh` which follows the same hierarchy with its own TOML parser. The Go daemon uses `internal/config/config.go` with the `BurntSushi/toml` library. Both read the same config file.

## Provider System

Providers are pluggable shell scripts that define how to launch, detect, and read state from an AI agent. See `docs/providers.md` for the full API.

```
lib/aimux/providers/     # Built-in providers
  claude.sh
  codex.sh
  ollama.sh

~/.aimux/providers/      # User-defined providers (searched first)
  my-agent.sh
```

## Queue System

The queue is a priority-ordered list of tickets persisted in `~/.aimux/queue.json`. The daemon's dispatcher goroutine polls the queue and launches tickets when capacity is available.

```
Priority 0 = highest, default = 5

Queue states: queued -> dispatching -> running -> completed/failed
```

## Key Design Decisions

- **Bash for CLI, Go for daemon**: Bash gives fast startup and easy tmux/git integration. Go provides proper signal handling, file locking, and concurrent polling.
- **Atomic state writes**: Both bash (write to temp, rename) and Go (CreateTemp + Rename) use atomic file operations to prevent corruption.
- **Provider abstraction**: Agent-specific logic is isolated in provider scripts, keeping the core agnostic.
- **tmux as the substrate**: All workspace isolation and session management runs through tmux. This makes aimux work with any terminal emulator.
