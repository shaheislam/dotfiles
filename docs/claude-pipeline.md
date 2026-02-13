# Claude Pipeline - Multi-Model Reasoning Chains

Chain Claude Code models in the terminal: pass reasoning output from one model as input to another.

## Quick Start

```bash
# Default: opus reasons → sonnet implements
claude-pipeline 'Design and implement a retry mechanism for API calls'

# Short alias
cpipe 'Add input validation to user signup form'

# Pipe existing code as context
cat src/api.ts | claude-pipeline 'refactor with better error handling'
```

## How It Works

Claude Code's `-p` (print) flag enables non-interactive output, and `--model` selects the model. Combining these with Unix pipes creates multi-model pipelines:

```
Stage 1: claude -p --model opus "Analyze and plan: <prompt>"
    ↓ (text output piped as context)
Stage 2: claude -p --model sonnet "Implement based on: <stage 1 output>"
```

Under the hood, `claude-pipeline` captures each stage's output and passes it as context to the next stage. This uses your existing Claude Code subscription (Max/Pro/Teams) - no API key needed.

## Presets

| Preset | Stages | Models | Use Case |
|--------|--------|--------|----------|
| `--preset think` | 2 | opus → sonnet | Deep reasoning then implementation (default) |
| `--preset review` | 3 | opus → sonnet → haiku | Reason → implement → review |
| `--preset cheap` | 2 | sonnet → haiku | Balanced reasoning → fast execution |
| `--preset local` | 2 | ollama → sonnet | Local reasoning → cloud implementation |
| `--preset council` | 3 | opus → sonnet → opus | Multi-perspective structured debate (DQS) |
| `--preset redteam` | 2 | opus → sonnet | Adversarial attack → synthesis (DQS) |

## Options

| Flag | Description |
|------|-------------|
| `--reason MODEL` | Model for reasoning stage (default: opus) |
| `--execute MODEL` | Model for execution stage (default: sonnet) |
| `--stages N` | Number of stages, 2-5 (default: 2) |
| `--preset NAME` | Use a preset configuration |
| `--stream` | Use stream-json format between stages |
| `--save FILE` | Save intermediate outputs to files |
| `--system PROMPT` | System prompt for all stages |
| `--verbose` | Show stage progress |
| `--dry-run` | Show pipeline command without executing |

## Examples

```bash
# Architecture planning with review
claude-pipeline --preset review 'Add WebSocket support to the chat feature'

# Cost-effective pipeline
claude-pipeline --preset cheap 'Write a bash one-liner to find large files'

# Custom model selection
claude-pipeline --reason opus --execute haiku 'Optimize this SQL query'

# Save intermediate reasoning
claude-pipeline --save /tmp/analysis --verbose 'Design a caching strategy for user sessions'
# Creates: /tmp/analysis-stage1.txt, /tmp/analysis-stage2.txt

# Dry run to see what would execute
claude-pipeline --dry-run --preset review 'Add authentication middleware'

# 3-stage with custom models
claude-pipeline --stages 3 --reason opus --execute sonnet 'Build a REST API endpoint'

# Local + cloud hybrid (requires Ollama)
claude-pipeline --preset local 'Explain the trade-offs of microservices vs monolith'
```

## Comparison with Built-in Features

| Approach | When to Use |
|----------|-------------|
| `/model opusplan` | Inside the Claude Code TUI for automatic hybrid mode |
| `claude-pipeline` | Terminal pipelines, CI/CD, batch processing, custom model chains |
| `claude -p \| claude -p` | Manual one-off pipes (claude-pipeline automates this) |
| Agent Teams | Multi-agent collaboration within a session |

## Available Models

| Alias | Model | Best For |
|-------|-------|----------|
| `opus` | Opus 4.6 | Deep reasoning, architecture, complex analysis |
| `sonnet` | Sonnet 4.5 | Balanced coding, implementation |
| `haiku` | Haiku 4.5 | Fast responses, simple tasks, review |
| `ollama` | Local model | Offline reasoning, privacy-sensitive tasks |

