# AST Patterns for AI Gateway

Structural code patterns using ast-grep (sgconfig.yml format).
These patterns define code smells and anti-patterns that AI agents
can detect and fix automatically.

## Pattern Types

### Rule-based (YAML)
Define patterns in `sgconfig.yml` that ast-grep matches structurally.
Unlike regex, these understand code structure (AST) so they don't
match inside strings, comments, or unrelated syntax.

### Agent-guidance metadata
Each rule includes `note` fields with guidance for AI agents on HOW
to fix the issue, not just WHAT the issue is.

## Usage

```bash
# Install ast-grep
brew install ast-grep

# Run all rules
ast-grep scan --config sgconfig.yml

# Run on specific files
ast-grep scan --config sgconfig.yml path/to/file.py
```

## Integration with AI Gateway

The `analyze.sh` script can invoke ast-grep when available:
```bash
scripts/aigateway/analyze.sh --tool ast-grep path/to/file.py
```
