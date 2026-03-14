# aimux — AI Agent Multiplexer: Product Plan

## Context

You asked whether your existing dotfiles tmux workflow could be productionized as an open-source competitor to cmux. After deep investigation:

**The answer is yes — but what was built in the previous iteration (the `aimux/` prototype in the dotfiles worktree) is a prototype, not a product.** The prototype's `aimux run` is just `tmux send-keys`, the config system doesn't exist, the daemon has race conditions, and tests only check exit codes.

**The market is crowded** — dmux (~1k stars), Tenex (~800 stars), amux, and cmux (6.2k stars) all exist. But none of them have what makes your dotfiles unique: **real autonomous ticket execution with retry loops, multi-provider bridge review, agent state monitoring, and queue management with rate-limit-aware dispatch.**

This plan creates a standalone `~/aimux` repo that extracts the production-quality orchestration from your dotfiles into a `brew install`-able product.

## Architecture: Bash CLI + Go Daemon

- **CLI (`bin/aimux`)**: Bash dispatcher sourcing subcommand scripts from `lib/aimux/`. Already proven in prototype — keep the pattern.
- **Daemon (`cmd/aimuxd`)**: Go binary for agent state polling, notifications, queue dispatch. Go gives us atomic PID handling, proper signal management, concurrent polling, and built-in TOML/JSON parsing.
- **Config**: TOML at `~/.aimux/config.toml`, environment variable overrides. Go daemon handles parsing; bash scripts query daemon or read env vars.
- **State**: JSON files in `~/.aimux/state/` written atomically by daemon, read by bash scripts via `jq`.
- **Providers**: Pluggable bash files — each provider implements `launch_cmd`, `detect`, `detect_state`. Custom providers go in `~/.aimux/providers/`.

### Key Design Decisions

1. **Daemon is optional** — `aimux new/status/kill/run` work without it. Daemon adds monitoring, notifications, and queue dispatch.
2. **No dotfiles dependency** — zero references to `~/dotfiles`, `gwt-*`, `devcon`, `bd`, `entire`, `ralph-loop`. Works after `brew install aimux` alone.
3. **Agents run IN tmux panes** — not as child processes. They're interactive TUI programs; users need to attach and interact. We launch via `tmux send-keys` but monitor via the daemon.
4. **Provider plugin system** — bash files in `~/.aimux/providers/`. Each implements 3 functions. Ships with claude, codex, ollama built-in.

## Repository Structure (`~/aimux`)

