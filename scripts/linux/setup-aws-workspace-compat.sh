#!/usr/bin/env bash

# setup-aws-workspace-compat.sh - Backward compatibility wrapper
# Redirects to the unified setup.sh with Linux settings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  This script has been replaced by the unified setup system"
echo "→ Redirecting to: ../setup.sh --os linux $*"
echo ""

exec "$SCRIPT_DIR/../setup.sh" --os linux "$@"
