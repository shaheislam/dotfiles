# Shell Code Style Conventions

## Fish Shell (Primary)

- Functions go in `.config/fish/functions/` — one function per file
- Function filename must match function name (e.g., `gwt-dev.fish` contains `function gwt-dev`)
- Use `argparse` for flag parsing in functions with options
- Prefer `set -l` for local variables, `set -gx` for exports
- Use `test` over `[` for conditionals
- String operations: prefer Fish builtins (`string match`, `string replace`) over external tools
- Exit codes: `return 0` for success, `return 1` for failure
- Error output: `echo "Error: message" >&2`

## Bash Scripts

- Scripts go in `scripts/` directory
- Always include `#!/usr/bin/env bash` shebang
- Always `set -euo pipefail` at the top
- Use `local` for function-scoped variables
- Quote all variable expansions: `"$var"` not `$var`
- Functions: lowercase with underscores (e.g., `install_package`)

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Fish function | kebab-case | `gwt-dev`, `otel-start` |
| Fish alias | short lowercase | `gwtd`, `ptctl` |
| Bash function | snake_case | `install_package` |
| Script file | kebab-case | `setup-mobile-coding.sh` |
| Config dir | lowercase | `.config/ghostty/` |

## Zsh Compatibility

- All PATH additions must be in both Fish config and `.zshrc`
- Aliases that work in both shells should be documented in both configs
