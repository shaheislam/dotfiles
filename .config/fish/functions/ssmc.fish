function ssmc --description "Connect to EC2 instances via AWS SSM with interactive selection"
    set -l profile $argv[1]

    # Try to get instances with current credentials first
    echo "Fetching EC2 instances..."

    # Get all running instances with their Name tags
    set -l instances (aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' \
        --output text 2>/dev/null)

    # If no instances found and we have a profile, try with profile
    if test -z "$instances" -a -n "$profile"
        echo "Retrying with profile: $profile"
        set instances (aws ec2 describe-instances \
            --profile $profile \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' \
            --output text 2>/dev/null)
    end

    if test -z "$instances"
        echo "No running instances found"
        return 1
    end

    # Get SSM connectivity status
    echo "Checking SSM connectivity..."
    set -l ssm_instances (aws ssm describe-instance-information --query 'InstanceInformationList[*].InstanceId' --output text 2>/dev/null)

    # Format instances for fzf
    set -l formatted_instances
    echo "$instances" | while read -l line
        set -l parts (string split \t $line)
        set -l name $parts[1]
        set -l instance_id $parts[2]
        set -l instance_type $parts[3]
        set -l ip_address $parts[4]

        # Handle instances without Name tag
        if test "$name" = None -o -z "$name"
            set name Unnamed
        end

        # Check if instance has SSM connectivity
        set -l ssm_status "SSM Offline"
        if string match -q "*$instance_id*" $ssm_instances
            set ssm_status "SSM Ready"
        end

        set -a formatted_instances "$name ($instance_type) [$ip_address] - $instance_id $ssm_status"
    end

    # Use fzf to select instance
    set -l selection (printf '%s\n' $formatted_instances | fzf --prompt="Select EC2 instance: " --height=40% --border)

    if test -n "$selection"
        # Extract instance ID from selection
        set -l instance_id (string match -r -- '- (i-[a-f0-9]+)' $selection | tail -1 | string replace -- '- ' '')

        if test -n "$instance_id"
            # Check if instance has SSM connectivity
            if not string match -q "*$instance_id*" $ssm_instances
                echo "Warning: Instance $instance_id does not have SSM connectivity"
                echo "The SSM agent may not be installed or running on this instance"
                read -P "Try to connect anyway? (y/N): " -n 1 confirm
                if test "$confirm" != y -a "$confirm" != Y
                    return 1
                end
            end

            echo "Connecting to instance: $instance_id"
            # Try without profile first (uses environment credentials if available)
            aws ssm start-session --target $instance_id

            # If that fails and we have a profile, try with profile
            if test $status -ne 0 -a -n "$profile"
                echo "Retrying with profile: $profile"
                aws ssm start-session --target $instance_id --profile $profile
            end
        else
            echo "Failed to extract instance ID from selection"
            return 1
        end
    else
        echo "No instance selected"
        return 1
    end
end
