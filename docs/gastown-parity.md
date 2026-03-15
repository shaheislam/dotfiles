# Gastown Parity Analysis

> Analysis of our gwtt setup vs Steve Yegge's Gastown + Beads system.
> Reference: https://github.com/steveyegge/gastown + https://github.com/steveyegge/beads

## Summary

Our gwtt setup has **~95% parity** with Gastown/Beads. The core orchestration
infrastructure is complete. Round 1 addressed native Beads primitive integration
(merge-slot, gate, swarm) and fixed bugs. Round 2 (post-article analysis) added
patrol exponential backoff, GUPP hook beads, and `gwt-nudge`.

## Parity Matrix

### Gastown Core Roles

| Gastown Concept | Our Equivalent | Status |
|-----------------|----------------|--------|
| Polecat (transient worker) | `gwt-ticket` | ✅ Full parity |
| Witness (lifecycle monitor) | `worktree-witness.sh` | ✅ Full parity + backoff |
| Refinery (merge queue) | `merge-queue.sh` | ✅ + bd merge-slot |
| Mayor (global coordinator) | `gwt-mayor.sh` | ✅ Full parity + backoff |
| Deacon (health daemon) | `worktree-witness.sh` + `gwt-mayor.sh` | ✅ Distributed |
| Convoy (work tracking) | `convoy.sh` | ✅ Full parity |
| Rig (project container) | worktree + devcontainer | ✅ Full parity |
| Town (workspace) | `~/.claude/` + multi-sub | ✅ Full parity |
| Crews (persistent workers) | Claude Code TUI sessions | ✅ Manual |
| Agent registry | `claude-sub` profiles | ✅ Full parity |
| Formula (reusable workflows) | `templates/workflows/*.toml` | ✅ Full parity |
| Patrols (ephemeral loops) | Witness + Mayor loops | ✅ With exponential backoff |
| GUPP Hook bead | gwt-ticket hook wisp | ✅ Ephemeral hook event |
| gt nudge | `gwt-nudge` | ✅ Added |
| Wisps (ephemeral beads) | `bd create --ephemeral` | ✅ Used in hook + nudge |

### Beads Core Features

| Beads Feature | Our Equivalent | Status |
|---------------|----------------|--------|
| `bd prime` | SessionStart hook | ✅ Wired |
| `bd prime` | PreCompact hook | ✅ Wired |
| `bd init` | gwt-ticket auto-init | ✅ Per-worktree |
| `bd create` | gwt-ticket creates bead | ✅ Fixed: uses --external-ref |
| `bd ready` | `gwt-queue bd-ready` | ✅ Added |
| `bd merge-slot` | merge-queue.sh | ✅ Integrated |
| `bd gate` | phase-gates.sh | ✅ Integrated |
| `bd swarm` | gwt-ticket --swarm-epic | ✅ Added |
| `bd swarm status` | `bd swarm status` direct | ✅ Use bd directly |
| Molecules | `molecule.sh` + `bd swarm` | ✅ Full parity |
| Town Beads | `town-beads.sh` | ✅ Cross-project sync |

### Gastown Advanced Features

| Feature | Status | Notes |
|---------|--------|-------|
| `bd federation` (p2p) | ❌ Not implemented | Complex; future |
| `bd cook` (formulas) | ✅ Partial | Our TOML templates cover core use cases |
| ZFC state derivation | ✅ `agent-state.sh` | Same pattern |
| Propulsion principle | ✅ ralph-loop | Agents execute immediately |
| GUPP Hook beads | ✅ gwt-ticket hook wisp | Ephemeral hook bead on startup |
| gt nudge | ✅ `gwt-nudge` | Tmux WAKE + optional sling |
| gt handoff | ❌ Not implemented | Future: /resume-based session handoff |
| gt seance | ❌ Not implemented | Future: predecessor session querying |
| Dogs/Boot the Dog | ❌ Not implemented | Future: Deacon helper pattern |
| NDI (nondeterministic idempotence) | ✅ molecule.sh chains | Same guarantee pattern |
| Mol Mall | ❌ Not implemented | Community formula marketplace |
| Integration Tiers 0-3 | ✅ Informal | claude-sub + devcontainer covers all tiers |
| Cross-provider bridge | ✅ Extension beyond Gastown | We add cross-provider review |
| Checkpoints | ✅ Extension beyond Gastown | Session ↔ commit linking |
| Multi-subscription | ✅ Extension beyond Gastown | Rate-limit-aware scheduling |
| Agent CVs | ✅ Extension beyond Gastown | Per-agent lifecycle tracking |
| Dashboard | ✅ `agent-dashboard.sh` | Web UI at :8787 |

## Changes Made

### Round 2 (Post-Article Analysis, v0.7.0)

7. **worktree-witness.sh + gwt-mayor.sh**: Added patrol exponential backoff.
   Gastown patrols back off when idle rather than using fixed polling intervals.
   Both daemon loops now double their sleep when inactive (up to 300s cap),
   resetting immediately when there's activity to process. Reduces idle CPU/noise.

8. **gwt-ticket.fish**: Added GUPP Hook bead on startup. Per the Gastown Universal
   Propulsion Principle ("If there is work on your hook, YOU MUST RUN IT"), each
   polecat now creates an ephemeral hook bead (wisp) via `bd create --ephemeral`
   when spawning. The wisp is labeled `gt:hook,gt:gupp` and uses the `agent.hooked`
   event category, making the GUPP handoff visible in Beads.

