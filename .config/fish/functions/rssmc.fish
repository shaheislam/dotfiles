function rssmc --description "Connect to EC2 instance via SSM + SSHFS mount for local Neovim editing"
    set -l profile $argv[1]

    # Ensure Neovim server is running
    if not pgrep -f "nvim.*--listen.*/tmp/nvim.socket" > /dev/null 2>&1
        echo "📝 Starting Neovim server..."
        nvim --listen /tmp/nvim.socket &
        sleep 1
    else
        echo "✅ Neovim server already running"
    end

    # Try to get instances with current credentials first
    echo "Fetching EC2 instances..."

    # Get all running instances with their SSM status
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

    # If still no instances and no profile specified, try default
    if test -z "$instances" -a -z "$profile"
        set profile "labs"
        echo "Trying default profile: $profile"
        set instances (aws ec2 describe-instances \
            --profile $profile \
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
    set -l ssm_instances (aws ssm describe-instance-information \
        --query 'InstanceInformationList[*].InstanceId' \
        --output text 2>/dev/null)

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
        --prompt="Select EC2 instance to mount via SSHFS > " \
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

    # Create mount directory
    set -l mount_dir "$HOME/.sshfs/ec2-$instance_id"
    mkdir -p "$mount_dir"

    # Find an available port
    set -l port 2224
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1
        set port (math $port + 1)
    end

    # Start SSM session with port forwarding in background
    echo "🔧 Setting up SSM port forward on localhost:$port..."
    aws ssm start-session \
        --target $instance_id \
        --document-name AWS-StartPortForwardingSession \
        --parameters "portNumber=22,localPortNumber=$port" &

    set -l ssm_pid $last_pid

    # Wait for port to be ready
    echo "⏳ Waiting for tunnel..."
    for i in (seq 1 30)
        if nc -z localhost $port 2>/dev/null
            echo "✅ Tunnel established!"
            break
        end
        sleep 1
    end

    # Mount via SSHFS
    echo "📂 Mounting filesystem via SSHFS..."
    /usr/local/bin/sshfs -p $port \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o reconnect \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        ec2-user@localhost:/ "$mount_dir" 2>/dev/null

    set -l mount_status $status

    if test $mount_status -eq 0
        echo "✅ Mounted at: $mount_dir"

        # Change Neovim working directory to mount point
        nvim --server /tmp/nvim.socket --remote-send ":cd $mount_dir<CR>" 2>/dev/null

        echo ""
        echo "🎉 Ready to edit! Use these commands:"
        echo "  rnvim <file>  or  rn <file>         # Open file in Neovim"
        echo "  cd $mount_dir                        # Browse files locally"
        echo ""
        echo "To disconnect: Ctrl+C here or unmount with:"
        echo "  umount $mount_dir"
        echo ""
        echo "📡 Session active. Press Ctrl+C to disconnect..."

        # Keep the session alive
        wait $ssm_pid
    else
        echo "❌ Failed to mount filesystem"
        kill $ssm_pid 2>/dev/null
        return 1
    end

    # Cleanup on exit
    echo "🧹 Cleaning up..."
    umount "$mount_dir" 2>/dev/null || fusermount -u "$mount_dir" 2>/dev/null
    rmdir "$mount_dir" 2>/dev/null
end