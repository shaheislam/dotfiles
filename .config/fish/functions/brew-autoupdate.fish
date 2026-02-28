function brew-autoupdate --description "Manage Homebrew background auto-updates (via brew autoupdate)"
    set -l subcmd $argv[1]

    switch "$subcmd"
        case start
            # Start background auto-updates: every 24h, with upgrade + cleanup
            brew autoupdate start --upgrade --cleanup --immediate
            echo "Homebrew auto-update started (every 24h with upgrade + cleanup)"
        case stop
            brew autoupdate stop
            echo "Homebrew auto-update stopped"
        case status
            brew autoupdate status
        case delete
            brew autoupdate delete
            echo "Homebrew auto-update LaunchAgent removed"
        case ''
            brew autoupdate status
        case '*'
            echo "Usage: brew-autoupdate [start|stop|status|delete]"
            echo ""
            echo "  start   - Start background auto-updates (24h interval, upgrade + cleanup)"
            echo "  stop    - Stop background auto-updates"
            echo "  status  - Show current auto-update status"
            echo "  delete  - Remove the LaunchAgent entirely"
            return 1
    end
end
