# OpenTelemetry Observability

## Overview

Claude Code has native OpenTelemetry support capturing:
- **Metrics**: tool durations, API costs, token usage, cache hit rates (8 metric types)
- **Events**: tool_result, api_request, api_response, session_start, session_end (5 event types)
- **Traces**: session-correlated spans via prompt.id

The OTEL LGTM stack (`grafana/otel-lgtm`) receives this telemetry via OTLP HTTP on port 4318.

## Architecture

```
Claude Code (OTEL SDK) --OTLP HTTP--> localhost:4318
                                          |
                                    otel-lgtm container
                                    ├── OTEL Collector (receives + routes)
                                    ├── Prometheus (metrics)
                                    ├── Tempo (traces)
                                    ├── Loki (logs/events)
                                    ├── Pyroscope (profiles)
                                    └── Grafana :3000 (visualization)
```

## Environment Variables

Set in `.claude/settings.json` `env` block and Fish/Zsh configs:

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | Enable OTEL telemetry |
| `OTEL_METRICS_EXPORTER` | `otlp` | Send metrics via OTLP |
| `OTEL_LOGS_EXPORTER` | `otlp` | Send logs/events via OTLP |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | OTLP HTTP receiver |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | Protocol format |
| `OTEL_LOG_TOOL_DETAILS` | `1` | Include tool names in events |

## Fish Wrapper

```fish
otel start    # Start OTEL LGTM stack
otel stop     # Stop stack
otel status   # Show status
otel open     # Open Grafana
otel doctor   # Verify everything
```

## Graceful Degradation

If the container isn't running, Claude Code silently drops telemetry. Zero impact on operation.

## Files

| File | Purpose |
|------|---------|
| `scripts/otel/docker-compose.yml` | Single `grafana/otel-lgtm` service |
| `scripts/otel/setup-otel.sh` | Lifecycle management script |
| `scripts/otel/grafana/dashboards/claude-code.json` | Pre-built Grafana dashboard |
| `.config/fish/functions/otel.fish` | Fish wrapper function |

## Relationship to JSONL Hooks

OTEL and JSONL hooks are **complementary**, not competing:
- **OTEL** captures SDK-level data: API costs, token counts, tool durations, cache rates
- **JSONL hooks** capture hook-level context: file paths, commands, error messages, notifications

Both feed into the harness engineering feedback loop.
