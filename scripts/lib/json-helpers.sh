#!/usr/bin/env bash
#
# json-helpers.sh - Lightweight JSON helpers using jq
#
# Replaces python3 JSON parsing (~30-50ms startup) with jq (<5ms startup).
# Source this file from any script that needs JSON field extraction.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/json-helpers.sh"
#
# Functions:
#   json_val <key> <json>                  - Extract top-level field, empty string default
#   json_val_default <key> <default> <json> - Extract field with custom default
#   json_arr_filter <filter_expr> <json>    - Filter array with jq expression

# Extract single top-level field from JSON string
# Usage: json_val "state" "$json_string"
json_val() {
    local key="$1" json="$2"
    printf '%s' "$json" | jq -r ".$key // \"\"" 2>/dev/null
}

# Extract field with explicit default value
# Usage: json_val_default "state" "unknown" "$json_string"
json_val_default() {
    local key="$1" default="$2" json="$3"
    printf '%s' "$json" | jq -r ".$key // \"$default\"" 2>/dev/null
}

# Filter JSON array with jq expression, one result per line
# Usage: json_arr_filter '.[] | select(.state == "stuck") | .path' "$json_string"
json_arr_filter() {
    local expr="$1" json="$2"
    printf '%s' "$json" | jq -r "$expr" 2>/dev/null
}
