# Claude Code Configuration

@PRINCIPLES.md
@RULES.md

## Shell Guidance

- Fish is the default shell on this machine and in this repo context.
- For interactive Fish commands, use `set -e VAR` instead of `unset VAR`.
- `env -u VAR command` is valid for one-off command execution from Fish.
- If a snippet is Bash/Zsh-only, label it explicitly instead of presenting it as generic shell syntax.
