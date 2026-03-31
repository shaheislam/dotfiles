#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIFF_DIR="$ROOT/../.entire/opencode/sse/diffs"

if [ ! -d "$DIFF_DIR" ]; then
	echo "No diff snapshots recorded yet ($DIFF_DIR missing)" >&2
	exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 is required for diff listing" >&2
	exit 1
fi

if ! LATEST=$(
	python3 - "$DIFF_DIR" <<'PY'
import os, sys
directory = os.path.abspath(sys.argv[1])
candidates = [os.path.join(directory, name) for name in os.listdir(directory) if name.endswith('.patch')]
if not candidates:
    raise SystemExit(1)
latest = max(candidates, key=os.path.getmtime)
print(latest)
PY
); then
	echo "No diff snapshots found" >&2
	exit 1
fi

case "${1:-path}" in
--meta)
	if [ -f "$LATEST.json" ]; then
		cat "$LATEST.json"
	else
		echo "{}"
	fi
	;;
--cat)
	cat "$LATEST"
	;;
*)
	echo "$LATEST"
	;;
esac
