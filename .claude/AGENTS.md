# AGENTS.md - Claude Code Agent System Reference

Specialized agent system for Claude Code with 15 subagent files (12 domain specialists + 3 project-specific).

## Overview

Each agent is a **Claude Code subagent file** (`.claude/agents/*.md`) with YAML frontmatter defining name, description, tool access, model, and optional features. Claude auto-delegates to subagents based on their description fields. Each subagent runs in its own context window with a custom system prompt.

**Core Features**:
- **Subagent Files**: Markdown files with YAML frontmatter in `.claude/agents/`
- **Auto-Delegation**: Claude uses description fields to decide when to delegate
- **Tool Restrictions**: Each agent has specific tool access (read-only vs full)
- **Model Selection**: `haiku` for fast read-only agents, `inherit` for full capability
- **Persistent Memory**: `memory: project` on architect for cross-session learning
- **Background Mode**: `background: true` on test-runner for concurrent execution
- **Cost Control**: `maxTurns` on bounded agents (test-runner, dotfiles-doctor, mentor)
- **Skill Preloading**: `skills` field injects skill content at startup (shell-expert)
- **MCP Access**: `mcpServers` gives agents access to specific MCP servers (architect, mentor)
- **Lifecycle Hooks**: SubagentStart/SubagentStop events in settings.json for logging
- **Manual Override**: Use `--persona-[name]` flags for explicit control
- **Flag Integration**: Works with all thinking flags, MCP servers, and command categories

