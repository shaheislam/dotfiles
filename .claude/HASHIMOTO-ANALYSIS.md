# Hashimoto AI Practices vs Our Dotfiles: Gap Analysis

> Based on Mitchell Hashimoto's article: [My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey)

## Executive Summary

Our dotfiles setup is **significantly more sophisticated** than what Hashimoto describes in terms of infrastructure, automation, and tooling. However, Hashimoto's article reveals several **philosophical and practical gaps** in our approach that, once addressed, would make our setup strictly superior.

**Verdict**: Feature parity on most points, **superior** on tooling/automation, but with meaningful gaps in practical agent guidance (AGENTS.md philosophy) and workflow discipline patterns.

---

## Detailed Comparison

### 1. AGENTS.md Philosophy

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Purpose** | Empirical corrections - each line prevents a specific bad behavior | Abstract persona framework with 12 agents | **GAP** |
| **Format** | 4-5 lines of practical, project-specific rules | 175 lines of theoretical architecture | **GAP** |
| **Example** | Ghostty's: "See full C API by finding dcimgui.h in .zig-cache" | "Systems architecture specialist with decision frameworks" | **GAP** |
| **Evolution** | Updated when agents make mistakes | Static specification | **GAP** |

**Analysis**: This is our **biggest gap**. Hashimoto's AGENTS.md is a living document that grows from observed failures. Each line is a specific correction: "Don't do X, instead do Y" or "Find Z at this location." Our AGENTS.md is a theoretical persona system that Claude Code largely ignores in practice.

**The Ghostty AGENTS.md is 4 lines:**
```
- See the full C API by finding dcimgui.h in .zig-cache
- See full examples of how to use every widget by loading this file: [URL]
- On macOS, run builds with -Demit-macos-app=false to verify API usage
- There are no unit tests in this package
```

Each line prevents a concrete mistake agents repeatedly make.

**Action Required**: Create a new practical AGENTS.md for the dotfiles project based on actual observed bad behaviors. Keep the persona framework if desired but separate it.

---

### 2. Harness Engineering (Programmed Tools)

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Concept** | Create tools that help agents succeed on first attempt | Hooks that enforce rules (bun, bash safety) | **PARTIAL** |
| **Screenshots** | Scripts to take screenshots for visual verification | No screenshot tooling for agents | **GAP** |
| **Filtered tests** | Run filtered test subsets for faster feedback | Full test suites only | **GAP** |
| **Tool advertising** | AGENTS.md tells agents about available tools | Not documented for agents | **GAP** |
| **Hook enforcement** | Not mentioned | use_bun.py, validate-bash.py, ts_lint.py | **SUPERIOR** |

**Analysis**: We have excellent **enforcement** harnesses (hooks that block bad commands), which Hashimoto doesn't mention. But we lack **assistance** harnesses (tools that help agents find the right answer). The key insight is that AGENTS.md should advertise available tools so agents know to use them.

**Action Required**: Document existing tools/scripts in AGENTS.md so agents know to use them. Create filtered test helpers.

---

### 3. Background Agent Workflows

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Single background agent** | Runs 1 agent during manual work | ralph-loop, gwt-parallel for multiple | **SUPERIOR** |
| **End-of-day kickoff** | Last 30 min for agent setup | No structured routine | **GAP** |
| **Notification control** | Disables notifications deliberately | macOS notifications active | **GAP** |
| **Check on breaks** | Reviews during natural work breaks | Hook-driven tmux window indicators | **SUPERIOR** |
| **Daily utilization** | 10-20% of workday | Not measured | **GAP** |

**Analysis**: Our hook-driven tmux indicator system is **superior** to Hashimoto's manual checking approach. However, we lack the disciplined daily routines he describes. The end-of-day kickoff pattern is a valuable workflow practice we should document.

---

### 4. Task Categorization

