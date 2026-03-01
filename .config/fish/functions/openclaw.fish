function openclaw --description "OpenClaw AI assistant management"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        set subcmd help
    end

    switch $subcmd
        case start
            command openclaw gateway start
            echo "OpenClaw Gateway started"

        case stop
            command openclaw gateway stop
            echo "OpenClaw Gateway stopped"

        case restart
            command openclaw gateway restart
            echo "OpenClaw Gateway restarted"

        case status
            command openclaw gateway status

        case doctor
            command openclaw doctor

        case send
            if test (count $argv) -lt 3
                echo "Usage: claw send <channel> <message>"
                return 1
            end
            set -l channel $argv[2]
            set -l message (string join " " $argv[3..])
            command openclaw message send --channel $channel --message "$message"

        case audit
            command openclaw security audit --deep

        case logs
            command openclaw logs --follow

        case config
            if test (count $argv) -lt 3
                command openclaw config list
            else
                command openclaw config set $argv[2..]
            end

        case pair
            if test (count $argv) -lt 3
                echo "Usage: claw pair <channel> <code>"
                return 1
            end
            command openclaw pairing approve $argv[2] $argv[3]

        case agent
            set -l message (string join " " $argv[2..])
            command openclaw agent --message "$message" --thinking high

        case secrets
            if test (count $argv) -lt 2
                command openclaw secrets audit
            else
                command openclaw secrets $argv[2..]
            end

        case approvals
            if test (count $argv) -lt 2
                command openclaw approvals list
            else
                command openclaw approvals $argv[2..]
            end

        case node
            if test (count $argv) -lt 2
                command openclaw node status
            else
                command openclaw node $argv[2..]
            end

        case update
            command openclaw update $argv[2..]

        case skills
            if test (count $argv) -lt 2
                command openclaw skills list
            else
                command openclaw skills $argv[2..]
            end

        case help -h --help
            echo "OpenClaw - Self-hosted AI Assistant"
            echo ""
            echo "Usage: claw <command> [args]"
            echo ""
            echo "Commands:"
            echo "  start            Start the Gateway daemon"
            echo "  stop             Stop the Gateway daemon"
            echo "  restart          Restart the Gateway daemon"
            echo "  status           Show Gateway status"
            echo "  doctor           Run health checks"
            echo "  send <ch> <m>    Send message to channel"
            echo "  audit            Run security audit"
            echo "  logs             Follow Gateway logs"
            echo "  config [k] [v]   Get/set configuration"
            echo "  pair <ch> <c>    Approve DM pairing"
            echo "  agent <msg>      Direct agent query"
            echo "  secrets [cmd]    Manage external secrets (audit/configure/apply/reload)"
            echo "  approvals [cmd]  Manage exec approvals (list/edit)"
            echo "  node [cmd]       Manage node hosts (status/start/stop)"
            echo "  update [args]    Update OpenClaw"
            echo "  skills [cmd]     Manage agent skills (list/install)"
            echo "  help             Show this help"

        case '*'
            command openclaw $argv
    end
end
