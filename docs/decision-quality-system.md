# Decision Quality System - Plan Enhancement Architecture

> Structured multi-perspective plan construction using the cross-provider bridge as adversarial infrastructure.

## 1. Summary

The Decision Quality System (DQS) enhances how plans are constructed by routing proposals through three parallel analysis paths — **Council** (collaborative structured debate), **Red Team** (adversarial attack), and **First Principles** (assumption decomposition) — before synthesizing a final decision. This leverages the existing cross-provider bridge infrastructure for correlation-bias mitigation.

**Key Insight**: The Migration Architecture Proposal structure (15 sections from Summary through Open Questions) maps directly onto a structured plan template that the DQS can evaluate. The cross-provider bridge already provides single-reviewer adversarial checking; DQS extends this to multi-perspective analysis.

## 2. How the Migration Architecture Proposal Structure Helps

The 15-section structure provides a **completeness checklist** that prevents plans from shipping with gaps:

| Section | DQS Role | Why It Matters |
|---------|----------|----------------|
| Summary | Council input | Forces concise framing — debatable |
| Goals / Non-Goals | Red Team target | Adversaries attack goal scoping |
| Current State | First Principles anchor | Grounded in observable reality |
| Proposed Architecture | All three paths | Primary attack surface |
| Migration Strategy | Red Team priority | Highest risk section |
| File/Data Workflow | Council debate | Multiple valid approaches |
| Tooling & Restructure | First Principles | Challenge tool assumptions |
| Branch & Delivery | Council + Red Team | Sequence and blast radius |
| Work Breakdown | First Principles | Decompose into verifiable units |
| Milestones | Council debate | Ordering and dependencies |
| Risks & Mitigations | Red Team validation | Are mitigations sufficient? |
| Architectural Decisions | All three paths | Highest-leverage review targets |
| Dependency Rationalization | First Principles | Challenge every dependency |
| Open Questions | DQS output | Fed back as synthesis |

**Verdict**: This structure provides the scaffolding DQS needs. Without it, plans are freeform and reviewers miss entire categories of risk.

## 3. Three-Path Analysis Architecture

### 3.1 Council (Collaborative-Adversarial)

**What**: 4-agent structured debate across 3 rounds. Agents take different stances on the same proposal and argue through structured turn-taking.

**Maps to**: `claude-pipeline` multi-stage chains + Agent Teams

**Implementation**:
```bash
# Council as a 3-stage pipeline with role-specific system prompts
cpipe --stages 3 \
  --system "Round 1: Each perspective argues their position" \
  --system "Round 2: Respond to counter-arguments" \
  --system "Round 3: Converge on strongest arguments" \
  "Review this architecture proposal: <plan>"
```

**Or with Agent Teams**:
```
Spawn 4 teammates with different analytical lenses:
- Architect: structural soundness, scalability
- Security: threat model, attack surfaces
- Performance: bottlenecks, resource implications
- Operations: deployment complexity, maintenance burden
```

**Current capability**: Agent Teams + `--persona-*` flags already support this. The gap is a **structured debate protocol** (rounds, turn-taking, convergence rules).

### 3.2 Red Team (Adversarial Attack)

**What**: Aggressive adversarial analysis that tries to break the proposal. Steelman the opposition, then counter-argue.

**Maps to**: Cross-provider bridge with adversarial prompt

**Implementation**:
```bash
# Red Team via cross-provider bridge with custom adversarial prompt
CROSS_PROVIDER_BRIDGE=1 \
CROSS_PROVIDER_PROMPT="You are a hostile adversarial reviewer. Your job is to BREAK this plan. Find: 1) Fatal flaws that would cause project failure 2) Hidden assumptions that are wrong 3) Missing failure modes 4) Optimistic estimates that will slip 5) Dependencies that will break. Start with CONCERNS: unless you genuinely cannot find issues." \
CROSS_PROVIDER_MAX_ITERATIONS=3 \
claude
```

**Current capability**: Cross-provider bridge already does this with a softer prompt. Enhancing the prompt to be explicitly adversarial, plus increasing `MAX_ITERATIONS`, gives true red-teaming.

### 3.3 First Principles (Assumption Decomposition)

**What**: Decompose every assumption in the proposal down to verifiable ground truth. Ask "what is actually true?" rather than "what do we believe?"

**Maps to**: Sequential MCP + `--ultrathink` flag

**Implementation**:
```bash
# First Principles via deep analysis
cpipe --preset think \
  --system "Decompose this proposal into its fundamental assumptions. For each assumption: 1) State it explicitly 2) Grade confidence (high/medium/low) 3) Identify how to verify it 4) Flag what changes if it's wrong. Do NOT accept any claim at face value." \
  "Analyze assumptions in: <plan>"
```

**Current capability**: `--ultrathink` + Sequential MCP already enables deep analysis. The gap is a **structured assumption registry** output format.

## 4. Synthesized Output

The three paths converge into a synthesis document:

```
## Decision Quality Report

### Strongest Arguments For
[From Council consensus + First Principles verified assumptions]

### Strongest Arguments Against
[From Red Team attacks that were NOT successfully countered]

### Hidden Assumptions
[From First Principles decomposition — unverified beliefs]

### Convergence Points
[Where all three paths agree — high confidence]

### Risk Assessment
[Combined from Red Team attacks + Council debate + First Principles gaps]

### Recommended Changes
[Specific modifications to the plan, ordered by impact]

### Open Questions Elevated
[Questions that none of the three paths could resolve]
```

