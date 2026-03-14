#!/usr/bin/env bash
# aimux notify - multi-channel notification dispatch

_notify_msg=""
_notify_title="aimux"
_notify_channels=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --title | -t)
        _notify_title="$2"
        shift 2
        ;;
    --bell)
        _notify_channels+=(bell)
        shift
        ;;
    --osc)
        _notify_channels+=(osc)
        shift
        ;;
    --native)
        _notify_channels+=(native)
        shift
        ;;
    --webhook)
        _notify_channels+=(webhook)
        shift
        ;;
    --all)
        _notify_channels=(bell osc native)
        shift
        ;;
    -h | --help)
        echo "Usage: aimux notify [--bell] [--osc] [--native] [--all] [--title TITLE] <message>"
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _notify_msg="$1"
        shift
        ;;
    esac
done

[[ -z "$_notify_msg" ]] && die "Usage: aimux notify <message>"

# Default: all available channels
[[ ${#_notify_channels[@]} -eq 0 ]] && _notify_channels=(bell osc native)

for _ch in "${_notify_channels[@]}"; do
    case "$_ch" in
    bell)
        printf '\a'
        ;;
    osc)
        # OSC 9 (iTerm2, WezTerm)
        printf '\033]9;%s\007' "$_notify_msg"
        # OSC 99 (kitty)
        printf '\033]99;i=aimux:d=0;%s\033\\' "$_notify_msg"
        ;;
    native)
        if [[ "$(uname)" == "Darwin" ]]; then
            if has terminal-notifier; then
                terminal-notifier -title "$_notify_title" -message "$_notify_msg" -group aimux 2>/dev/null || true
            else
                osascript -e "display notification \"$_notify_msg\" with title \"$_notify_title\"" 2>/dev/null || true
            fi
        elif [[ "$(uname)" == "Linux" ]]; then
            if has notify-send; then
                notify-send "$_notify_title" "$_notify_msg" 2>/dev/null || true
            fi
        fi
        ;;
    webhook)
        local_url="${AIMUX_WEBHOOK_URL:-}"
        if [[ -n "$local_url" ]]; then
            curl -s -X POST "$local_url" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"[$_notify_title] $_notify_msg\"}" &>/dev/null &
        fi
        ;;
    esac
done

log "notify: [$_notify_title] $_notify_msg (channels: ${_notify_channels[*]})"
