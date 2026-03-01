---
paths:
  - ".claude/hooks/cross-provider-bridge.sh"
  - "scripts/test-claude-pipeline.sh"
---

# Cross-Provider Reasoning Bridge

Stop hook for correlation-bias mitigation — sends reasoning to independent AI providers.

**Enable**: `CROSS_PROVIDER_BRIDGE=1 claude`
**Providers**: Codex, Gemini, Ollama, DeepSeek, Claude, OpenCode
**Key env vars**: `CROSS_PROVIDER_ORDER` (default: `codex,opencode`), `CROSS_PROVIDER_MODE` (`review|redteam|steelman|assumptions`), `CROSS_PROVIDER_MAX_ITERATIONS` (default: 3)
**Hook**: `.claude/hooks/cross-provider-bridge.sh` (command type, not prompt/agent)

## Claude Pipeline (Multi-Model Reasoning Chains)
`claude-pipeline` / `cpipe`. Default: opus→sonnet. Docs: `docs/claude-pipeline.md`.
**Presets**: `review` (opus→sonnet→haiku), `cheap` (sonnet→haiku), `local` (ollama→sonnet), `council`, `redteam`

## Decision Quality System (DQS)
Docs: `docs/decision-quality-system.md`.
**Paths**: Council (`cpipe --preset council`), Red Team (`CROSS_PROVIDER_MODE=redteam`), First Principles (`CROSS_PROVIDER_MODE=assumptions`)
