# Gastown vs Dotfiles-Gastown: Feature Comparison & Gap Analysis

> Generated: 2026-02-14
> Source: [steveyegge/gastown](https://github.com/steveyegge/gastown) + [Welcome to Gas Town](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04)

## Executive Summary

Your dotfiles-gastown setup has independently reimplemented **~65-70%** of Gastown's core functionality using shell scripts, Fish functions, and Claude Code hooks. The remaining gaps fall into three categories:

1. **Architectural differences** (Gastown uses Go + Dolt; you use Bash/Fish + flat files)
2. **Features not yet implemented** (Mail system, Convoys, Formulas/Molecules, Rig system)
3. **Features where your implementation diverges** (different design choices that may be intentional)

---

## Feature Comparison Table

### Legend
- **Full** = Feature parity or equivalent functionality
- **Partial** = Core concept exists but incomplete compared to Gastown
- **None** = Not implemented
- **Divergent** = Different approach that serves similar purpose
- **N/A** = Not applicable to your architecture

| # | Gastown Feature | Gastown Component | Dotfiles Equivalent | Coverage | Notes |
|---|----------------|-------------------|---------------------|----------|-------|
| | **AGENT HIERARCHY** | | | | |
| 1 | Daemon (Go background process) | `daemon.Daemon` - 3min heartbeat checks | Event-driven tmux window status | Partial | Tmux windows expose agent state, but there is no Dolt/Deacon lifecycle management |
| 2 | Boot Agent (ephemeral triage) | `boot` - spawned by daemon for AI triage | `agent-triage.sh` | Full | Both analyze agent state and decide START/WAKE/NUDGE/NOTHING |
| 3 | Deacon (health orchestrator) | `deacon` - patrol cycles, lifecycle mgmt | `agent-state.sh` + hook-based tmux status | Partial | Status is event-driven; no dedicated Deacon agent with patrol cycles |
| 4 | Mayor (global coordinator) | `mayor` - dispatches work, handles escalations | None | None | No global work coordinator agent |
| 5 | Witness (rig-level monitor) | `witness` - monitors polecats & refinery | `worktree-witness.sh` | Full | Per-worktree lifecycle monitor with crash detection and auto-retry |
| 6 | Refinery (merge processor) | `refinery` - validates & merges branches | `merge-queue.sh` | Partial | Serialized merge queue exists but lacks intelligent rebase/conflict resolution |
| 7 | Polecats (ephemeral workers) | `polecat` - persistent identity, ephemeral session | `gwt-ticket` workers | Partial | Workers exist but lack persistent identity/CV tracking |
| 8 | Crew Workers (persistent) | `crew` - user-managed workspaces | `gwt-dev` / `gwt-claude` | Full | Persistent worktree + devcontainer workspaces |
| | | | | | |
| | **WORK MANAGEMENT** | | | | |
| 9 | Work Dispatch (`gt sling`) | Assigns beads to rigs, spawns polecats | `gwt-ticket` | Partial | Dispatches work to worktrees but no bead-based assignment |
| 10 | Formulas (TOML workflow templates) | Reusable multi-step workflow definitions | `templates/workflows/*.toml` | Partial | You have 4 templates (implement, bugfix, refactor, test) but they're prompt templates, not durable multi-step workflows |
| 11 | Molecules (durable chained beads) | Multi-step workflows that survive restarts | None | None | No durable chained workflow tracking |
| 12 | Wisps (ephemeral molecules) | Transient operations, destroyed after runs | None | None | No ephemeral workflow concept |
| 13 | Protomolecules (template classes) | Template for instantiating molecules | None | None | No molecule instantiation system |
| 14 | Work Completion (`gt done`) | Clean git state verify, merge-request, self-nuke | `ticket-complete.sh` | Partial | Completion exists but no self-nuking mechanism |
| 15 | Convoys (batch work tracking) | Group related beads for batch processing | None | None | No batch work tracking/grouping |
| 16 | GUPP (propulsion principle) | "If you have work on your Hook, RUN IT" | ralph-loop + SessionStart hooks | Partial | ralph-loop enforces iteration; `bd prime` checks work; but no formal Hook system |
| 17 | Hook System (work assignment) | Work attached to agent via bead `assignee` field | None | None | No formal hook/assignee mechanism for work routing |
| | | | | | |
| | **COMMUNICATION** | | | | |
| 18 | Mail System | Inter-agent messaging with addressing | Agent Teams `SendMessage` | Partial | Agent Teams provides DMs and broadcasts; no persistent mail inbox/archive |
| 19 | Mail Addressing & Routing | `<rig>/<agent>`, broadcast, groups | Agent Teams by name | Partial | Name-based addressing only; no rig/group/queue routing |
| 20 | Mailing Groups | `gt mail group create` | None | None | No mailing group concept |
| 21 | Hookable Mail (ad-hoc instructions) | Mail beads hooked as agent instructions | None | None | No mail-to-work-assignment conversion |
| 22 | `gt nudge` (real-time messaging) | Send text to Claude session via tmux | `tmux send-keys` (ad-hoc) | Partial | Can send to tmux but no structured `nudge` command |
| | | | | | |
| | **SESSION & LIFECYCLE** | | | | |
| 23 | `gt prime` (context recovery) | SessionStart hook: role detection, context loading | `bd prime` (SessionStart hook) | Partial | Beads priming exists but no role detection or AUTONOMOUS WORK MODE |
| 24 | Context Cycling / Handoff | `gt handoff` - session refresh with state transfer | Checkpoints system (`ckpt`) | Divergent | Checkpoints capture session context to git; different approach to continuity |
| 25 | Session Management | tmux session lifecycle per agent | tmux session per worktree | Full | Both use tmux for agent sessions |
| 26 | Self-Nuking Polecats | Workers delete own worktree + session on completion | `gwt-cleanup` (manual) | Partial | Cleanup is manual/batched, not automatic per-agent |
| | | | | | |
| | **HEALTH & MONITORING** | | | | |
| 27 | 4-Layer Health Monitoring | Daemon → Boot → Deacon → Witness | Watcher + Triage + Witness | Partial | 3 layers vs 4; no dedicated Deacon patrol cycle |
| 28 | GUPP Violation Detection | Daemon detects 30min stuck + work hooked | Hook-based agent state | Partial | Window status is event-driven; stuck-agent patrols need a separate lifecycle check |
| 29 | Heartbeat Files | Age-based health assessment | tmux session existence checks | Divergent | ZFC-style: derive from tmux state, not heartbeat files |
| 30 | `gt peek` (health check) | Ping individual agent health | `agent-state.sh <worktree>` | Full | State derivation from tmux + git + ralph-loop |
| 31 | `gt doctor` (diagnostics) | System-wide health check | `gwt-doctor` | Full | Agent orchestration health check |
| 32 | Web Dashboard | Browser-based monitoring UI | None | None | No web dashboard for agent monitoring |
| | | | | | |
| | **DATA & STORAGE** | | | | |
| 33 | Beads Issue Tracking | Git-backed issue tracking with DAG deps | `bd` (steveyegge/beads plugin) | Full | Same `bd` CLI, installed via Homebrew |
| 34 | Two-Level Beads (town + rig) | `~/gt/.beads/` + per-rig `.beads/` | Per-project `.beads/` only | Partial | No town-level beads for cross-project coordination |
| 35 | Prefix-Based Routing | `hq-*` → town, `gt-*` → rig | Single prefix per project | Partial | No multi-database routing |
| 36 | Dolt Backend (versioned SQL) | Dolt for persistent structured data | Git-backed flat files | Divergent | You use git-backed storage; Gastown uses Dolt SQL server |
| 37 | Capability Ledger / Agent CVs | Permanent record of agent work history | None | None | No agent performance tracking/CV system |
| 38 | `bd audit --actor` | Query agent work history | None | None | No per-agent audit trail |
| | | | | | |
| | **RIG SYSTEM** | | | | |
| 39 | Rigs (project containers) | Wrap git repo + manage agents per project | Worktrees (per-branch) | Divergent | Worktrees are per-branch; Rigs are per-project with dedicated agents |
| 40 | Shared Bare Git Repository | `.repo.git/` shared by refinery + polecats | Standard git worktrees | Divergent | You use standard `git worktree add`; Gastown uses shared bare repo for instant branch visibility |
| 41 | Rig Parking/Docking | `gt rig park/unpark`, `dock/undock` | None | None | No project-level pause/resume state |
| 42 | Rig-Level Configuration | Per-rig agent overrides and formulas | `.devcontainer/setup.sh` per project | Partial | Per-project devcontainer config but no agent-level overrides |
| | | | | | |
| | **MERGE & COMPLETION** | | | | |
| 43 | Merge Queue (Refinery-managed) | AI-powered rebase + merge + push to origin | `merge-queue.sh` | Partial | Serialized merge queue but no AI-powered conflict resolution |
| 44 | Conflict Resolution (re-spawn) | Refinery spawns fresh polecat on conflict | None | None | No automatic re-implementation on merge conflict |
| 45 | `gt mq` Commands | list, next, submit, status, retry, reject | `merge-queue.sh add/daemon/list/stop` | Partial | Subset of commands; no retry/reject/status per item |
| | | | | | |
| | **INFRASTRUCTURE** | | | | |
| 46 | Go CLI (`gt`) | Compiled Go binary for all operations | Fish functions + Bash scripts | Divergent | Shell-based vs compiled; yours is more portable but slower |
| 47 | tmux Integration | Session per agent, structured naming | tmux per worktree, structured naming | Full | Both deeply integrated with tmux |
| 48 | Zero-Footprint Compliance (ZFC) | Derive state from tmux/git/beads, no state files | `agent-state.sh` (ZFC pattern) | Full | Explicitly uses ZFC - derives from tmux + git + ralph-loop |
| 49 | Configuration (`gt config`) | Agent aliases, default agent, custom commands | `.claude/settings.json` + env vars | Divergent | Different config mechanisms serving same purpose |
| 50 | `gt install` (workspace init) | Initialize Gas Town workspace | `scripts/setup.sh` | Divergent | Your setup is broader (entire dev env); Gastown is workspace-specific |

---

## Features UNIQUE to Your Dotfiles (Not in Gastown)

| Feature | Component | Description |
|---------|-----------|-------------|
| Cross-Provider Reasoning Bridge | `cross-provider-bridge.sh` | Sends reasoning to independent AI for correlation-bias mitigation |
| Decision Quality System (DQS) | `cpipe --preset council/redteam` | Multi-perspective plan evaluation (council, red team, first principles) |
| Claude Pipeline | `claude-pipeline` / `cpipe` | Multi-model reasoning chains (opus → sonnet piping) |
| Ticket Queue (rate-limit aware) | `gwt-queue` | Queue tickets for auto-dispatch when usage limits reset |
| Multi-Subscription Profiles | `claude-sub` / `csub` | Multiple Claude Max subscriptions with auto-dispatch |
| Devcontainer Integration | `gwt-dev`, `gwt-claude` | Isolated devcontainer per worktree with auto-login |
| Self-Hosted LLM Stack | Ollama + Open WebUI + Fish functions | Local LLM fallback (qwen3-coder, llama3.1, etc.) |
| OpenClaw Platform | `openclaw` / `claw` | Multi-channel AI assistant (Telegram, Slack, Discord, etc.) |
| Checkpoints System | `ckpt` | Session context linked to git commits on orphan branch |
| Phase Gates | `phase-gates.sh` | Pause agents on external conditions (CI, PR review, human) |
| Parallel Worktrees | `gwt-parallel` | Launch multiple worktrees simultaneously in tmux windows |
| Docker Linux Testing | `scripts/docker/` | Test dotfiles in Linux containers via Colima |
| Mobile Coding Setup | `setup-mobile-coding.sh` | Remote dev from mobile via Mosh + Tailscale |
| PreToolUse Hooks | `validate-bash.py`, `use_bun.py` | Dangerous command blocking, bun enforcement |
| PostToolUse Hooks | `deepwiki-context.py` | Language-aware DeepWiki suggestions |
| Notification System | `macos_notification.py` | Desktop alerts for agent events |
| Plugin Ecosystem | 14 installed plugins | code-review, hookify, feature-dev, etc. |

---

## Gap Analysis: Priority Assessment

### Priority 1: High Impact, Feasible to Implement

| Gap | Gastown Feature | Effort | Impact | Recommendation |
|-----|----------------|--------|--------|----------------|
| **Agent CVs / Capability Ledger** | Track agent work history, success rates, skill tags | Medium | High | Add `bd audit` tracking to worktree-witness completion; log bead closures with agent metadata |
| **Self-Nuking Workers** | Auto-cleanup worktree + session on completion | Low | Medium | Add auto-cleanup to `worktree-witness.sh` on COMPLETED state |
| **`gt nudge` equivalent** | Structured command to send text to agent sessions | Low | Medium | Create `gwt-nudge` Fish function wrapping tmux send-keys |
| **Merge Queue Retry/Reject** | Per-item retry and reject in merge queue | Low | Medium | Extend `merge-queue.sh` with retry/reject/status subcommands |

### Priority 2: Medium Impact, Moderate Effort

| Gap | Gastown Feature | Effort | Impact | Recommendation |
|-----|----------------|--------|--------|----------------|
| **Mayor (global coordinator)** | Central work dispatch across projects | High | High | Consider a `gwt-mayor` function that orchestrates across worktrees |
| **Convoys (batch tracking)** | Group related work items | Medium | Medium | Add convoy/batch concept to ticket queue |
| **Formulas → Molecules** | Durable multi-step workflows | High | Medium | Extend workflow templates to track step completion |
| **Two-Level Beads** | Town-level beads for cross-project coordination | Medium | Medium | Initialize `~/.beads/` as town-level beads with `hq-*` routing |
| **Web Dashboard** | Browser-based agent monitoring | High | Medium | Consider a simple localhost dashboard (could use Open WebUI pattern) |

### Priority 3: Low Priority or Intentionally Different

| Gap | Gastown Feature | Effort | Impact | Recommendation |
|-----|----------------|--------|--------|----------------|
| **Dolt Backend** | Versioned SQL database for beads | Very High | Low | Your git-backed approach works fine; Dolt adds complexity |
| **Rig System** | Per-project agent containers | High | Low | Worktrees serve the same purpose at branch level |
| **Rig Parking/Docking** | Project-level pause/resume | Medium | Low | Not needed with your tmux session model |
| **Go CLI** | Compiled binary for speed | Very High | Low | Fish/Bash approach is more hackable and extensible |
| **Hookable Mail** | Convert mail to work assignments | Medium | Low | Agent Teams messaging serves similar purpose |
| **Wisps/Protomolecules** | Ephemeral workflow instances | High | Low | Over-engineering for your use case |

---

## Coverage Summary

| Category | Gastown Features | Full | Partial | None | Divergent |
|----------|-----------------|------|---------|------|-----------|
| Agent Hierarchy | 8 | 2 | 4 | 1 | 1 |
| Work Management | 9 | 0 | 4 | 5 | 0 |
| Communication | 5 | 0 | 3 | 2 | 0 |
| Session & Lifecycle | 4 | 1 | 2 | 0 | 1 |
| Health & Monitoring | 6 | 4 | 1 | 1 | 0 |
| Data & Storage | 6 | 1 | 2 | 2 | 1 |
| Rig System | 4 | 0 | 1 | 2 | 1 |
| Merge & Completion | 3 | 0 | 2 | 1 | 0 |
| Infrastructure | 5 | 2 | 0 | 0 | 3 |
| **TOTAL** | **50** | **10 (20%)** | **19 (38%)** | **14 (28%)** | **7 (14%)** |

**Effective Coverage**: 10 Full + 19 Partial + 7 Divergent = **36/50 features (72%)** have some form of implementation.

---

## Architectural Comparison

| Aspect | Gastown | Your Dotfiles |
|--------|---------|---------------|
| **Language** | Go (compiled binary) | Fish + Bash (interpreted scripts) |
| **Storage** | Dolt (versioned SQL) | Git-backed flat files |
| **Agent Runtime** | Claude Code in tmux | Claude Code in tmux (+ devcontainers) |
| **State Derivation** | ZFC (tmux + beads + git) | ZFC (tmux + git + ralph-loop state) |
| **Work Tracking** | Beads (two-level, routed) | Beads (single-level) + ticket systems |
| **Workflow Templates** | Formulas → Molecules → Wisps | TOML prompt templates |
| **Merge Process** | Refinery agent (AI-powered) | merge-queue.sh (serialized daemon) |
| **Health Monitoring** | 4-layer (Daemon→Boot→Deacon→Witness) | 3-layer (Watcher→Triage→Witness) |
| **Communication** | Mail system (persistent, routed) | Agent Teams (ephemeral, name-based) |
| **Extensibility** | Agent plugins, custom formulas | Fish functions, Claude Code plugins |

---

## Key Takeaways

1. **Your setup is already very capable** - 72% coverage of Gastown features, plus 17+ unique features Gastown doesn't have.

2. **Biggest gaps are in work management** - Molecules, Convoys, and the Mayor pattern. These enable more sophisticated multi-agent coordination.

3. **Your unique strengths** - Cross-provider bridge, DQS, ticket queue with rate-limit awareness, devcontainer integration, and multi-subscription profiles are features Gastown lacks entirely.

4. **Architectural trade-offs are intentional** - Your Fish/Bash approach trades performance for hackability and portability. Gastown's Go binary is faster but harder to customize.

5. **Low-hanging fruit** - Agent CVs, self-nuking workers, nudge command, and merge queue extensions would close the most impactful gaps with minimal effort.