9. **gwt-nudge**: New `gwt-nudge` function (Gastown `gt nudge` equivalent).
   Sends a WAKE keystroke to an idle agent's tmux pane via `agent-triage.sh`.
   Optional `--sling` flag creates an ephemeral nudge event bead in Beads.
   ```fish
   gwt-nudge                        # Nudge agent in current worktree
   gwt-nudge my-feature             # Nudge by worktree name
   gwt-nudge --message "Check CI"   # Custom message
   gwt-nudge --sling                # Nudge + sling hook event wisp
   ```

### Round 1 (Initial Parity)

### Bug Fixes

1. **gwt-ticket.fish**: Fixed `bd create` call — was using issue key as positional
   title arg AND `--title` simultaneously. Now correctly uses:
   ```fish
   bd create "$title" --external-ref "$issue_key" --description "$description"
   ```
   The `--external-ref` field links the bead to the Linear/Jira ticket key.

2. **gwt-ticket.fish**: Fixed stale `~/dotfiles-gastownbeads/` paths → `~/dotfiles-gastown/`
   in 4 places (agent-state, phase-gates, merge-queue, worktree-witness fallbacks).

### New Features

3. **merge-queue.sh**: Added `bd merge-slot` integration. When a worktree has a
   `.beads` database, the Refinery now uses Beads' native distributed merge slot
   for exclusive access instead of only using the file-based lock. This prevents
   the "monkey knife fight" problem where multiple agents race to merge simultaneously.
   Falls back gracefully when Beads is unavailable.

4. **phase-gates.sh**: Added `bd gate` integration:
   - New `bd-bead` gate type: waits for a cross-rig bead to close
     (`BD_AWAIT_ID=<rig>:<bead-id>`)
   - `ci-pipeline`, `pr-review`, and `human-input` gates now mirror to native
     Beads gates when `.beads` is present (enabling `bd gate check` to evaluate them)
   - `bd gate check` can now auto-resolve GitHub Actions and PR gates

5. **gwt-ticket.fish**: Added `--swarm-epic ID` flag. When specified with a bead
   epic ID, creates a `bd swarm` molecule to orchestrate parallel polecat work
   on the epic's children.

6. **gwt-queue.fish**: Added `bd-ready` command. Queries `bd ready` from a
   Beads-enabled repo and imports unblocked issues into the ticket queue:
   ```fish
   gwt-queue bd-ready --repo ~/myproject --limit 5 --sub personal
   gwt-queue bd-ready --dry-run  # Preview without queuing
   ```

## Usage Examples

### Work Discovery from Beads

```fish
# See what work is unblocked in a beads-enabled project
cd ~/myproject
gwt-queue bd-ready --dry-run

# Import and queue for dispatch
gwt-queue bd-ready --limit 5 --sub personal
gwt-queue start
```

### Epic Swarm

```fish
# Start a polecat swarm for a Beads epic
gwt-ticket bd-epic123 "Auth overhaul" "OAuth2 + RBAC" --swarm-epic bd-abc12

# Check swarm status
cd ~/myproject && bd swarm status
```

### Cross-Rig Bead Gate

```fish
# Gate this worktree on a bead in another project closing
phase-gates.sh create bd-bead /path/to/worktree

# Check if the referenced bead is done
BD_AWAIT_ID=gastown:bd-xyz99 phase-gates.sh check bd-bead /path/to/worktree
```

### Native Merge Slot (Automatic)

When `merge-queue.sh process` runs on a worktree with `.beads`, it automatically:
1. Creates a merge slot bead (idempotent)
2. Acquires exclusive access (60s timeout)
3. Performs the merge
4. Releases the slot

This serializes merges at the Beads level, visible to all agents in the rig.

## What Gastown Has That We Don't

1. **`bd federation`** — Peer-to-peer federation between Gas Towns (cross-machine
   bead sync). Complex distributed systems feature; not needed for single-machine setup.

2. **Full `bd cook` / formula execution** — Gastown has a 3-tier formula resolution
   system (project → town → system). Our TOML templates are simpler but cover
   the same use cases via gwt-ticket `--template`.

3. **Formal Tier 0-3 agent integration** — Gastown formalizes agent provider
   integration levels. We have this informally via claude-sub profiles + devcontainer
   auto-login.

4. **`gt handoff`** — Graceful agent session refresh with work continuation.
   Not implemented; `/resume` in ralph-loop is the closest analog.

5. **`gt seance`** — Agents querying predecessor sessions (what was previously
   decided). Gastown's `ckpt resume` equivalent but at agent-to-agent level.
   Our checkpoints system does this for humans, not agents.

6. **Dogs/Boot the Dog** — Deacon's maintenance helpers; Boot checks on Deacon
   every 5 min. Not implemented; our Mayor serves the coordinator role without helpers.

7. **Mol Mall** — Community formula marketplace. Not implemented; formulas live
   locally in `templates/workflows/`.

## Architecture Notes

**Why We Outperform in Some Areas**:
- **Multi-subscription scheduling**: Our `gwt-queue` has sophisticated rate-limit-aware
  multi-subscription dispatch that Gastown lacks
- **Cross-provider bridge**: We add cross-provider reasoning review via Stop hook
- **Checkpoints**: Session ↔ git commit linking for context recovery
- **Agent CVs**: Detailed per-agent execution timeline tracking

**The Propulsion Principle**: Our ralph-loop already implements this — agents
execute immediately on their task without waiting for confirmation. The completion
promise (e.g., `TICKET_TASK_COMPLETE`) is the termination condition.
