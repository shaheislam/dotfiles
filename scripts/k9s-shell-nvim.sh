#!/bin/bash
# K9s shell wrapper with auto-nvim installation
# Usage: k9s-shell-nvim.sh <namespace> <pod> <container> <shell>

NAMESPACE="$1"
POD="$2"
CONTAINER="$3"
SHELL_TYPE="${4:-sh}"

# Build kubectl command
KUBECTL_CMD="kubectl exec -it -n $NAMESPACE $POD"
[ -n "$CONTAINER" ] && KUBECTL_CMD="$KUBECTL_CMD -c $CONTAINER"

# First, try to install nvim silently
kubectl exec -n $NAMESPACE $POD ${CONTAINER:+-c $CONTAINER} -- sh -c '
if ! command -v nvim >/dev/null 2>&1; then
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache neovim >/dev/null 2>&1
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1 && apt-get install -y neovim >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    yum install -y neovim >/dev/null 2>&1
  fi
fi
' 2>/dev/null || true

# Now exec into the shell
if [ "$SHELL_TYPE" = "bash" ]; then
  $KUBECTL_CMD -- bash -c 'export TERM=xterm-256color; export EDITOR=nvim; exec bash' 2>/dev/null || \
  $KUBECTL_CMD -- sh -c 'export TERM=xterm-256color; export EDITOR=nvim; exec sh'
else
  $KUBECTL_CMD -- sh -c 'export TERM=xterm-256color; export EDITOR=nvim; exec sh'
fi