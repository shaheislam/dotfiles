#!/usr/bin/env bash
# fix-hookify-imports.sh - Patch hookify plugin's broken Python import path
#
# Problem: The hookify plugin uses `from hookify.core...` imports, but Claude Code's
# versioned plugin cache structure (hookify/0.1.0/) breaks Python package resolution.
# Additionally, CLAUDE_PLUGIN_ROOT may not be available as an env var at runtime
# (Claude Code interpolates it in the command string but may not export it).
#
# Fix: Derive PLUGIN_ROOT from __file__ (the script's own path) and register a
# synthetic hookify package via sys.modules. This works regardless of env vars.
#
# This script should be run after plugin installs/updates (FORCE_AUTOUPDATE_PLUGINS=1
# causes re-downloads every session, overwriting previous patches).

set -euo pipefail

HOOKIFY_BASE="${HOME}/.claude/plugins/cache/claude-code-plugins/hookify"

# Find the latest version directory
if [[ ! -d "$HOOKIFY_BASE" ]]; then
	echo "hookify plugin not found at $HOOKIFY_BASE - skipping"
	exit 0
fi

HOOKIFY_VERSION=$(ls -1 "$HOOKIFY_BASE" | sort -V | tail -1)
HOOKIFY_ROOT="${HOOKIFY_BASE}/${HOOKIFY_VERSION}"
HOOKS_DIR="${HOOKIFY_ROOT}/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
	echo "hookify hooks directory not found at $HOOKS_DIR - skipping"
	exit 0
fi

patched_imports=0
skipped_imports=0
patched_stdin=0

for hook_file in "$HOOKS_DIR"/*.py; do
	[[ -f "$hook_file" ]] || continue

	# Skip files that don't import from hookify (e.g. __init__.py)
	if ! grep -q "from hookify\." "$hook_file" 2>/dev/null; then
		continue
	fi

	# Skip if already has v2 fix (__file__-based)
	if grep -q "os.path.dirname(os.path.dirname(os.path.abspath(__file__)))" "$hook_file" 2>/dev/null; then
		skipped_imports=$((skipped_imports + 1))
	else
		# Apply the import patch using Python with file path as argument
		python3 - "$hook_file" <<'PYEOF'
import sys

hook_file = sys.argv[1]

with open(hook_file, 'r') as f:
    content = f.read()

# Pattern variants to replace (ordered most specific to least specific)
patterns = [
    # v1 fix: env-var-based synthetic module (current broken fix)
    '''# CRITICAL: Register hookify as a synthetic package pointing to PLUGIN_ROOT
# The versioned directory structure (hookify/0.1.0/) prevents normal package resolution,
# so we register the package manually with __path__ pointing to the versioned dir.
import types
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT and 'hookify' not in sys.modules:
    _pkg = types.ModuleType('hookify')
    _pkg.__path__ = [PLUGIN_ROOT]
    _pkg.__package__ = 'hookify'
    sys.modules['hookify'] = _pkg''',

    # Original broken: env-var sys.path with extra comments
    '''# CRITICAL: Add plugin root to Python path for imports
# We need to add the parent of the plugin directory so Python can find "hookify" package
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT:
    # Add the parent directory of the plugin
    parent_dir = os.path.dirname(PLUGIN_ROOT)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)

    # Also add PLUGIN_ROOT itself in case we have other scripts
    if PLUGIN_ROOT not in sys.path:
        sys.path.insert(0, PLUGIN_ROOT)''',

    # Original broken: env-var sys.path (compact)
    '''# CRITICAL: Add plugin root to Python path for imports
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT:
    parent_dir = os.path.dirname(PLUGIN_ROOT)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    if PLUGIN_ROOT not in sys.path:
        sys.path.insert(0, PLUGIN_ROOT)''',
]

new_block = '''# CRITICAL: Register hookify as a synthetic package for imports
# Derive PLUGIN_ROOT from this script's location (hooks/ subdir of plugin root).
# Cannot rely on CLAUDE_PLUGIN_ROOT env var - it may only be interpolated in the
# command string, not exported to the subprocess environment.
import types
PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if 'hookify' not in sys.modules:
    _pkg = types.ModuleType('hookify')
    _pkg.__path__ = [PLUGIN_ROOT]
    _pkg.__package__ = 'hookify'
    sys.modules['hookify'] = _pkg'''

replaced = False
for pattern in patterns:
    if pattern in content:
        content = content.replace(pattern, new_block)
        replaced = True
        break

if not replaced:
    print(f'WARNING: No known pattern found in {hook_file}', file=sys.stderr)
    sys.exit(1)

with open(hook_file, 'w') as f:
    f.write(content)
PYEOF
		patched_imports=$((patched_imports + 1))
	fi

	# Harden stdin handling so missing stdin doesn't throw JSON errors
	stdin_result=$(
		python3 - "$hook_file" <<'PYEOF'
import json
import sys

hook_file = sys.argv[1]

with open(hook_file, 'r') as f:
    content = f.read()

if 'json.load(sys.stdin)' not in content:
    sys.exit(0)

helper_name = '_hookify_safe_json_load'
helper_block = '''
def _hookify_safe_json_load():
    """Return JSON from stdin or an empty dict if unavailable."""
    try:
        raw_data = sys.stdin.read()
    except Exception:
        return {}
    if not raw_data.strip():
        return {}
    try:
        return json.loads(raw_data)
    except json.JSONDecodeError:
        return {}
'''.strip('\n')

changed = False

if helper_name not in content:
    marker = 'import json\n'
    insertion = f"{marker}\n{helper_block}\n\n"
    if marker in content:
        content = content.replace(marker, insertion, 1)
    else:
        content = f"{helper_block}\n\n" + content
    changed = True

if 'json.load(sys.stdin)' in content:
    content = content.replace('json.load(sys.stdin)', f'{helper_name}()')
    changed = True

if changed:
    with open(hook_file, 'w') as f:
        f.write(content)
    print('patched')
PYEOF
	)

	if [[ -n "${stdin_result}" ]]; then
		patched_stdin=$((patched_stdin + 1))
	fi
done

if [[ $patched_imports -gt 0 ]]; then
	echo "hookify: patched $patched_imports hook scripts (imports, v$HOOKIFY_VERSION)"
elif [[ $skipped_imports -gt 0 ]]; then
	echo "hookify: import fixes already present ($skipped_imports scripts, v$HOOKIFY_VERSION)"
else
	echo "hookify: no import patches applied"
fi

if [[ $patched_stdin -gt 0 ]]; then
	echo "hookify: added safe stdin handling to $patched_stdin scripts (v$HOOKIFY_VERSION)"
else
	echo "hookify: safe stdin handling already present"
fi
