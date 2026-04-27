---
name: petlab-aws
description: Petlab AWS SSO login. Authenticates against the petlab.awsapps.com SSO portal and verifies credentials for prod, management, logging, security, labs, or petlab profiles.
argument-hint: profile-name (prod|management|logging|sec|security|labs|petlab|all)
---

# Petlab AWS SSO Login

All Petlab profiles share a single SSO session (`sso-main`) at `https://petlab.awsapps.com/start`, so `aws sso login --profile <any>` refreshes the shared token for every profile.

## Profiles

| Profile | Account ID | Role | Notes |
|---------|------------|------|-------|
| `prod` | 325875666703 | AWSAdministratorAccess | Production |
| `management` | 503036359418 | AWSAdministratorAccess | Org root / billing |
| `logging` | 077624256399 | AWSAdministratorAccess | Centralised logging |
| `security` (`sec`) | 538335833983 | AWSAdministratorAccess | SecurityAudit / GuardDuty |
| `labs` | 154805902702 | AWSAdministratorAccess | Default work profile |
| `petlab` | 154805902702 | AWSAdministratorAccess | Alias of `labs` |

Default region: `us-east-1`. SSO session: `sso-main`.

## Action

Argument: `$ARGUMENTS` (default to `labs` if empty; map `sec` -> `security`).

1. **Login** with the matching profile:
   ```bash
   aws sso login --profile <profile>
   ```
   Opens the browser. If `$ARGUMENTS` is `all`, run login once for `labs` — a single SSO token covers every profile under `sso-main`.

2. **Verify** with STS — never read `~/.aws/credentials` or `~/.aws/config` directly:
   ```bash
   aws sts get-caller-identity --profile <profile>
   ```
   Confirm the returned `Account` matches the table above.

3. **Set default profile** for the current Fish shell:
   ```fish
   set -gx AWS_PROFILE <profile>
   set -gx AWS_REGION us-east-1
   ```
   Bash/Zsh: `export AWS_PROFILE=<profile>`.

4. **Report** which profile is now active and the account ID.

## Notes

- Browser-based SSO must complete in the user's terminal, not inside Claude Code. If `aws sso login` is blocked (sandbox/headless), tell the user to run it themselves with `! aws sso login --profile <profile>` so the prompt stays attached to their TTY.
- Token TTL is set by the IdP (typically 8-12 hours). On `ExpiredToken` errors, re-run step 1.
- Alternative tooling available on this machine: `assume <profile>` (Granted) and the `aws-sso <profile>` Fish wrapper — use these if plain `aws sso login` misbehaves or the user prefers Granted's keychain caching.
- Logout / clear cached SSO token: `aws sso logout`.
- List configured profiles: `aws configure list-profiles`.
- Never echo access keys, session tokens, or credential values.
