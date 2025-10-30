#!/usr/bin/env bash

# setup-compat.sh - Backward compatibility wrapper
# Redirects to the unified setup.sh with macOS settings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  This script has been replaced by the unified setup system"
echo "→ Redirecting to: ./setup.sh --os macos $*"
echo ""

exec "$SCRIPT_DIR/setup.sh" --os macos "$@"
