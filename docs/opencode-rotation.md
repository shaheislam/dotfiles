# OpenCode Rotation Flow

This note explains how the OpenCode ↔ OpenAI account rotation feature works from CLI enrollment through the runtime plugin that automatically retries prompts when an account hits its usage cap.

## Goals

- Keep long-running OpenCode sessions alive by rotating across pre-authenticated OpenAI accounts whenever a 429/usage-limit error fires.
- Provide a single source of truth for agents so they know which commands prep the environment, how rotation behaves, and which tests keep the feature healthy.

## Building Blocks

### `opencode-accounts` (fish)

Path: `.config/fish/functions/opencode-accounts.fish`

- `add <name>` – runs `opencode auth login` and saves the resulting `.openai` entry to `~/.opencode/accounts/<name>/openai-auth.json`, updating `.accounts` and `.current` pointers.
- `capture <name>` – records the currently active auth for quick refreshes.
- `switch <name>` – rewrites `~/.local/share/opencode/auth.json` (OpenCode’s live credential) with a saved profile.
- `check-and-rotate` – used in `gwt-ticket` before every launch to ensure a valid account. It auto-saves the live token if it isn’t in the rotation list, probes each saved profile via `scripts/opencode/usage-check.sh`, and if every profile is exhausted it falls back to an interactive login.
- Helpers like `status`, `list`, and `check` expose rotation state for humans. `ai-accounts.fish` consumes these commands so `ai-accounts` shows OpenCode/Codex parity in one shot.

Profiles live under `~/.opencode/accounts/`. The `.accounts` file stores display order, `.current` stores the numeric index of the last successful profile, and each profile keeps a trimmed-down `openai-auth.json` so Codex can stay in sync via `_ai_accounts_sync`.

### Usage probe

Path: `scripts/opencode/usage-check.sh`

- Issues a 1-token `gpt-4o-mini` completion using the provided bearer token (from either `auth.json` or `--token`).
- Exit codes: `0` available, `1` rate/usage limit, `2` invalid token/network failure, `3` missing auth. Rotation relies on this script whenever it needs to vet a saved profile (`probeToken()` in the plugin) or when `opencode-accounts check` is invoked manually.

### Rotation plugin

Path: `.opencode/plugins/openai-rotate.ts`

- Hooks into `chat.message` events to capture the last prompt (`pendingPrompts`) scoped to each OpenCode session.
- Watches `session.error` events. When an assistant message produces an error and `isOpenAIUsageLimit()` sees 429/usage-limit hints (including custom provider payloads), the plugin kicks off rotation.
- Guards against duplicate work with `rotatingSessions` (per session ID) and `handledMessages` to avoid replaying the same completion twice.

## Runtime Flow

1. **Prompt capture** – When a user prompt is sent to an OpenAI-backed model (`providerID` of `openai` or `codex`), the plugin snapshots the agent/model/system/tools/payload, so it can be replayed verbatim if needed.
2. **Error detection** – If OpenCode reports a `session.error` for the same session and the stored message hasn’t already been retried, `isOpenAIUsageLimit()` inspects HTTP status, response bodies, and provider IDs to verify the error really is an OpenAI usage cap (avoiding unrelated provider failures).
3. **Account rotation** – `rotateAccount()`:
   - Reads `~/.local/share/opencode/auth.json` to find the active OpenAI token and auto-saves it under `~/.opencode/accounts/auto-<timestamp>` if the profile isn’t already in `.accounts`.
   - Loads the profile list from `.accounts`, determines the active profile, then iterates through the remaining names in round-robin order using `rotateFrom()`.
   - For each candidate profile, reads `<profile>/openai-auth.json`, grabs the access token, and calls `probeToken()` (which shells out to `usage-check.sh`).
   - On the first profile whose probe exits with `0`, writes the token back to the live `auth.json` via `switchAccount()`, persists the new `.current` index, and returns `{ ok: true, name }`.
   - If every token is exhausted, returns `{ ok: false, reason }` so the plugin can warn the user to enroll another account via `opencode-accounts`.
