# Workspace: ~/work

> Shared context for all projects under ~/work. Project-level CLAUDE.md files override these defaults.

## AWS & Cloud Credentials

## Shell Guidance

- Fish is the default interactive shell on this machine.
- For interactive Fish commands, use `set -e VAR` instead of `unset VAR`.
- `env -u VAR command` is valid for one-off command execution from Fish.
- If an example is Bash/Zsh-only, label it explicitly instead of presenting it as generic shell syntax.

### Pre-Session Setup

Before starting work that involves AWS, authenticate in your terminal first:

```bash
# Option 1: AWS SSO (primary method)
aws sso login --profile labs
aws sts get-caller-identity  # verify

# Option 2: Granted (multi-account)
assume labs

# Option 3: Fish wrapper
aws-sso labs
```

Claude Code inherits cached AWS credentials from the shell environment. Interactive login flows (browser-based SSO) must happen outside Claude Code.

### Credential Verification

When AWS operations fail with credential errors, suggest the user run:
```bash
aws sts get-caller-identity --profile labs
```
If that fails, the SSO session has expired and needs re-authentication in the terminal.

### Default AWS Profile

The default AWS profile for work projects is `labs`. If `AWS_PROFILE` is not set, suggest setting it:
```bash
export AWS_PROFILE=labs
```

### Credential Safety Rules

- NEVER read `~/.aws/credentials` or `~/.aws/config` directly
- NEVER store AWS keys, tokens, or secrets in code, commits, or CLAUDE.md files
- NEVER echo or log credential values
- Use `aws sts get-caller-identity` to verify access, not credential file inspection
- Use `aws configure export-credentials --format env` for credential export (not file reads)

## Common Development Patterns

### Infrastructure Commands (require valid AWS session)
- `terraform plan` / `terraform apply`
- `aws s3 ls`, `aws cloudformation describe-stacks`
- `aws lambda list-functions`, `aws ecs describe-services`

### Credential Helper Tools Available
- `granted` / `assume` - AWS role assumption with Keychain backend
- `aws-vault` - if installed, wraps commands with temporary credentials
- `op` (1Password CLI) - inject secrets into commands at runtime