| Category | Hashimoto | Our Setup | Verdict |
|----------|-----------|-----------|---------|
| **Deep research** | Agent surveys fields, produces summaries | No dedicated research workflow | **GAP** |
| **Parallel exploration** | Illuminating unknown unknowns | gwt-parallel for multiple branches | **PARITY** |
| **Issue/PR triage** | gh-based reports (no agent responses) | /jira, ticket-execute (full execution) | **SUPERIOR** |
| **Slam dunks** | High-confidence, well-defined tasks | ralph-loop, gwt-ticket for autonomous execution | **SUPERIOR** |
| **Planning vs execution** | Split vague requests into two phases | /feature-dev has 7-phase workflow | **SUPERIOR** |

**Analysis**: Our automation for ticket execution and autonomous development is far ahead. The gap is in **research workflows** - we don't have a structured way to ask agents to survey libraries, create comparison reports, etc.

---

### 5. Agent-First Mindset

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Use agents, not chatbots** | Core philosophy | Claude Code is primary tool | **PARITY** |
| **Agents read/execute/request** | Essential capabilities | Full tool access via Claude Code | **PARITY** |
| **Learn agent strengths** | Experimentation phase | Extensive plugin ecosystem | **SUPERIOR** |
| **Negative space** | Know when NOT to use agents | Not explicitly documented | **GAP** |
| **Skill maintenance** | Continue manual work deliberately | Not addressed | **GAP** |

---

### 6. Context Management

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Separate clear tasks** | Break work into actionable chunks | gwt-ticket with focused prompts | **PARITY** |
| **Verification mechanisms** | Give agents ways to self-correct | Hooks for validation, test runners | **SUPERIOR** |
| **Context7 docs** | Not mentioned | MCP server integration | **SUPERIOR** |
| **Session management** | Not detailed | JFDI system, audit logging | **SUPERIOR** |

---

### 7. Model Selection

| Aspect | Hashimoto | Our Setup | Verdict |
|--------|-----------|-----------|---------|
| **Slow models for quality** | Amp deep mode (GPT-5.2-Codex) for background | Opus 4.6 as default | **DIFFERENT** |
| **Model per task type** | Match model to task | Single model configuration | **GAP** |
| **Multi-provider** | Claude Code + Amp | Claude Code only | **GAP** |

---

## Summary Scorecard

| Category | Hashimoto | Our Setup | Winner |
|----------|-----------|-----------|--------|
| AGENTS.md (practical guidance) | Empirical, concise | Theoretical, verbose | **Hashimoto** |
| Harness engineering | Tools + advertising | Hooks + enforcement | **Tie** |
| Background workflows | Disciplined routine | Advanced tooling | **Our setup** |
| Task categorization | Manual 4-category | Automated execution | **Our setup** |
| Parallel development | Single agent | Worktrees + devcontainers | **Our setup** |
| Ticket automation | gh triage reports | Full autonomous execution | **Our setup** |
| Activity monitoring | Manual breaks | Hook-driven tmux status | **Our setup** |
| Research workflows | Structured approach | No dedicated workflow | **Hashimoto** |
| Model diversity | Multi-provider | Single provider | **Hashimoto** |
| Negative space docs | Acknowledged | Not documented | **Hashimoto** |
| Hook enforcement | Not mentioned | Python hooks system | **Our setup** |
| Plugin ecosystem | Not mentioned | 14 plugins | **Our setup** |

**Final Score**: Our setup is **superior in automation and tooling** (8 categories), while Hashimoto leads in **philosophical practices** (4 categories). The gaps are addressable.

---

## Recommended Changes

### Priority 1: Create Practical AGENTS.md (High Impact, Low Effort)
Create a Hashimoto-style file documenting concrete bad behaviors. Keep in root `AGENTS.md` alongside the framework.

### Priority 2: Advertise Tools in AGENTS.md (High Impact, Low Effort)
Document available scripts and hooks so agents know to use them.

### Priority 3: Add Research Workflow (Medium Impact, Medium Effort)
Create a `/research` command or template for deep research sessions.

### Priority 4: Document "Negative Space" (Medium Impact, Low Effort)
Add a section documenting when NOT to use agents for dotfiles tasks.

### Priority 5: End-of-Day Kickoff Pattern (Low Impact, Low Effort)
Document the workflow pattern, optionally create a Fish function.