## Raw Pipe Syntax

For manual control, you can pipe `claude -p` invocations directly:

```bash
# Simple text piping
claude -p --model opus "Plan: add retry logic to API calls" | \
  claude -p --model sonnet "Implement the plan above"

# Structured stream-json piping
claude -p --model opus --output-format stream-json "Analyze architecture" | \
  claude -p --model sonnet --input-format stream-json "Implement recommendations"

# 3-stage manual pipeline
claude -p --model opus "Analyze security vulnerabilities" | \
  claude -p --model sonnet "Fix the identified vulnerabilities" | \
  claude -p --model haiku "Review the fixes for completeness"
```

## Cross-Provider Bridge (Stop Hook)

Automatically sends Claude's reasoning to an independent AI provider (Codex or OpenCode) for cross-provider validation. Mitigates correlation issues between same-provider models.

### How It Works

```
Claude reasons (Opus) → Stop hook fires → Sends to Codex/OpenCode → Feeds review back
    ↓                                                                      ↓
stop_hook_active=false                                          stop_hook_active=true
(bridge runs)                                                   (bridge skips → no loop)
```

The hook is disabled by default. Enable it with `CROSS_PROVIDER_BRIDGE=1`.

### Graceful Fallback

The bridge tries providers in order and silently falls through if none are available:

1. **Codex** (`codex exec -`): Requires `codex` CLI + `CODEX_API_KEY` or `OPENAI_API_KEY`
2. **OpenCode** (`opencode run -q`): Requires `opencode` CLI + configured auth
3. **Silent continue**: If nothing works, Claude continues normally - zero failures

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CROSS_PROVIDER_BRIDGE` | *(unset)* | Set to `1` to enable |
| `CROSS_PROVIDER_ORDER` | `codex,opencode` | Comma-separated provider priority |
| `CROSS_PROVIDER_CODEX_MODEL` | *(codex default)* | Override Codex model |
| `CROSS_PROVIDER_OPENCODE_MODEL` | `ollama/qwen3-coder` | OpenCode model (provider/model format) |
| `CROSS_PROVIDER_MAX_CHARS` | `4000` | Max context chars sent for review |
| `CROSS_PROVIDER_PROMPT` | *(built-in)* | Custom review prompt |

### Integration with gwt-ticket

The bridge works transparently with autonomous ticket execution:

```bash
# Enable bridge globally (all Claude sessions get cross-provider review)
export CROSS_PROVIDER_BRIDGE=1

# Run ticket - bridge fires during every ralph-loop iteration
gwt-ticket ENG-123 "Fix auth bug" "Session tokens expire"

# Or enable per-session via prompt prefix
gwt-ticket ENG-123 "Fix" "Desc" --prompt-prefix "IMPORTANT: Cross-provider review is active"
```

No changes needed to gwt-ticket, ralph-loop, or gwt-queue - the Stop hook fires automatically.

### Usage Examples

```bash
# Enable for current shell session
export CROSS_PROVIDER_BRIDGE=1
export OPENAI_API_KEY=sk-...  # for Codex

# Prefer OpenCode over Codex
export CROSS_PROVIDER_ORDER=opencode,codex
export CROSS_PROVIDER_OPENCODE_MODEL=openai/o3

# Disable temporarily
unset CROSS_PROVIDER_BRIDGE
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_CODE_MODEL` | `qwen3-coder` | Ollama model used when `--preset local` |
| `CROSS_PROVIDER_BRIDGE` | *(unset)* | Set to `1` to enable cross-provider bridge |
| `CROSS_PROVIDER_ORDER` | `codex,opencode` | Provider priority for bridge |
| `CROSS_PROVIDER_OPENCODE_MODEL` | `ollama/qwen3-coder` | Model for OpenCode bridge |

## Testing

```bash
# Config tests (no API calls) - includes hook tests
./scripts/test-claude-pipeline.sh

# Live tests (uses Claude subscription)
./scripts/test-claude-pipeline.sh --live
```
