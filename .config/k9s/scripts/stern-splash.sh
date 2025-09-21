#!/usr/bin/env bash
# Stern with enhanced highlighting for k9s
# Uses stern's native highlighting features for better k9s integration

# Extract arguments
CONTEXT="$1"
NAMESPACE="$2"
NAME="$3"

# Run stern with enhanced native highlighting
# This stays within k9s viewer instead of launching external programs
exec stern \
    --tail=100 \
    --timestamps \
    --color=always \
    --diff-container \
    --highlight "ERROR|error|Error" \
    --highlight "WARN|warn|Warning|WARNING" \
    --highlight "INFO|info|Info" \
    --highlight "DEBUG|debug|Debug" \
    --highlight "FATAL|fatal|Fatal" \
    --highlight "TRACE|trace|Trace" \
    --highlight '\b[45]\d\d\b' \
    --highlight '\b200\b|\b201\b|\b204\b' \
    --highlight '\b404\b|\b403\b|\b401\b' \
    --highlight '\bGET\b|\bPOST\b|\bPUT\b|\bDELETE\b|\bPATCH\b' \
    --context "$CONTEXT" \
    -n "$NAMESPACE" \
    "$NAME"