function openclaw-notify --description "Send notifications via OpenClaw channels"
    set -l channel $OPENCLAW_NOTIFY_CHANNEL
    if test -z "$channel"
        set channel default
    end
    set -l urgency normal
    set -l message_parts

    # Parse arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --channel -c
                set i (math $i + 1)
                set channel $argv[$i]
            case --urgency -u
                set i (math $i + 1)
                set urgency $argv[$i]
            case --help -h
                echo "Usage: openclaw-notify [--channel <ch>] [--urgency low|normal|high] <message>"
                echo ""
                echo "Options:"
                echo "  --channel, -c  Channel to send to (default: \$OPENCLAW_NOTIFY_CHANNEL or 'default')"
                echo "  --urgency, -u  Message urgency: low, normal, high (default: normal)"
                echo ""
                echo "Environment:"
                echo "  OPENCLAW_NOTIFY_STRICT=1  Fail on notification errors"
                return 0
            case '*'
                set -a message_parts $argv[$i]
        end
        set i (math $i + 1)
    end

    set -l message (string join " " $message_parts)

    if test -z "$message"
        echo "Usage: openclaw-notify [--channel <ch>] [--urgency low|normal|high] <message>"
        return 1
    end

    # Log helper
    set -l log_file $HOME/.openclaw/notify.log
    function _oc_fish_log --no-scope
        if test -d (dirname $log_file)
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] $argv" >> $log_file 2>/dev/null
        end
    end

    # Check if openclaw is installed
    if not command -q openclaw
        _oc_fish_log "SKIP openclaw not installed: $message"
        if command -q terminal-notifier
            terminal-notifier -title "OpenClaw" -message "$message"
        end
        return 0
    end

    # Check if Gateway is running
    if not command openclaw gateway status >/dev/null 2>&1
        _oc_fish_log "SKIP gateway not running: $message"
        if command -q terminal-notifier
            terminal-notifier -title "OpenClaw (offline)" -message "$message"
        end
        return 0
    end

    # Format based on urgency
    switch $urgency
        case high
            set message "[URGENT] $message"
        case low
            set message "[info] $message"
    end

    if command openclaw message send --channel "$channel" --message "$message" 2>/dev/null
        _oc_fish_log "OK [$channel] $message"
    else
        _oc_fish_log "FAIL [$channel] $message"
        if test "$OPENCLAW_NOTIFY_STRICT" = 1
            return 1
        end
    end
end
