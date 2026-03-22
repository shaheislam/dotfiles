# Gap Analysis: superset-sh/superset vs dotfiles

Comparison of patterns from [superset-sh/superset](https://github.com/superset-sh/superset)
(Electron-based "Terminal for Coding Agents") with our dotfiles git worktree infrastructure.

## Implemented

### 1. Port Allocation System (P2)
**Gap**: Multiple worktree devcontainers competing for the same ports (3000, 8080, etc).
**Superset pattern**: `~/.superset/port-allocations.json` with mkdir-based file locking.
**Our implementation**:
- `scripts/port-allocator.sh` — JSON-backed allocator, 20 ports per worktree
- `gwt-ports` Fish function — auto-detects worktree from git context
- Integrated into `gwt-dev.fish` (auto-allocate) and `tmux-worktree-cleanup.sh` (auto-release)
- Named offsets: PORT_APP, PORT_API, PORT_DEV, PORT_DB, PORT_REDIS, etc.

### 2. Centralized Agent Commands (P2)
**Gap**: Agent prompts only existed in `.claude/skills/`, not shared with Codex.
**Superset pattern**: `.agents/commands/` as single source of truth with symlinks.
**Our implementation**:
- `.agents/commands/` with 4 shared commands: create-pr, ci-check, deslop, respond-to-pr-comments
- `scripts/sync-agent-commands.sh` — creates relative symlinks to `.claude/commands/`
- Generates `.codex/instructions.md` with command references
- Auto-syncs during `gwt-setup`

### 3. Structured Setup/Teardown Steps (P3)
**Gap**: `gwt-setup.fish` was monolithic with no step tracking or idempotency.
**Superset pattern**: Numbered steps with skip/failure tracking and summary output.
**Our implementation**:
- `scripts/worktree-setup-steps.sh` — 6 steps with JSON state file
- Idempotent: re-runs skip completed steps
- Supports `--force`, `--step N`, `--status`, `--reset`, `--dry-run`
- `gwt-setup.fish` delegates to step system with legacy fallback

### 4. Multi-Agent MCP Config Parity (P2)
**Gap**: MCP servers only configured for Claude Code, not Codex/OpenCode.
**Superset pattern**: Single `.mcp.json` at root, replicated to all agent configs.
**Our implementation**:
- `scripts/sync-mcp-config.sh` — converts `.mcp.json` into:

  - Codex: appends `[mcp_servers.*]` TOML sections
  - OpenCode: generates `opencode.json`
- Auto-syncs during `gwt-setup`

## Deferred (Not Implemented)

### Neon DB Branching per Worktree
**Superset**: Creates a Neon PostgreSQL branch per worktree, tears down on cleanup.
**Why deferred**: Project-specific; our worktrees are for dotfiles/general dev, not DB-backed apps.
**When relevant**: If gwt-ticket is used for projects with Neon databases.

### ElectricSQL per Worktree
**Superset**: Runs a Docker ElectricSQL container per workspace for real-time sync.
**Why deferred**: Too application-specific for a dotfiles setup.

### Caddy Reverse Proxy for Local Dev
**Superset**: Uses Caddy for HTTP/2 SSE streams to bypass browser 6-connection limit.
**Why deferred**: Only useful for specific app architectures (SSE-heavy).

### CI Triage with Claude Code
**Superset**: GitHub Actions workflow that runs `claude -p` to auto-triage issues.
**Why deferred**: Useful pattern but requires GitHub Actions setup per-repo, not dotfiles-level.
**Recommendation**: Create a reusable workflow template in `.github/workflows/`.

### Desktop App (Electron GUI)
**Superset**: Full GUI with diff viewing, workspace switching, agent monitoring.
**Why deferred**: Our tmux + Fish functions achieve similar goals in the terminal.
**Overlap**: Both systems use git worktrees as the core isolation primitive.

## Architectural Observations

### What Superset Does Better
1. **Port conflict prevention** is built-in from day one (now implemented)
2. **Multi-agent first**: configs for 5+ agents maintained in parity
3. **Step-based setup/teardown** with clear failure/skip reporting
4. **Desktop automation MCP**: agents can control the IDE itself

### What Our Dotfiles Do Better
1. **Agent lifecycle management**: triage, nudge, witness, merge-queue, phase-gates
2. **Beads memory system**: persistent agent memory across sessions
3. **Subscription profiles**: multi-account round-robin with usage-limit failover
4. **tmux integration**: color-coded windows, auto-cleanup, WAKE keystrokes
5. **Queue system**: rate-limit-aware ticket queue with daemon
