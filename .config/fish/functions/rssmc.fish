function rssmc --description "Connect to EC2 instance via SSM with convenient workflow"
    set -l profile $argv[1]

    # Check for required tools
    if not command -v session-manager-plugin > /dev/null 2>&1
        echo "❌ AWS Session Manager Plugin is not installed"
        echo "Install it with: brew install --cask session-manager-plugin"
        return 1
    end

    # Set environment variables
    if test -n "$profile"
        set -x AWS_PROFILE $profile
    end

    # Try to get instances with current credentials first
    echo "Fetching EC2 instances..."

    # Get region early for consistency
    set -l region (aws configure get region 2>/dev/null)
    if test -z "$region"
        set region "us-east-1"
    end

    # Get all running instances with their SSM status
    set -l instances (aws ec2 describe-instances \
        --region $region \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' \
        --output text 2>/dev/null)

    # If no instances found and we have a profile, try with profile
    if test -z "$instances" -a -n "$profile"
        echo "Retrying with profile: $profile"
        set -l profile_region (aws configure get region --profile $profile 2>/dev/null)
        if test -n "$profile_region"
            set region $profile_region
        end
        set instances (aws ec2 describe-instances \
            --profile $profile \
            --region $region \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' \
            --output text 2>/dev/null)
    end

    # If still no instances and no profile specified, try default
    if test -z "$instances" -a -z "$profile"
        set profile "labs"
        echo "Trying default profile: $profile"
        set -l profile_region (aws configure get region --profile $profile 2>/dev/null)
        if test -n "$profile_region"
            set region $profile_region
        end
        set instances (aws ec2 describe-instances \
            --profile $profile \
            --region $region \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' \
            --output text 2>/dev/null)
    end

    if test -z "$instances"
        echo "No running instances found"
        echo "Tip: If using Granted, run 'assume <profile>' first"
        return 1
    end

    # Get SSM connection status for all instances
    echo "Checking SSM connectivity..."

    set -l ssm_instances
    if test -n "$profile"
        set ssm_instances (aws ssm describe-instance-information \
            --profile $profile \
            --region $region \
            --query 'InstanceInformationList[*].InstanceId' \
            --output text 2>/dev/null)
    else
        set ssm_instances (aws ssm describe-instance-information \
            --region $region \
            --query 'InstanceInformationList[*].InstanceId' \
            --output text 2>/dev/null)
    end

    # Format for fzf: "Name (InstanceType) - InstanceId [SSM Status]"
    set -l formatted_instances
    for line in $instances
        set -l parts (string split \t $line)
        set -l name $parts[1]
        set -l instance_id $parts[2]
        set -l instance_type $parts[3]
        set -l ip $parts[4]

        # Check if instance has SSM connectivity
        if string match -q "*$instance_id*" $ssm_instances
            set -l ssm_status "✅ SSM"
        else
            set -l ssm_status "❌ No SSM"
        end

        # Format: "Name (Type) - ID [Status] IP"
        set formatted_instances $formatted_instances "$name ($instance_type) - $instance_id [$ssm_status] $ip"
    end

    # Use fzf for selection
    set -l selected (printf "%s\n" $formatted_instances | fzf \
        --prompt="Select EC2 instance to connect > " \
        --height=40% \
        --layout=reverse \
        --border \
        --header="Use arrow keys to select, Enter to connect, Esc to cancel")

    if test -z "$selected"
        echo "Cancelled"
        return 1
    end

    # Extract instance ID from selection
    set -l instance_id (echo $selected | sed -n 's/.*- \(i-[a-z0-9]*\) .*/\1/p')

    if test -z "$instance_id"
        echo "Failed to extract instance ID"
        return 1
    end

    echo "🚀 Connecting to $instance_id via SSM..."

    # Build SSM command
    set -l ssm_cmd "aws ssm start-session"
    if test -n "$profile"
        set ssm_cmd "$ssm_cmd --profile $profile"
    end
    set ssm_cmd "$ssm_cmd --region $region"
    set ssm_cmd "$ssm_cmd --target $instance_id"

    echo ""
    echo "📡 Starting SSM session..."
    echo ""
    echo "💡 Tips for remote editing:"
    echo "  • For Neovim: Use distant.nvim (already configured)"
    echo "  • For quick edits: nano, vim, or vi"
    echo "  • To copy files: Use 'aws s3 cp' to transfer via S3"
    echo ""

    # Start interactive SSM session
    eval $ssm_cmd
end