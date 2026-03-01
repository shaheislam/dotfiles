---
paths:
  - "scripts/agent-*"
  - "scripts/worktree-*"
  - "scripts/merge-queue*"
  - "scripts/convoy*"
  - "scripts/molecule*"
  - "scripts/town-beads*"
  - "scripts/gwt-*"
  - ".config/fish/functions/gwt-*"
  - "templates/workflows/**"
---

# Agent Orchestration (Gastown Patterns)

Multi-agent lifecycle management. Scripts in `scripts/`, each supports `--help`.

## Core Scripts
- `agent-state.sh`: derive state from ground truth (ZFC pattern)
- `worktree-witness.sh`: lifecycle monitor (auto-spawned by gwt-ticket)
- `merge-queue.sh`: serialized merges
- `agent-triage.sh`: intelligent restart (START/WAKE/NUDGE/NOTHING)
- `phase-gates.sh`: pause on external conditions

## Agent States
`running` | `idle` | `stuck` | `completed` | `dead` | `none`

## Workflow Templates (`templates/workflows/*.toml`)
`implement`, `bugfix`, `refactor`, `test` — used via `gwt-ticket --template`

## Higher-Level Orchestration
- **Convoys** (`convoy.sh`): Batch work tracking. JSONL at `~/.claude/convoys.jsonl`
- **Molecules** (`molecule.sh`): Durable multi-step workflows with checkpoints
- **Town Beads** (`town-beads.sh`): Cross-project memory sync (on by default)
- **Mayor** (`gwt-mayor.sh`): Global coordinator daemon
- **Dashboard** (`agent-dashboard.sh`): Web dashboard at `http://127.0.0.1:8787`

## gwt-ticket Flags
`--convoy NAME|ID`, `--plan NAME [specs]`, `--molecule [id]`, `--town` (default), `--no-town`, `--mayor`, `--no-mayor`
