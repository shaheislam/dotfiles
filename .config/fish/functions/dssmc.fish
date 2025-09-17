function dssmc --description "Connect to EC2 instance via SSM tunnel for distant.nvim"
    # Parse arguments
    set -l instance_id ""
    set -l profile "labs"
    set -l port ""
    set -l skip_next false

    # Parse named arguments only if there are arguments
    if test (count $argv) -gt 0
        for i in (seq 1 (count $argv))
            # Skip if this was a value for a previous flag
            if test "$skip_next" = true
                set skip_next false
                continue
            end

            switch $argv[$i]
            case --profile -p
                if test (math "$i + 1") -le (count $argv)
                    set profile $argv[(math "$i + 1")]
                    set skip_next true
                end
            case --port
                if test (math "$i + 1") -le (count $argv)
                    set port $argv[(math "$i + 1")]
                    set skip_next true
                end
            case --help -h
                echo "Usage: dssmc [instance-id] [options]"
                echo ""
                echo "Connect to EC2 instance via SSM tunnel for distant.nvim"
                echo ""
                echo "Options:"
                echo "  --profile, -p <profile>  AWS profile to use (default: labs)"
                echo "  --port <port>           Local port for tunnel (default: 2222)"
                echo "  --help, -h              Show this help message"
                echo ""
                echo "Examples:"
                echo "  dssmc                   # Interactive instance selection"
                echo "  dssmc i-1234567890abc   # Connect to specific instance"
                echo "  dssmc --profile dev     # Use 'dev' AWS profile"
                echo "  dssmc --port 2223       # Use port 2223 for tunnel"
                return 0
            case '*'
                # If it's not a flag, treat as instance ID
                if not string match -q -- '--*' $argv[$i]; and not string match -q -- '-*' $argv[$i]
                    if test -z "$instance_id"
                        set instance_id $argv[$i]
                    end
                end
        end
    end
    end

    # Set port environment variable if provided
    if test -n "$port"
        set -x DISTANT_LOCAL_PORT $port
    end

    # Build and execute the command
    if test -n "$instance_id"
        # If instance ID provided, pass both instance ID and profile
        $HOME/dotfiles/scripts/aws/distant-ssm-tunnel.sh $instance_id $profile
    else
        # If no instance ID, only pass profile (script will do interactive selection)
        $HOME/dotfiles/scripts/aws/distant-ssm-tunnel.sh "" $profile
    end
end