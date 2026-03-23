# Workspace Standards

> Place this file at your workspace root (e.g., ~/work/CLAUDE.md).
> All projects within this directory inherit these rules automatically.
> Project-specific CLAUDE.md files override these where they conflict.
> Remove this blockquote and customize the sections below for your org.

## Org Context

- **Team**: <!-- e.g., Platform Engineering -->
- **Infra**: <!-- e.g., AWS us-east-1, EKS, Terraform -->
- **CI/CD**: <!-- e.g., GitHub Actions, ArgoCD -->
- **Registry**: <!-- e.g., ECR 123456789.dkr.ecr.us-east-1.amazonaws.com -->

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `make test` | Run project tests |
| `make lint` | Run linter |
| `make build` | Build project |
<!-- Add org-specific CLIs below -->
<!-- | `kubectl --context staging get pods` | Check staging pods | -->
<!-- | `vault kv get secret/app` | Fetch secrets | -->
<!-- | `terraform plan` | Preview infra changes | -->

## Coding Standards

- Use conventional commits: `type(scope): description`
- Always run tests before committing
- Keep functions focused and small
- Prefer standard library solutions over external dependencies
<!-- Add org standards below -->
<!-- - All public APIs must have OpenAPI specs -->
<!-- - Database migrations require rollback scripts -->

## Git Workflow

- Create feature branches from main/master
- Write descriptive commit messages explaining why, not just what
- Squash fixup commits before merging
<!-- - PRs require 2 approvals before merge -->
<!-- - Never push directly to main -->

## Code Review

- Check for security issues (injection, XSS, hardcoded secrets)
- Verify error handling is appropriate
- Ensure tests cover the change
<!-- - All PRs must pass CI before review -->
<!-- - Tag @security-team for auth/crypto changes -->

## Secrets & Auth

<!-- Uncomment and customize -->
<!-- - Never hardcode credentials, use env vars or vault -->
<!-- - AWS: use SSO profiles, never long-lived keys -->
<!-- - Secrets manager: HashiCorp Vault at vault.internal -->

## Deployment

<!-- Uncomment and customize -->
<!-- - Staging: auto-deploy from main -->
<!-- - Production: tag-based release via ArgoCD -->
<!-- - Rollback: `kubectl rollout undo deployment/SERVICE` -->
