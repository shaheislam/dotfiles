#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.config/opencode/plugin/openai-rotate.ts"

if ! command -v bun >/dev/null 2>&1; then
    echo "FAIL bun is required for rotation validation" >&2
    exit 1
fi

if [ ! -f "$PLUGIN" ]; then
    echo "FAIL missing plugin: $PLUGIN" >&2
    exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

pass() {
    printf 'PASS %s\n' "$1"
}

fail() {
    printf 'FAIL %s\n' "$1" >&2
    exit 1
}

write_case() {
    local case_dir="$1"
    local spare_token="$2"

    mkdir -p "$case_dir/accounts/current" "$case_dir/accounts/spare" "$case_dir/auth"

    jq -n '{openai:{access:"bad-token",accountId:"acct-current"}}' >"$case_dir/auth/auth.json"
    printf 'current\nspare\n' >"$case_dir/accounts/.accounts"
    jq -n '{access:"bad-token",accountId:"acct-current"}' >"$case_dir/accounts/current/openai-auth.json"
    jq -n --arg token "$spare_token" '{access:$token,accountId:"acct-spare"}' >"$case_dir/accounts/spare/openai-auth.json"

    cat >"$case_dir/usage-check.sh" <<'EOF'
#!/usr/bin/env bash
if [ "$3" = "good-token" ]; then
    exit 0
fi
exit 1
EOF
    chmod +x "$case_dir/usage-check.sh"
}

HARNESS="$TMPDIR/harness.mjs"
cat >"$HARNESS" <<'EOF'
const fs = await import("node:fs/promises")
const pluginUrl = new URL(`file://${process.env.OPENCODE_ROTATE_PLUGIN}`)
const { OpenAIRotatePlugin } = await import(pluginUrl.href)
const providerID = process.env.OPENCODE_ROTATE_PROVIDER_ID || "openai"

const calls = []
const hooks = await OpenAIRotatePlugin({
  client: {
    tui: { showToast: async (args) => calls.push(["toast", args.body]) },
    session: { prompt: async (args) => calls.push(["prompt", args.body]) },
  },
  directory: process.cwd(),
  worktree: process.cwd(),
  project: {},
  serverUrl: new URL("http://localhost"),
  $: undefined,
})

await hooks["chat.message"](
  { sessionID: "session-1", agent: "build", model: { providerID, modelID: "gpt-5.4" } },
  {
    message: {
      id: "user-1",
      sessionID: "session-1",
      role: "user",
      time: { created: Date.now() },
      agent: "build",
      model: { providerID, modelID: "gpt-5.4" },
      system: "system-note",
      variant: "default",
    },
    parts: [{ id: "part-1", sessionID: "session-1", messageID: "user-1", type: "text", text: "hello rotate" }],
  },
)

if (process.env.OPENCODE_ROTATE_SKIP_ERROR !== "1") {
  const errorEvent = {
    event: {
      type: "session.error",
      properties: {
        sessionID: "session-1",
        error: { name: "APIError", data: { statusCode: 429, message: "usage.limit reached", providerID } },
      },
    },
  }

  await hooks.event(errorEvent)
  await hooks.event(errorEvent)
}

const auth = JSON.parse(await fs.readFile(process.env.OPENCODE_AUTH_FILE, "utf8"))
console.log(JSON.stringify({ calls, activeAccess: auth.openai.access }))
EOF

run_case() {
    local case_name="$1"
    local spare_token="$2"
    local expected_access="$3"
    local expected_toast_variant="$4"
    local expected_prompt_count="$5"
    local provider_id="${6:-openai}"

    local case_dir="$TMPDIR/$case_name"
    write_case "$case_dir" "$spare_token"

    local result
    result="$(OPENCODE_ROTATE_PLUGIN="$PLUGIN" \
        OPENCODE_AUTH_FILE="$case_dir/auth/auth.json" \
        OPENCODE_ACCOUNTS_DIR="$case_dir/accounts" \
        OPENCODE_USAGE_CHECK_SCRIPT="$case_dir/usage-check.sh" \
        OPENCODE_ROTATE_PROVIDER_ID="$provider_id" \
        OPENCODE_OPENAI_PREFLIGHT=0 \
        bun "$HARNESS")" || fail "$case_name execution failed"

    local actual_access
    actual_access="$(printf '%s' "$result" | jq -r '.activeAccess')"
    [ "$actual_access" = "$expected_access" ] || fail "$case_name expected access $expected_access, got $actual_access"

    local toast_variant
    toast_variant="$(printf '%s' "$result" | jq -r '.calls[0][1].variant')"
    [ "$toast_variant" = "$expected_toast_variant" ] || fail "$case_name expected toast $expected_toast_variant, got $toast_variant"

    local prompt_count
    prompt_count="$(printf '%s' "$result" | jq '[.calls[] | select(.[0] == "prompt")] | length')"
    [ "$prompt_count" = "$expected_prompt_count" ] || fail "$case_name expected $expected_prompt_count prompt retries, got $prompt_count"

    local toast_count
    toast_count="$(printf '%s' "$result" | jq '[.calls[] | select(.[0] == "toast")] | length')"
    [ "$toast_count" = "1" ] || fail "$case_name expected one toast after duplicate errors, got $toast_count"

    pass "$case_name"
}

run_preflight_case() {
    local case_name="$1"
    local case_dir="$TMPDIR/$case_name"
    write_case "$case_dir" good-token

    local result
    result="$(OPENCODE_ROTATE_PLUGIN="$PLUGIN" \
        OPENCODE_AUTH_FILE="$case_dir/auth/auth.json" \
        OPENCODE_ACCOUNTS_DIR="$case_dir/accounts" \
        OPENCODE_USAGE_CHECK_SCRIPT="$case_dir/usage-check.sh" \
        OPENCODE_ROTATE_PROVIDER_ID="openai" \
        OPENCODE_ROTATE_SKIP_ERROR=1 \
        bun "$HARNESS")" || fail "$case_name execution failed"

    local actual_access
    actual_access="$(printf '%s' "$result" | jq -r '.activeAccess')"
    [ "$actual_access" = "good-token" ] || fail "$case_name expected preflight switch to good-token, got $actual_access"

    local toast_variant
    toast_variant="$(printf '%s' "$result" | jq -r '.calls[0][1].variant')"
    [ "$toast_variant" = "warning" ] || fail "$case_name expected warning toast, got $toast_variant"

    local prompt_count
    prompt_count="$(printf '%s' "$result" | jq '[.calls[] | select(.[0] == "prompt")] | length')"
    [ "$prompt_count" = "0" ] || fail "$case_name expected no retry prompt during preflight, got $prompt_count"

    pass "$case_name"
}

run_case success-openai good-token good-token warning 1 openai
run_case exhausted bad-spare bad-token error 0 openai
run_case success-codex good-token good-token warning 1 codex
run_preflight_case preflight-openai

pass "rotation validation complete"
