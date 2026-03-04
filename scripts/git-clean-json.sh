#!/usr/bin/env bash
#
# git-clean-json.sh - Git clean filter for JSON files
#
# Normalizes JSON before storing in git: sorts keys, pretty-prints with
# 2-space indent, and uses standard character encoding. This eliminates
# phantom diffs from key reordering (e.g., Claude Code re-serializing
# settings.json with alphabetically sorted keys).
#
# Registered via .gitattributes:
#   .claude/settings.json filter=json-normalize
#
# Git config (set by setup.sh):
#   [filter "json-normalize"]
#       clean = scripts/git-clean-json.sh
#
# Usage: reads from stdin, writes normalized JSON to stdout

python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    json.dump(data, sys.stdout, indent=2, sort_keys=True, ensure_ascii=False)
    print()
except (json.JSONDecodeError, ValueError):
    sys.stdin.seek(0)
    sys.stdout.write(sys.stdin.read())
"