4. **User feedback + replay** – Success produces a warning toast (“Switched to '<name>'…”), while failures raise an error toast pointing to `opencode-accounts`. On success the plugin rebuilds the prompt body with `toPromptParts()` and calls `client.session.prompt()` to transparently resend the request with the new account.
5. **Bookkeeping** – Regardless of outcome, `rotatingSessions` is cleared so future errors can retry again. `pendingPrompts` is cleared once a non-error assistant message lands.

Environment knobs:

- `OPENCODE_AUTH_FILE`, `OPENCODE_ACCOUNTS_DIR`, and `OPENCODE_USAGE_CHECK_SCRIPT` let harness tests point at temp directories.
- `OPENCODE_ROTATE_DEBUG_LOG` captures verbose traces for diagnosing odd failures.

## Harness Coverage

- **OpenCode hosts (gwt-ticket, dev panes, Neovim bridge launches)** call `scripts/opencode/check-and-rotate.sh` before the CLI boots. The helper runs `usage-check.sh`, invokes `opencode-accounts check-and-rotate` via fish if the current sub is exhausted, and re-checks before allowing the session to proceed.
- **Codex harnesses** (`.claude/hooks/cross-provider-bridge.sh`, `scripts/codex-bridge-review.sh`, and any other shell scripts) shell through `scripts/codex/run-with-rotation.sh`, which drops into fish long enough to execute `codex-rotate` with the requested args, then streams output back to the original process. This keeps cross-provider codex reviewers and automation runs alive without extra flags.
- **Neovim plugin flows** inherit whatever harness launches them (gwt-ticket or cross-provider), so the same helpers guarantee autorotation even when prompts originate from inside Neovim.

## Tests & Validation

- `scripts/opencode/test-rotation.sh` – Bun harness that runs the plugin directly, injects fake accounts, and verifies both successful rotations and exhausted-account failures for `openai` *and* `codex` provider IDs.
- `scripts/opencode/test-live-rotation.sh` – boots a temp HOME, spins up a Bun-powered mock OpenAI server, runs `opencode run` twice (before and after token swap), and confirms the session keeps streaming tokens after the auth switch.
- `scripts/opencode/doctor.sh` – quick health check that the binary, config, auth, and account profiles exist, and that `usage-check.sh` succeeds.
- `scripts/test-filter.sh opencode` – aggregates the OpenCode-specific checks so CI agents can run `scripts/test-filter.sh opencode` for the entire suite.

## Operations Playbook

- **Enroll accounts** – `opencode-accounts add personal`, repeat for each subscription. Use `opencode-accounts status` to confirm the rotation order and active profile.
- **Pre-flight** – `gwt-ticket` automatically runs `opencode-accounts check-and-rotate`, but you can run it manually if you expect to hammer the API outside that workflow.
- **During rotation failures** – If you see the “Save another account with opencode-accounts” toast, either capture a fresh login (`opencode-accounts capture new-name`) or prune stale profiles so `.accounts` matches reality.
- **Observability** – Set `OPENCODE_ROTATE_DEBUG_LOG=/tmp/opencode-rotate.log` before launching OpenCode to capture every detection/rotation decision.

## Relationship to Codex rotation

The Codex CLI uses `codex-rotate.fish` for similar round-robin failover. Both systems share helpers through `ai-accounts.fish`, but they rotate different auth stores (`~/.codex/accounts` vs `~/.opencode/accounts`). Keeping both in sync ensures `codex-rotate` and the OpenCode plugin draw from the same pool of tokens.

## Quick Reference

- `opencode-accounts add <name>` – enroll a new OpenAI account.
- `opencode-accounts list` – show saved profiles and the current pointer.
- `opencode-accounts check-and-rotate` – manually verify an available profile before a big session.
- `scripts/opencode/check-and-rotate.sh --quiet` – CLI-friendly preflight for hooks (used by cross-provider OpenCode runs).
- `scripts/opencode/test-rotation.sh` – fast local assurance that the plugin still rotates + retries prompts.
- `scripts/opencode/test-live-rotation.sh` – heavier, end-to-end smoke.
