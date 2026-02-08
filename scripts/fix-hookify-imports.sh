#!/usr/bin/env bash
# fix-hookify-imports.sh - Patch hookify plugin's broken Python import path
#
# Problem: The hookify plugin uses `from hookify.core...` imports, but Claude Code's
# versioned plugin cache structure (hookify/0.1.0/) breaks Python package resolution.
# The hook scripts add parent_dir to sys.path, but parent_dir is hookify/ which only
# contains 0.1.0/ - not the hookify package Python expects.
#
# Fix: Replace the broken sys.path manipulation with a synthetic package registration
# using sys.modules, pointing hookify.__path__ to the versioned PLUGIN_ROOT directory.
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

# The broken pattern to find
BROKEN_PATTERN="parent_dir = os.path.dirname(PLUGIN_ROOT)"

# Check if already patched (look for the fix marker)
PATCHED_MARKER="sys.modules\['hookify'\]"

patched=0
skipped=0

for hook_file in "$HOOKS_DIR"/*.py; do
    [[ -f "$hook_file" ]] || continue

    if grep -q "$PATCHED_MARKER" "$hook_file" 2>/dev/null; then
        skipped=$((skipped + 1))
        continue
    fi

    if ! grep -q "$BROKEN_PATTERN" "$hook_file" 2>/dev/null; then
        continue
    fi

    # Apply the fix: replace the broken path setup block
    python3 -c "
import re, sys

with open('$hook_file', 'r') as f:
    content = f.read()

old_block = '''# CRITICAL: Add plugin root to Python path for imports
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT:
    parent_dir = os.path.dirname(PLUGIN_ROOT)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    if PLUGIN_ROOT not in sys.path:
        sys.path.insert(0, PLUGIN_ROOT)'''

# Also handle the variant with extra comment line
old_block_variant = '''# CRITICAL: Add plugin root to Python path for imports
# We need to add the parent of the plugin directory so Python can find \"hookify\" package
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT:
    # Add the parent directory of the plugin
    parent_dir = os.path.dirname(PLUGIN_ROOT)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)

    # Also add PLUGIN_ROOT itself in case we have other scripts
    if PLUGIN_ROOT not in sys.path:
        sys.path.insert(0, PLUGIN_ROOT)'''

new_block = '''# CRITICAL: Register hookify as a synthetic package pointing to PLUGIN_ROOT
# The versioned directory structure (hookify/0.1.0/) prevents normal package resolution,
# so we register the package manually with __path__ pointing to the versioned dir.
import types
PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT and 'hookify' not in sys.modules:
    _pkg = types.ModuleType('hookify')
    _pkg.__path__ = [PLUGIN_ROOT]
    _pkg.__package__ = 'hookify'
    sys.modules['hookify'] = _pkg'''

if old_block_variant in content:
    content = content.replace(old_block_variant, new_block)
elif old_block in content:
    content = content.replace(old_block, new_block)
else:
    print(f'WARNING: Could not find expected pattern in {sys.argv[0]}', file=sys.stderr)
    sys.exit(1)

with open('$hook_file', 'w') as f:
    f.write(content)
"

    patched=$((patched + 1))
done

if [[ $patched -gt 0 ]]; then
    echo "hookify: patched $patched hook scripts (v$HOOKIFY_VERSION)"
elif [[ $skipped -gt 0 ]]; then
    echo "hookify: already patched ($skipped scripts, v$HOOKIFY_VERSION)"
else
    echo "hookify: no scripts needed patching"
fi