```
~/aimux/
├── bin/aimux                     # Bash CLI dispatcher
├── cmd/aimuxd/main.go            # Go daemon
├── internal/                     # Go daemon packages
│   ├── config/config.go          # TOML config
│   ├── daemon/{daemon,poller,notifier}.go
│   ├── provider/{provider,claude,codex,ollama}.go
│   ├── queue/{queue,dispatcher}.go
│   └── state/{workspace,agent}.go
├── lib/aimux/                    # Bash subcommands
│   ├── _common.sh, _config.sh, _provider.sh, _witness.sh
│   ├── new.sh, run.sh, status.sh, kill.sh, attach.sh
│   ├── doctor.sh, daemon.sh, queue.sh, notify.sh, log.sh, help.sh
│   └── providers/{claude,codex,ollama}.sh
├── templates/launch/{claude,codex,ollama}.sh.tmpl
├── config/{aimux.tmux.conf, default.toml}
├── completions/{aimux.fish, aimux.bash, _aimux}
├── tests/{unit/*.bats, integration/*.bats, daemon/*_test.go}
├── docs/{architecture,providers,configuration,migration}.md
├── Formula/aimux.rb
├── go.mod, Makefile, README.md, LICENSE, CHANGELOG.md
└── .github/workflows/{test,release}.yml
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2) — "It works for real"

**Goal**: `aimux new`, `status`, `kill`, `doctor` work with real integration tests in `~/aimux`.

**Steps:**
1. Init `~/aimux` repo, copy correct parts from prototype (`bin/aimux`, `_common.sh`, `help.sh`, `Makefile`, `LICENSE`, completions)
2. Rewrite `_common.sh` — remove dotfiles assumptions, add config loading stub
3. Create `_config.sh` — reads `~/.aimux/config.toml` via `yq` or env vars
4. Port `new.sh` — add `--repo` flag (so it works from any directory), add state file writing to `~/.aimux/state/`
5. Port `status.sh` — reads daemon state files when available, falls back to live `git worktree list` + tmux queries
6. Port `kill.sh` — already solid in prototype, add state cleanup
7. Port `doctor.sh` — add checks for claude CLI, codex CLI, Go daemon binary, config file
8. Create `config/default.toml` — default configuration template
9. Write integration tests: `tests/integration/setup_suite.bash` (creates temp git repo + tmux server), `test_new.bats`, `test_kill.bats`, `test_status.bats`
10. Write unit tests: `tests/unit/test_common.bats`

**Key source files to port from:**
- `dotfiles/.config/fish/functions/gwt-dev.fish` (251 LOC) → `lib/aimux/new.sh`
- `dotfiles/.config/fish/functions/gwt-status.fish` (356 LOC) → `lib/aimux/status.sh`
- `dotfiles/.config/fish/functions/gwt-doctor.fish` (409 LOC) → `lib/aimux/doctor.sh`
- `dotfiles/scripts/tmux/tmux-worktree-cleanup.sh` (170 LOC) — reuse in `kill.sh`

### Phase 2: Go Daemon + Monitoring (Weeks 3-4) — "It watches and notifies"

**Goal**: `aimuxd` binary polls tmux panes, detects agent state, sends OS notifications, colors tmux windows.

**Steps:**
1. Init Go module (`go mod init github.com/shaheislam/aimux`)
2. Implement `internal/config/config.go` — TOML parsing with defaults
3. Implement `internal/state/workspace.go` — atomic JSON read/write for workspace state
4. Implement `internal/state/agent.go` — state machine (idle → working → done/stuck)
5. Implement `internal/daemon/poller.go` — port `tmux-claude-watcher.sh` detection logic:
   - `tmux list-panes -a` for all panes
   - `ps -t $tty` for agent process detection
   - `tmux capture-pane -p -S -20` for content analysis
   - Spinner detection (`… (`), completion markers (`COMPLETE`, `_DONE`, `TICKET_TASK_COMPLETE`)
   - **Real stuck timeout** — track `last_output_change` timestamp, mark stuck after configurable threshold
6. Implement `internal/daemon/notifier.go` — multi-channel: OSC 9/99, native OS (osascript/notify-send), webhook, terminal bell
7. Implement `internal/daemon/daemon.go` — main loop, proper PID file with `flock`, signal handling (SIGTERM graceful shutdown)
8. Implement `cmd/aimuxd/main.go` — CLI flags, daemon start
9. Rewrite `lib/aimux/daemon.sh` — manages Go binary lifecycle (start/stop/status)
10. Update Makefile — add `build` target for `go build -o lib/aimux/aimuxd cmd/aimuxd/main.go`
11. Go tests + integration tests for daemon lifecycle

**Key source file:**
- `dotfiles/scripts/tmux/tmux-claude-watcher.sh` (180 LOC) — the proven detection patterns to port to Go

### Phase 3: Autonomous Execution (Weeks 5-7) — "It runs tickets"

**Goal**: `aimux run TICKET-123 "prompt"` creates workspace, launches agent, monitors to completion with retries. **This is the crown jewel.**

**Steps:**
1. Create `lib/aimux/_provider.sh` — provider abstraction: `provider_launch_cmd`, `provider_detect`, `provider_detect_state`
2. Create `lib/aimux/providers/claude.sh` — Claude Code launch command builder, detection patterns
3. Create `lib/aimux/providers/codex.sh` — Codex launch command builder
4. Create `lib/aimux/providers/ollama.sh` — Ollama launch command builder
5. Create `templates/launch/claude.sh.tmpl` — launch script template that configures env vars, cd to worktree, invokes agent with prompt
6. Rewrite `lib/aimux/run.sh` — the complete autonomous execution flow:
   - Parse ticket args (ticket ID, prompt, provider, options)
   - Call `aimux new` to create workspace
   - Build prompt from template + user message
   - Write launch script to workspace (`$worktree/.aimux/launch.sh`)
   - Set up tmux pane layout
   - Execute launch script via `tmux send-keys`
   - Write state file with ticket metadata
   - Start witness process
7. Create `lib/aimux/_witness.sh` — per-workspace lifecycle monitor:
   - Polls pane for completion promise string
   - Handles retry on agent failure (agent exits, witness restarts after delay)
   - Stuck detection (delegates to daemon, but handles timeout locally too)
   - Post-completion actions (notification, state file update)
8. Integration tests with mocked agent (simple bash script that outputs completion markers)

**Key source file:**
- `dotfiles/.config/fish/functions/gwt-ticket.fish` (2,308 LOC) — decompose into `run.sh` + `_provider.sh` + `_witness.sh`. Critical sections: prompt building (lines ~1390-1499), launch script generation (lines ~1556-1762), tmux layout (lines ~2000-2108).

### Phase 4: Queue System (Weeks 8-9) — "It queues and dispatches"

**Goal**: `aimux queue add/list/start/stop/status` with rate-limit-aware dispatch.

**Steps:**
1. Implement `internal/queue/queue.go` — JSON queue persistence, add/remove/list
2. Implement `internal/queue/dispatcher.go` — rate-limit checking, dispatch via invoking `aimux run`
3. Rewrite `lib/aimux/queue.sh` — CLI interface to queue daemon
4. Add usage checking per provider (adapt `claude-usage.sh` pattern)
5. Integration tests

**Key source file:**
- `dotfiles/scripts/ticket-queue/queue-daemon.sh` (769 LOC) — dispatch logic, rate-limit checking

### Phase 5: Polish + Release (Weeks 10-12) — "It's a real product"

**Steps:**
1. Plugin loading system — `~/.aimux/providers/*.sh` auto-discovered
2. Complete documentation (README with GIF demos, getting-started guide, vs-cmux comparison)
3. Homebrew tap setup with GitHub Actions release automation
4. CI/CD pipeline (lint, shellcheck, BATS tests, Go tests, cross-platform)
5. CHANGELOG, contribution guidelines
6. `aimux log` subcommand for viewing agent output logs
7. `aimux attach` with session manager (port `tmux-session-manager.sh`)

## What Gets Dropped (for now)

These dotfiles features are NOT in scope for the initial product. They can be plugins later:
- Gastown patterns (convoys, molecules, town-beads, mayor)
- Crown tournament mode (multi-agent council voting)
- Beads memory integration
- Checkpoint integration (`entire` CLI)
- Subscription profile rotation (`claude-sub`)
- Codex account rotation (`codex-rotate`)
- OpenClaw integration
- Devcontainer-specific features (devcon, auto-login)

## Verification

After each phase, verify:
1. **Phase 1**: `aimux new test-branch && aimux status && aimux kill test-branch` works from a fresh git repo. `bats tests/` passes.
2. **Phase 2**: `aimux daemon start && sleep 15 && aimux daemon status` shows running. Open Claude Code in a tmux pane — daemon detects state and colors window. OS notification fires on completion.
3. **Phase 3**: `aimux run TEST-001 "Create a hello world script"` creates worktree, launches claude, agent executes, completion detected. `aimux status` shows state transitions.
4. **Phase 4**: `aimux queue add TEST-002 "Fix bug" && aimux queue list` shows queued ticket. `aimux queue start` dispatches when capacity available.
5. **Phase 5**: `brew install aimux` from tap works. New user with only tmux + git installed can run through quickstart guide.
