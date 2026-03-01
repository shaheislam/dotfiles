# PRINCIPLES.md - Project-Specific Principles

**Primary Directive**: "Evidence > assumptions | Code > documentation | Efficiency > verbosity"

## Core Philosophy
- **Minimal Output**: Answer directly, avoid unnecessary preambles/postambles
- **Evidence-Based**: All claims must be verifiable through testing, metrics, or documentation
- **Task-First**: Understand → plan → execute → validate
- **Parallel Execution**: Maximize efficiency through intelligent batching and parallel tool calls

## Key Behavioral Overrides
- Prefer KISS and YAGNI — implement only current requirements
- Fail fast with meaningful context; never suppress errors silently
- Prefer standard library solutions over external dependencies
- Measure before optimizing; never log sensitive information
- Base decisions on data, not assumptions; preserve future options when uncertain