**Frontmatter Fields** (from [official docs](https://code.claude.com/docs/en/sub-agents)):

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier (must match filename) |
| `description` | Yes | When to delegate (Claude reads this) |
| `tools` | No | Comma-separated allowed tools |
| `disallowedTools` | No | Comma-separated blocked tools |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit` (default) |
| `memory` | No | `user`, `project`, or `local` persistence scope |
| `background` | No | `true` for concurrent execution |
| `maxTurns` | No | Limit API round-trips (cost control) |
| `skills` | No | Comma-separated skills to preload |
| `mcpServers` | No | Comma-separated MCP servers to enable |
| `hooks` | No | Agent-scoped hooks (PreToolUse, PostToolUse, Stop) |
| `isolation` | No | `worktree` for isolated git worktree |
| `permissionMode` | No | Permission level override |

## Available Agents

### Technical Specialists

| Agent | Flag | Description | Primary Use Cases |
|-------|------|-------------|-------------------|
| [architect](agents/architect.md) | `--persona-architect` | Systems architecture specialist | System design, scalability, long-term planning |
| [frontend](agents/frontend.md) | `--persona-frontend` | UX specialist & accessibility advocate | UI components, responsive design, user experience |
| [backend](agents/backend.md) | `--persona-backend` | Reliability engineer & API specialist | Server development, APIs, data integrity |
| [security](agents/security.md) | `--persona-security` | Threat modeler & vulnerability specialist | Security audits, threat analysis, hardening |
| [performance](agents/performance.md) | `--persona-performance` | Optimization & bottleneck specialist | Performance tuning, metrics, optimization |

### Process & Quality Experts

| Agent | Flag | Description | Primary Use Cases |
|-------|------|-------------|-------------------|
| [analyzer](agents/analyzer.md) | `--persona-analyzer` | Root cause & investigation specialist | Debugging, troubleshooting, analysis |
| [qa](agents/qa.md) | `--persona-qa` | Quality advocate & testing specialist | Testing, validation, quality assurance |
| [refactorer](agents/refactorer.md) | `--persona-refactorer` | Code quality & technical debt manager | Code cleanup, refactoring, simplification |
| [devops](agents/devops.md) | `--persona-devops` | Infrastructure & automation specialist | CI/CD, deployment, infrastructure |
| [devops-security-auditor](agents/devops-security-auditor.md) | Special | DevOps security assessment specialist | Infrastructure security, container security |

### Knowledge & Communication

| Agent | Flag | Description | Primary Use Cases |
|-------|------|-------------|-------------------|
| [mentor](agents/mentor.md) | `--persona-mentor` | Educational & knowledge transfer specialist | Teaching, documentation, explanations |
| [scribe](agents/scribe.md) | `--persona-scribe=lang` | Documentation & localization specialist | Professional writing, documentation, translation |

### Project-Specific Agents

| Agent | Model | Extra Features | Primary Use Cases |
|-------|-------|----------------|-------------------|
| [shell-expert](agents/shell-expert.md) | inherit | `skills: fish-reload, dotfiles-sync` | Shell functions, scripts, Fish/Zsh parity |
| [test-runner](agents/test-runner.md) | haiku | `background: true`, `maxTurns: 10` | Running test suites, reporting results |
| [dotfiles-doctor](agents/dotfiles-doctor.md) | haiku | `maxTurns: 15` | Stow validation, tool checks, theme consistency |

## Agent Activation

### Manual Activation
Use flags to explicitly activate agents:
```bash
--persona-architect           # Activate architect agent
--persona-frontend --persona-qa  # Activate multiple agents
--persona-scribe=es          # Activate scribe with Spanish language
```

### Auto-Activation
Agents activate automatically based on:
- **Keywords**: Domain-specific terms trigger relevant agents
- **Context**: Project type and current task determine agent selection
- **Commands**: Specific commands have preferred agents
- **Complexity**: High complexity triggers analytical agents

### Command Integration
Commands work seamlessly with agents:
```bash
/build --persona-frontend     # Frontend-focused build
/analyze                       # Auto-activates analyzer, architect, security
/improve --persona-refactorer # Refactoring-focused improvements
/test --persona-qa            # QA-focused testing
```

## Cross-Agent Collaboration

Agents can work together for complex tasks:

### Common Collaboration Patterns
- **architect + performance**: System design with performance optimization
- **security + backend**: Secure server-side development
- **frontend + qa**: User-focused development with testing
- **mentor + scribe**: Educational content creation
- **analyzer + refactorer**: Root cause analysis with code improvement
- **devops + security**: Infrastructure automation with security

### Conflict Resolution
When multiple agents are active:
1. **Primary Agent**: Leads decision-making within domain
2. **Consulting Agents**: Provide specialized input
3. **Validation Agents**: Review decisions for quality
4. **Priority Matrix**: Resolves conflicts using agent hierarchies

## Flag Integration

All agents work with the complete flag system:

### Thinking Flags
- `--think`: Enhanced analysis (4K tokens)
- `--think-hard`: Deep analysis (10K tokens)
- `--ultrathink`: Maximum analysis (32K tokens)

### MCP Server Flags
- `--seq`: Sequential reasoning
- `--c7`: Context7 documentation
- `--magic`: UI component generation
- `--play`: Playwright testing

### Optimization Flags
- `--uc`: Ultra-compressed output
- `--validate`: Pre-operation validation
- `--safe-mode`: Conservative execution
- `--loop`: Iterative improvement

### Orchestration Flags
- `--wave-mode`: Multi-stage execution
- `--delegate`: Sub-agent delegation
- `--concurrency`: Parallel processing

## Agent Selection Guide

### By Task Type
- **Building**: frontend, backend, architect
- **Debugging**: analyzer, qa, performance
- **Security**: security, devops-security-auditor
- **Documentation**: scribe, mentor
- **Optimization**: performance, refactorer
- **Infrastructure**: devops, architect

### By Project Phase
- **Planning**: architect, analyzer
- **Implementation**: frontend, backend
- **Testing**: qa, performance
- **Deployment**: devops, security
- **Maintenance**: refactorer, analyzer

### By Complexity
- **Simple tasks**: Single specialized agent
- **Moderate tasks**: Primary + consulting agent
- **Complex tasks**: Multiple collaborative agents
- **Critical tasks**: Full agent team with validation

## Configuration

Agents respect all system configurations:
- Token limits and compression settings
- MCP server availability
- Resource management thresholds
- Quality gate requirements
- Validation cycles

## Best Practices

1. **Let auto-activation work**: The system usually selects the right agents
2. **Use explicit flags for precision**: Override when you need specific expertise
3. **Combine agents for complex tasks**: Multiple perspectives improve outcomes
4. **Trust agent expertise**: Each agent excels in their domain
5. **Monitor agent recommendations**: Agents provide domain-specific insights

## Quick Reference

```bash
# Single agent activation
--persona-frontend

# Multiple agents
--persona-architect --persona-security

# Agent with language
--persona-scribe=fr

# Agent with other flags
--persona-performance --think-hard --uc

# Command with agent
/build --persona-backend --validate
```

For detailed information about each agent, click on the agent name in the tables above to view their full specification.

## Agent Teams Integration

The persona-based agent system complements Claude Code's native **Agent Teams** feature (experimental). Agent Teams spawn separate Claude Code instances that communicate via peer-to-peer messaging, while personas operate within a single session.

### When to Use Each
| Scenario | Best Approach |
|----------|--------------|
| Single-session domain expertise | Personas (`--persona-*` flags) |
| Parallel same-repo collaboration | Agent Teams (teammates with shared task list) |
| Isolated multi-branch work | `gwt-parallel` (devcontainer + worktree per branch) |
| Autonomous ticket execution | `gwt-ticket` + ralph-loop |

### Combining Personas with Agent Teams
Teammates spawned via Agent Teams load CLAUDE.md, so persona auto-activation works within each teammate's session. When creating teams, leverage this by assigning domain-specific context:
```
Spawn a teammate focused on security review (will auto-activate security persona)
Spawn a teammate for frontend components (will auto-activate frontend persona)
```