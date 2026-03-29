# Codex Account Rotation Setup

## Overview

Round-robin rotation across multiple Codex CLI accounts with automatic failover on usage limits. When one account hits its limit, the next account in rotation is tried.

## Prerequisites

- Codex CLI installed (`brew install codex` or `npm install -g @openai/codex`)
- Fish shell with `codex-accounts` and `codex-rotate` functions loaded
- Multiple OpenAI accounts (each needs its own browser profile or incognito session for OAuth)

## Quick Setup (5 Accounts)

### Step 1: Enroll accounts

For each account, run `codex-accounts add <name>`. This opens a browser OAuth flow - sign in with the corresponding OpenAI account.

```fish
# Account 1 is already enrolled if you bootstrapped from existing auth
codex-accounts add acct1

# Enroll remaining accounts (each opens browser OAuth)
codex-accounts add acct2
codex-accounts add acct3
codex-accounts add acct4
codex-accounts add acct5
```

**Important:** Between each `add`, the previous codex session is logged out. Each `add` triggers `codex logout` then `codex login` to capture fresh credentials.

**Tip:** Use different browser profiles or incognito windows to sign in with different OpenAI accounts.

**Workspace auth note:** Codex auth tokens can stay on `org: Personal` even when the browser UI is using a paid workspace. Rotation now supports pinning a ChatGPT workspace UUID directly, which is more reliable than relying on the browser's default org.

```fish
codex-accounts workspace discover
codex-accounts workspace set acct1 <workspace-id>
codex-accounts capture acct1
```

`codex-rotate` preserves and tries a distinct live `~/.codex/auth.json` session before falling back to enrolled accounts, and it passes `-c forced_chatgpt_workspace_id="..."` whenever a workspace pin is configured.

### Step 2: Verify enrollment

```fish
codex-accounts list
# Output:
#   Codex accounts (5 enrolled):
#   > acct1: user1@example.com (plus)
#     acct2: user2@example.com (plus)
#     acct3: user3@example.com (free)
#     acct4: user4@example.com (plus)
#     acct5: user5@example.com (plus)

codex-accounts status
# Output:
#   Total accounts: 5
#   Last used:      acct1
#   Next up:        acct2
```

### Step 3: Test rotation

```fish
# Direct usage (rotates automatically)
codex-rotate exec --full-auto "echo hello world"

# Check which account was used
codex-accounts status
```

## Using with gwt-ticket

### Basic Codex mode

```fish
# Uses Codex as primary agent (with account rotation)
gwt-ticket TICKET-123 "Fix the bug" "Description of the fix" --codex
```

This launches Codex in a tmux pane using `codex-rotate exec --full-auto`, which automatically rotates through your enrolled accounts.

### Bridge review mode (Codex writes, Claude reviews)

```fish
# Codex executes, Claude reviews the diff, iterates up to 3 times
gwt-ticket TICKET-123 "Fix the bug" "Description" --codex --bridge
```

Bridge options:
```fish
--bridge-iterations 5     # Max review cycles (default: 3)
--bridge-model claude-sonnet-4-6  # Claude model for reviews
--bridge-mode redteam     # Review style: review|redteam|steelman|assumptions
```

### Crown tournament (multi-agent competition)

```fish
# 3 contestants: 2 Claude + 1 Codex, competing on the same ticket
gwt-ticket --crown 3 --crown-agents claude,claude,codex TICKET "Fix" "Desc"
```

## How Rotation Works

1. Accounts stored at `~/.codex/accounts/<name>/auth.json`
2. `.accounts` file lists enrolled names (newline-delimited)
3. `.current` file tracks the index of the last-used account
4. On each `codex-rotate` call:
   - Reads current index, advances to next (round-robin)
   - Copies that account's `auth.json` to `~/.codex/auth.json`
   - Applies an optional workspace pin from `CODEX_CHATGPT_WORKSPACE_ID`, `~/.codex/accounts/<name>/workspace_id`, or `~/.codex/accounts/.workspace-id`
   - Runs `codex` with the given arguments
   - If "usage limit" error detected in stderr, tries next account
   - If all accounts exhausted, reports failure

## 1Password Sync (Optional)

Sync account credentials across machines via 1Password:

```fish
# Push all local accounts to 1Password
codex-accounts 1p-sync --vault Private

# Pull accounts on a new machine
codex-accounts 1p-pull --vault Private

# Individual push/pull
codex-accounts 1p-push acct1 --vault Private
codex-accounts 1p-pull acct2
```

## Directory Structure

```
~/.codex/
  auth.json              # Active account (managed by codex-rotate)
  config.toml -> dotfiles/.codex/config.toml  # Symlinked config
  accounts/
    .accounts            # Enrolled names list
    .current             # Current rotation index (0-based)
    .workspace-id        # Optional global workspace pin
    acct1/
      auth.json          # OAuth credentials
      workspace_id       # Optional per-account workspace pin
      .1p-meta           # 1Password sync metadata (if synced)
    acct2/
      auth.json
    ...
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `No accounts enrolled` | Run `codex-accounts add <name>` |
| Account skipped (missing auth.json) | Re-enroll: `codex-accounts remove <name>; codex-accounts add <name>` |
| Logged into right email but wrong workspace/org | `codex-accounts workspace discover`, then `codex-accounts workspace set <name> <workspace-id>` |
| All accounts exhausted | Wait for limits to reset, or add more accounts |
| 1Password sync conflict | Use `--force` flag or resolve manually |
| Token expired | `codex-accounts remove <name>; codex-accounts add <name>` |

## Commands Reference

| Command | Description |
|---------|-------------|
| `codex-accounts add <name>` | Enroll new account (browser OAuth) |
| `codex-accounts capture <name>` | Save the current live Codex session into rotation |
| `codex-accounts workspace discover` | List workspace/account UUID candidates from local auth and browser storage |
| `codex-accounts workspace set [name] <workspace-id>` | Pin a global or per-account workspace UUID |
| `codex-accounts workspace clear [name]` | Remove a workspace pin |
| `codex-accounts remove <name>` | Remove account |
| `codex-accounts list` | Show all accounts with JWT info |
| `codex-accounts status` | Show rotation state |
| `codex-rotate [codex-args...]` | Run codex with rotation |
| `codex-accounts 1p-push <name>` | Push to 1Password |
| `codex-accounts 1p-pull [name]` | Pull from 1Password |
| `codex-accounts 1p-sync` | Two-way sync |
