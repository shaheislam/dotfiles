#!/usr/bin/env bash
set -euo pipefail

if [ "${OPENCODE_NVIM_HEALTH_SKIP:-}" = "1" ]; then
	echo "Skipping Neovim health checks (OPENCODE_NVIM_HEALTH_SKIP=1)"
	exit 0
fi

if ! command -v nvim >/dev/null 2>&1; then
	echo "Skipping Neovim health checks (nvim not found)" >&2
	exit 0
fi

TMP_LUA=$(mktemp)
cat <<'LUA' >"$TMP_LUA"
local modules = {"opencode", "codecompanion", "wrapped"}
local missing = {}
for _, mod in ipairs(modules) do
  local ok, err = pcall(require, mod)
  if not ok then
    table.insert(missing, string.format("%s (%s)", mod, err))
  end
end
if #missing > 0 then
  error("Neovim modules missing: " .. table.concat(missing, ", "))
end
LUA

NVIM_CMD=(nvim --headless)
if [ -n "${OPENCODE_NVIM_APPNAME:-}" ]; then
	NVIM_CMD=(env NVIM_APPNAME="$OPENCODE_NVIM_APPNAME" "${NVIM_CMD[@]}")
fi

set +euo pipefail
OUTPUT=$("${NVIM_CMD[@]}" -c "luafile $TMP_LUA" -c "checkhealth opencode" -c "checkhealth codecompanion" -c "qa" 2>&1)
STATUS=$?
set -euo pipefail
rm -f "$TMP_LUA"

if [ $STATUS -ne 0 ]; then
	echo "$OUTPUT" >&2
	exit $STATUS
fi

echo "$OUTPUT" | grep -qi "error" && {
	echo "$OUTPUT" >&2
	echo "Neovim checkhealth reported errors" >&2
	exit 1
}

exit 0
