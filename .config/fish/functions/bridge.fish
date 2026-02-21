function bridge --description "Toggle cross-provider bridge on/off mid-session"
    set -l pause_file "$HOME/.claude/bridge-paused"

    switch "$argv[1]"
        case off pause disable
            touch "$pause_file"
            echo "Bridge paused (file: $pause_file)"
            echo "The bridge hook will skip on next Stop event."
            echo "Run 'bridge on' to re-enable."
        case on resume enable
            if test -f "$pause_file"
                rm -f "$pause_file"
                echo "Bridge resumed."
            else
                echo "Bridge is already active (no pause file)."
            end
        case status ''
            if test -f "$pause_file"
                echo "Bridge: PAUSED (pause file exists: $pause_file)"
            else if test -n "$CROSS_PROVIDER_BRIDGE" -a "$CROSS_PROVIDER_BRIDGE" = 1
                echo "Bridge: ACTIVE"
                if test -n "$CROSS_PROVIDER_ORDER"
                    echo "  Providers: $CROSS_PROVIDER_ORDER"
                end
                if test -n "$CROSS_PROVIDER_MODE"
                    echo "  Mode: $CROSS_PROVIDER_MODE"
                end
                if test -n "$CROSS_PROVIDER_MAX_ITERATIONS"
                    echo "  Max iterations: $CROSS_PROVIDER_MAX_ITERATIONS"
                end
                if test -n "$CROSS_PROVIDER_MODELS"
                    echo "  Models: $CROSS_PROVIDER_MODELS"
                end
            else
                echo "Bridge: DISABLED (CROSS_PROVIDER_BRIDGE not set)"
            end
        case help -h --help
            echo "Usage: bridge [on|off|status]"
            echo ""
            echo "Toggle the cross-provider reasoning bridge mid-session."
            echo "Works by creating/removing ~/.claude/bridge-paused."
            echo ""
            echo "Commands:"
            echo "  off, pause, disable   Pause the bridge (creates pause file)"
            echo "  on, resume, enable    Resume the bridge (removes pause file)"
            echo "  status                Show bridge state (default)"
            echo ""
            echo "From within Claude Code, you can also run:"
            echo "  touch ~/.claude/bridge-paused   # pause"
            echo "  rm ~/.claude/bridge-paused       # resume"
        case '*'
            echo "Unknown command: $argv[1]"
            echo "Usage: bridge [on|off|status|help]"
            return 1
    end
end
