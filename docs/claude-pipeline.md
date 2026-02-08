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

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_CODE_MODEL` | `qwen3-coder` | Ollama model used when `--preset local` |

## Testing

```bash
# Config tests (no API calls)
./scripts/test-claude-pipeline.sh

# Live tests (uses Claude subscription)
./scripts/test-claude-pipeline.sh --live
```