## 5. Integration with Existing Infrastructure

### What We Already Have

| Component | DQS Role | Status |
|-----------|----------|--------|
| Cross-provider bridge | Red Team engine | Production |
| Claude Pipeline (`cpipe`) | Council multi-stage | Production |
| Agent Teams | Council parallel debate | Experimental |
| `--persona-*` flags | Specialized perspectives | Production |
| `--ultrathink` + Sequential | First Principles depth | Production |
| Workflow templates (TOML) | Plan structure templates | Production |
| `gwt-ticket` + ralph-loop | Autonomous execution | Production |

### What We Need to Build

| Component | Purpose | Effort |
|-----------|---------|--------|
| Plan template (TOML/MD) | Enforce 15-section structure | Low |
| DQS workflow template | Orchestrate 3-path analysis | Medium |
| Synthesis aggregator | Merge outputs into report | Medium |
| `cpipe --preset council` | Pre-configured Council pipeline | Low |
| Adversarial bridge prompt | Red Team-optimized prompt | Low |
| Assumption registry format | First Principles output schema | Low |

## 6. Proposed Plan Template

Based on the Migration Architecture Proposal structure, adapted for general use:

```toml
[plan]
name = "decision-quality"
description = "Structured plan with DQS evaluation"

[sections]
required = [
  "summary",           # 1-paragraph elevator pitch
  "goals",             # What success looks like
  "non_goals",         # Explicit scope boundaries
  "current_state",     # Observable ground truth
  "proposed_approach",  # The actual plan
  "migration_strategy", # How to get from current → proposed
  "risks_mitigations",  # Known risks with mitigation plans
  "decisions",          # Key architectural/design decisions with rationale
  "work_breakdown",     # Decomposed into verifiable units
  "open_questions",     # Unresolved issues
]

optional = [
  "milestones",         # Sequenced delivery plan
  "dependencies",       # External dependencies and rationalization
  "tooling",            # Tool choices and alternatives considered
  "delivery_strategy",  # Branch/release/rollback approach
  "data_workflow",      # Data flow and transformation
]

[evaluation]
council_rounds = 3
red_team_iterations = 3
first_principles_depth = "ultrathink"
synthesis_required = true
```

## 7. Usage Patterns

### Quick Plan Review (Single Provider)
```bash
# Existing: cross-provider bridge reviews Claude's plan
CROSS_PROVIDER_BRIDGE=1 CROSS_PROVIDER_MAX_ITERATIONS=3 claude
# Then: "Create a plan for X using the DQS template"
```

### Full DQS Review (Three Paths)
```bash
# Step 1: Write plan using template structure
claude -p --model opus "Create a plan for X using these sections: ..."  > /tmp/plan.md

# Step 2: Council (multi-perspective debate)
cat /tmp/plan.md | cpipe --preset review "Debate this plan from architect, security, ops, and UX perspectives"

# Step 3: Red Team (adversarial)
cat /tmp/plan.md | CROSS_PROVIDER_ORDER=gemini,codex,ollama \
  CROSS_PROVIDER_PROMPT="Break this plan. Find fatal flaws." \
  cpipe --reason opus --execute sonnet "Red team this plan"

# Step 4: First Principles
cat /tmp/plan.md | cpipe --preset think \
  "Decompose every assumption. What is actually true vs believed?"

# Step 5: Synthesize
cat /tmp/council.md /tmp/redteam.md /tmp/firstprinciples.md | \
  claude -p --model opus "Synthesize these three analyses into a Decision Quality Report"
```

### Autonomous Ticket with DQS
```bash
# gwt-ticket with bridge for adversarial review during execution
gwtt ENG-123 --bridge 3 --bridge-providers gemini,codex,ollama
```

## 8. Relationship to Cross-Provider Bridge

The bridge is the **execution engine** for the Red Team path. Current bridge capabilities:

- Iterative consensus (up to N rounds)
- Multi-provider fallback chain
- Thinking block stripping
- Consensus detection
- State persistence across iterations
- Configurable prompts

**Enhancement needed**: The bridge currently uses a general review prompt. Adding a `CROSS_PROVIDER_MODE` env var could switch between:
- `review` (default): Current balanced review
- `redteam`: Aggressive adversarial mode
- `steelman`: Strongest possible argument FOR the proposal
- `assumptions`: First Principles assumption extraction

This would be a small change to the bridge script — swap the prompt template based on mode.

## 9. Why This Matters

Without structured plan evaluation:
1. Plans ship with **unchallenged assumptions** (First Principles gap)
2. Risks are identified **after implementation starts** (Red Team gap)
3. Alternative approaches are **never considered** (Council gap)
4. The same model that wrote the plan **reviews its own work** (correlation bias)

The cross-provider bridge already solves #4. The DQS adds #1-#3 using infrastructure we mostly already have.

## 10. Implementation Priority

1. **Plan template** (TOML + example) — enforce structure before evaluation
2. **Adversarial bridge prompt** — `CROSS_PROVIDER_MODE=redteam` env var
3. **`cpipe --preset council`** — 3-round debate pipeline preset
4. **Assumption registry** — structured output for First Principles
5. **Synthesis script** — merge three analyses into Decision Quality Report
6. **`gwt-ticket --dqs`** flag — full DQS evaluation for autonomous tickets
