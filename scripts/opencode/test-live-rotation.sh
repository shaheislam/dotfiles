#!/usr/bin/env bash
set -euo pipefail

if ! command -v bun >/dev/null 2>&1; then
	echo "FAIL bun is required for live rotation validation" >&2
	exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
	echo "FAIL opencode is required for live rotation validation" >&2
	exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
	echo "FAIL sqlite3 is required for live rotation validation" >&2
	exit 1
fi

TMPDIR="$(mktemp -d)"

cleanup() {
	if [ "${OPENCODE_TEST_DEBUG:-0}" = "1" ]; then
		echo "DEBUG tmpdir preserved at $TMPDIR" >&2
		return
	fi
	rm -rf "$TMPDIR"
}

trap cleanup EXIT

HOME_DIR="$TMPDIR/home"
PROJECT_DIR="$TMPDIR/project"
LOG_DIR="$TMPDIR/logs"
AUTH_FILE="$HOME_DIR/.local/share/opencode/auth.json"
DB_FILE="$HOME_DIR/.local/share/opencode/opencode.db"
SERVER_LOG="$LOG_DIR/server.log"
RUN1_STDOUT="$LOG_DIR/run1.stdout"
RUN1_STDERR="$LOG_DIR/run1.stderr"
RUN2_STDOUT="$LOG_DIR/run2.stdout"
RUN2_STDERR="$LOG_DIR/run2.stderr"
MOCK_SERVER="$TMPDIR/mock-openai.mjs"

mkdir -p "$PROJECT_DIR" "$LOG_DIR" "$(dirname "$AUTH_FILE")"

cat >"$PROJECT_DIR/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "openai": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://127.0.0.1:43111/v1"
      },
      "models": {
        "gpt-5.4": {
          "name": "GPT-5.4 Test"
        }
      }
    }
  },
  "model": "openai/gpt-5.4",
  "small_model": "openai/gpt-5.4",
  "permission": "allow",
  "plugin": [],
  "share": "disabled",
  "autoupdate": false,
  "instructions": []
}
EOF

jq -n '{openai:{access:"bad-token",accountId:"acct-current"}}' >"$AUTH_FILE"

cat >"$MOCK_SERVER" <<'EOF'
import { appendFile } from "node:fs/promises"

const logPath = process.env.OPENCODE_MOCK_SERVER_LOG
const encoder = new TextEncoder()

function chatChunk(delta, finishReason = null) {
  return {
    id: "chatcmpl-test",
    object: "chat.completion.chunk",
    created: Math.floor(Date.now() / 1000),
    model: "gpt-5.4",
    choices: [{ index: 0, delta, finish_reason: finishReason }],
  }
}

const server = Bun.serve({
  port: 43111,
  fetch: async (request) => {
    const auth = request.headers.get("authorization") || ""
    const token = auth.replace(/^Bearer\s+/i, "")
    const url = new URL(request.url)

    if (request.method === "GET" && request.url.endsWith("/v1/models")) {
      await appendFile(logPath, `${request.method} ${url.pathname} ${token}\n`)
      return Response.json({ object: "list", data: [{ id: "gpt-5.4", object: "model", owned_by: "test" }] })
    }

    const body = await request.json().catch(() => ({}))
    await appendFile(logPath, `${request.method} ${url.pathname} ${token} ${JSON.stringify({ model: body.model, stream: body.stream })}\n`)

    if (body.stream) {
      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(chatChunk({ role: "assistant" }))}\n\n`))
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(chatChunk({ content: "ROTATION_OK" }))}\n\n`))
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(chatChunk({}, "stop"))}\n\n`))
          controller.enqueue(encoder.encode("data: [DONE]\n\n"))
          controller.close()
        },
      })

      return new Response(stream, {
        headers: {
          "content-type": "text/event-stream",
          "cache-control": "no-cache",
          connection: "keep-alive"
        }
      })
    }

    return Response.json({
      id: "chatcmpl-test",
      object: "chat.completion",
      created: Math.floor(Date.now() / 1000),
      model: "gpt-5.4",
      choices: [{ index: 0, message: { role: "assistant", content: "ROTATION_OK" }, finish_reason: "stop" }]
    })
  },
})

await appendFile(logPath, `LISTEN ${server.port}\n`)
await new Promise(() => {})
EOF

OPENCODE_MOCK_SERVER_LOG="$SERVER_LOG" bun "$MOCK_SERVER" >"$LOG_DIR/mock.stdout" 2>"$LOG_DIR/mock.stderr" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true; cleanup' EXIT
sleep 1

HOME="$HOME_DIR" \
	opencode run --dir "$PROJECT_DIR" --title live-rotation-test --model openai/gpt-5.4 "Reply with exactly ROTATION_OK" \
	--print-logs --log-level DEBUG \
	>"$RUN1_STDOUT" 2>"$RUN1_STDERR" || {
	cat "$RUN1_STDERR" >&2
	echo "FAIL initial live opencode run failed" >&2
	exit 1
}

grep -q 'ROTATION_OK' "$RUN1_STDOUT" || {
	cat "$RUN1_STDOUT" >&2
	echo "FAIL initial run did not produce ROTATION_OK" >&2
	exit 1
}

SESSION_ID="$(sqlite3 "$DB_FILE" "select id from session order by rowid desc limit 1;")"
[ -n "$SESSION_ID" ] || {
	echo "FAIL could not determine latest OpenCode session id" >&2
	exit 1
}

jq '.openai = {access:"good-token",accountId:"acct-spare"}' "$AUTH_FILE" >"$TMPDIR/auth.next.json"
mv "$TMPDIR/auth.next.json" "$AUTH_FILE"

HOME="$HOME_DIR" \
	opencode run --dir "$PROJECT_DIR" --session "$SESSION_ID" --model openai/gpt-5.4 "Reply with exactly ROTATION_OK" \
	--print-logs --log-level DEBUG \
	>"$RUN2_STDOUT" 2>"$RUN2_STDERR" || {
	cat "$RUN2_STDERR" >&2
	echo "FAIL continued live opencode run failed" >&2
	exit 1
}

grep -q 'ROTATION_OK' "$RUN2_STDOUT" || {
	cat "$RUN2_STDOUT" >&2
	echo "FAIL continued run did not produce ROTATION_OK" >&2
	exit 1
}

post_count="$(grep -c 'POST /v1/chat/completions' "$SERVER_LOG" || true)"
[ "$post_count" -ge 2 ] || {
	cat "$SERVER_LOG" >&2
	echo "FAIL expected at least two live OpenCode requests" >&2
	exit 1
}

active_access="$(jq -r '.openai.access' "$AUTH_FILE")"
[ "$active_access" = "good-token" ] || {
	echo "FAIL expected active auth to switch to good-token, got $active_access" >&2
	exit 1
}

printf 'PASS live session created\n'
printf 'PASS live session continued after auth switch\n'
printf 'PASS live rotation smoke complete\n'
