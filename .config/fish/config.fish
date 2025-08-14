# Fish Shell Configuration
# Integrated configuration combining dotfiles setup with extended functionality

# Helper functions for completions (available in all sessions)
function __fish_complete_aws_s3_buckets
    if test -n "$AWS_PROFILE"
        aws s3 ls 2>/dev/null | awk '{print $3}' | head -20
    end
end

function __fish_complete_aws_profiles
    aws configure list-profiles 2>/dev/null
end

# Completions for AWS functions with descriptions
complete -c ct-view -e
complete -c ct-view -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and analyze AWS CloudTrail logs in S3 buckets"

complete -c gd-view -e  
complete -c gd-view -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and analyze AWS GuardDuty security findings in S3"

complete -c s3-logs -e
complete -c s3-logs -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and format JSON logs from S3 buckets using s3grep"

complete -c s3-dates -e
complete -c s3-dates -f -a "(__fish_complete_aws_s3_buckets)" -d "List available dates in S3 log buckets with filtering"

complete -c s3-browse -e
complete -c s3-browse -f -a "(__fish_complete_aws_s3_buckets)" -d "Interactive browser for exploring S3 log buckets"

complete -c logs -e
complete -c logs -f -a "AssumeRole CreateBucket RunInstances UnauthorizedAccess root" -d "Quick AWS log search with auto-detection of common buckets"

complete -c ssmc -e
complete -c ssmc -f -a "(__fish_complete_aws_profiles)" -d "Connect to EC2 instances via AWS SSM with interactive selection"

complete -c aws-sso -e
complete -c aws-sso -f -a "(__fish_complete_aws_profiles)" -d "Authenticate with AWS SSO and export credentials to environment"


# Only run in interactive sessions
if status is-interactive
    # Set key bindings for better autocomplete
    set -g fish_key_bindings fish_vi_key_bindings
    set -g fish_escape_delay_ms 100

    # Environment Variables
    set -x BAT_THEME tokyonight_night
    set -x STARSHIP_CONFIG $HOME/.config/starship.toml
    # set -x TERM screen-256color  # Disabled to prevent VS Code integration issues

    # Additional environment variables from extended config
    set -x PYTHONPATH /opt/homebrew/lib/python3.12/site-packages

    # Path configuration - combining both configs
    fish_add_path /opt/homebrew/bin
    fish_add_path $HOME/bin
    fish_add_path $HOME/.local/bin
    fish_add_path /usr/local/bin
    fish_add_path $HOME/Library/Python/3.9/bin
    fish_add_path $HOME/.cargo/bin
    fish_add_path $HOME/.rd/bin
    fish_add_path $HOME/.bun/bin

    # Add VSCode bin to PATH if it exists
    if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
        fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    end

    # Initialize tools
    if command -v starship >/dev/null
        starship init fish | source
    end

    if command -v zoxide >/dev/null
        zoxide init fish | source
    end

    if command -v direnv >/dev/null
        direnv hook fish | source
        set -g direnv_fish_mode eval_on_arrow
    end

    if command -v atuin >/dev/null
        set -gx ATUIN_NOBIND "true"
        atuin init fish | source
    end

    # Source asdf
    if test -f "/opt/homebrew/opt/asdf/libexec/asdf.fish"
        source /opt/homebrew/opt/asdf/libexec/asdf.fish
    end

    # Configure mise settings
    if command -v mise >/dev/null
        mise settings add idiomatic_version_file_enable_tools ruby
    end

    # FZF configuration - enhanced version combining both configs
    if command -v fzf >/dev/null
        fzf --fish | source
    end

    if test -f ~/.fzf.fish
        source ~/.fzf.fish
    end

    # Enhanced FZF configuration from extended config
    if type -q rg
        set -gx FZF_DEFAULT_COMMAND 'rg --files'
        set -gx FZF_DEFAULT_OPTS '-m --height 50% --border'
    else
        # Fallback to fd-based configuration
        set -gx FZF_DEFAULT_COMMAND "fd --hidden --strip-cwd-prefix --exclude .git"
    end

    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    set -gx FZF_ALT_C_COMMAND "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

    # FZF theme colors (keeping the nice blue/purple theme)
    set -l fg "#CBE0F0"
    set -l bg "#011628"
    set -l bg_highlight "#143652"
    set -l purple "#B388FF"
    set -l blue "#06BCE4"
    set -l cyan "#2CF9ED"

    set -gx FZF_DEFAULT_OPTS "--color=fg:$fg,bg:$bg,hl:$purple,fg+:$fg,bg+:$bg_highlight,hl+:$purple,info:$blue,prompt:$cyan,pointer:$cyan,marker:$cyan,spinner:$cyan,header:$cyan"

    # Disable fish greeting
    set -g fish_greeting ""

    # thefuck initialization
    if command -v thefuck >/dev/null
        thefuck --alias | source
    end

    # Enhanced aliases combining both configs
    alias python=python3
    alias mkdir="mkdir -p"
    alias ls="eza"
    alias la="eza -al"
    alias l="eza -hal"
    alias cat="bat"
    alias k=kubectl
    alias kubectl=kubecolor
    alias vi=nvim
    alias vim=nvim
    alias n=nvim
    alias lg=lazygit
    alias ld=lazydocker
    alias fixterm="stty sane"

    # Obsidian Aliases
    alias obs="cd '/Users/shaheislam/Library/Mobile Documents/iCloud~md~obsidian/Documents/Engineering'"
    alias obsplb="cd '/Users/shahe/Documents/Local Vault'"

    # Kubernetes aliases
    alias kctx="kubie ctx"
    alias kns="kubie ns"

    # GitHub Gist aliases
    alias gispub="gis"
    alias gispriv="gh gist create"
    alias gisls="gh gist list"
    alias gisdel="gh gist delete"

    # Utility aliases
    alias wea="curl --silent wttr.in/Didsbury_uk | grep -v Follow"
    alias save="~/sesh.sh save"
    alias rest="~/sesh.sh restore"
    alias tr="clear; tmux new -A -s main"
    alias ts="tmux run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh'"
    alias tk="tmux kill-server"

    # Security aliases
    alias vetf="vet --force"  # Force execution (use with caution)

    # Git worktree aliases
    alias gwta="git worktree add"
    alias gwtab="git worktree add -b"
    # alias gwtl="git worktree list"  # Replaced with fzf function below
    # alias gwtr="git worktree remove"  # Replaced with fzf function below
    alias gwtp="git worktree prune"
    alias gwtm="git worktree move"

    # Functions from extended config
    function gis
        if test -n "$argv[1]"
            gh gist create -p $argv[1] | grep https | tee >(pbcopy)
        else
            gisls
        end
    end

        function ssmc --description "Connect to EC2 instances via AWS SSM with interactive selection"
        set -l profile $argv[1]
        if test -z "$profile"
            set profile "petlab"  # Default profile
        end

        echo "Fetching instances from AWS..."

        # Get instances with their names and IDs, only running instances
        set -l instances (aws ec2 describe-instances \
            --profile $profile \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,LaunchTime]' \
            --output text 2>/dev/null)

        if test -z "$instances"
            echo "No running instances found or AWS CLI error"
            return 1
        end

        # Format for fzf: "Name (InstanceType) - InstanceId"
        set -l formatted_instances
        for line in $instances
            set -l parts (string split \t $line)
            set -l name $parts[1]
            set -l instance_id $parts[2]
            set -l instance_type $parts[3]
            set -l launch_time $parts[4]

            # Handle instances without Name tag
            if test "$name" = "None" -o -z "$name"
                set name "Unnamed"
            end

            set -a formatted_instances "$name ($instance_type) - $instance_id"
        end

        # Use fzf to select instance
        set -l selection (printf '%s\n' $formatted_instances | fzf --prompt="Select EC2 instance: " --height=40% --border)

        if test -n "$selection"
            # Extract instance ID from selection (everything after the last " - ")
            set -l instance_id (string match -r -- '- (i-[a-f0-9]+)$' $selection | tail -1)

            if test -n "$instance_id"
                echo "Connecting to instance: $instance_id with profile: $profile"
                aws ssm start-session --target $instance_id --profile $profile
            else
                echo "Failed to extract instance ID from selection"
                return 1
            end
        else
            echo "No instance selected"
            return 1
        end
    end

    function f
        vim (fzf)
    end

    function gx
        git branch --list | grep -v "^[ *]*main\$" | xargs git branch -d
    end

    function e
        ls -hal | nms -as
    end

    function tb
        nc termbin.com 9999 | pbcopy
    end

    # AWS SSO function (enhanced version)
    function aws-sso --description "Authenticate with AWS SSO and export credentials to environment"
        set -l profile $argv[1]
        if test -z "$profile"
            set profile "petlab"
        end

        aws sso login --profile "$profile"
        eval (aws configure export-credentials --profile "$profile" --format env)
        set -gx AWS_DEFAULT_PROFILE "$profile"
        set -gx AWS_PROFILE "$profile"

        if not aws sts get-caller-identity >/dev/null 2>&1
            echo "Failed to get credentials"
        end
    end

    # Granted AWS credential management function for Fish shell
    # Properly handles environment variable propagation from bash to Fish
    function assume --description "Assume AWS role using Granted"
        # Handle console flag for Firefox containers
        if test "$argv[1]" = "-c"
            set -l profile $argv[2]
            if test -n "$profile"
                # First assume the profile using bash with suppressed interactive prompts
                set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $profile >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
                for line in $env_vars
                    set -l parts (string split -m 1 "=" $line)
                    if test (count $parts) -eq 2
                        set -gx $parts[1] $parts[2]
                    end
                end
                
                # Then open console with profile-specific container names and colors
                switch $profile
                    case labs
                        granted console --firefox --color green --icon tree --container-name labs
                    case logging
                        granted console --firefox --color purple --icon circle --container-name logging
                    case security
                        granted console --firefox --color purple --icon fingerprint --container-name security
                    case management
                        granted console --firefox --color blue --icon briefcase --container-name management
                    case petlab
                        granted console --firefox --color pink --icon pet --container-name petlab
                    case prod
                        granted console --firefox --color red --icon briefcase --container-name prod
                    case '*'
                        granted console --firefox --container-name $profile
                end
                return
            end
        end
        
        # If no arguments provided, use interactive selection
        if test (count $argv) -eq 0
            # Get available profiles and use fzf for selection
            set -l profiles (aws configure list-profiles 2>/dev/null)
            if test (count $profiles) -eq 0
                echo "No AWS profiles found"
                return 1
            end
            
            # Use fzf for interactive selection
            set -l selected_profile (printf '%s\n' $profiles | fzf --prompt="Select AWS profile: " --height=40% --border)
            
            if test -n "$selected_profile"
                # Assume the selected profile
                set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $selected_profile >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
                for line in $env_vars
                    set -l parts (string split -m 1 "=" $line)
                    if test (count $parts) -eq 2
                        set -gx $parts[1] $parts[2]
                    end
                end
            else
                echo "No profile selected"
            end
            return
        end
        
        # Regular assume functionality with specific profile
        # Execute assume command in bash and capture AWS environment variables
        set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $argv >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
        
        # Parse and set each environment variable in the current Fish session
        for line in $env_vars
            set -l parts (string split -m 1 "=" $line)
            if test (count $parts) -eq 2
                set -gx $parts[1] $parts[2]
            end
        end
        
    end
    
    # Enable Granted completions for Fish shell
    if command -v granted &> /dev/null
        # Generate granted completions if not already installed
        if not test -f "$HOME/.config/fish/completions/granted.fish"
            granted completion --shell fish 2>/dev/null
        end
        # The completions will be auto-loaded by Fish from the completions directory
    end

    
    # Show current AWS account
    function aws-whoami --description "Show current AWS account and identity"
        if test -n "$AWS_PROFILE"
            echo "Current profile: $AWS_PROFILE"
            aws sts get-caller-identity --output table
        else
            echo "No AWS profile currently set"
        end
    end
    
    
    # S3grep wrapper to ensure AWS profile is used
    function s3grep
        if test -z "$AWS_PROFILE"
            echo "No AWS profile set. Run 'aws-sso <profile>' first."
            return 1
        end
        command s3grep $argv
    end

    # AWS Log Analysis Functions (Generic)
    
    # Pretty print s3grep output for JSON logs
    function s3-logs --description "Search and format JSON logs from S3 buckets using s3grep"
        set -l bucket $argv[1]
        set -l pattern $argv[2]
        set -l prefix $argv[3]
        
        if test -z "$bucket" -o -z "$pattern"
            echo "Usage: s3-logs <bucket> <pattern> [prefix]"
            echo "Example: s3-logs my-log-bucket '\"eventName\":\"AssumeRole\"' logs/2024/01/"
            return 1
        end
        
        set -l grep_args --bucket $bucket --pattern "$pattern"
        test -n "$prefix"; and set grep_args $grep_args --prefix "$prefix"
        
        s3grep $grep_args 2>/dev/null | while read -l line
            # Split on .gz: to properly separate filepath from JSON
            set -l parts (string split -m 1 ".gz:" $line)
            if test (count $parts) -eq 2
                set -l filepath $parts[1].gz
                set -l json $parts[2]
                set -l filename (basename $filepath)
                
                echo "📄 File: $filename"
                echo $json | jq '.' 2>/dev/null || begin
                    echo "Raw content (jq failed):"
                    echo $json | head -c 500
                    echo "..."
                end
                echo "═══════════════════════════════════════════════════════════════"
            else
                echo "Unparsed line: $line"
            end
        end
    end

    # Generic GuardDuty log viewer with custom bucket
    function gd-view --description "Search and analyze AWS GuardDuty security findings in S3"
        set -l bucket $argv[1]
        set -l pattern $argv[2]
        set -l prefix $argv[3]
        
        if test -z "$bucket"
            echo "Usage: gd-view <bucket> [pattern] [prefix]"
            echo "Example: gd-view my-guardduty-bucket '\"severity\":[5-9]' AWSLogs/123456/GuardDuty/"
            return 1
        end
        
        test -z "$pattern"; and set pattern '"severity":'
        
        s3-logs $bucket "$pattern" "$prefix" | while read -l line
            if string match -q "📄 File:*" "$line"
                echo $line
            else if string match -q "═*" "$line"
                echo $line
            else
                # Try to parse as GuardDuty finding
                echo $line | jq -r 'select(.type != null) | 
                    "🔍 \(.type)
                    📊 Severity: \(.severity) | \(.title // "No title")
                    👤 Resource: \(.resource.resourceType // "Unknown")
                    🌍 Region: \(.region // "Unknown")
                    🕐 Time: \(.createdAt // .updatedAt // "Unknown")
                    📝 \(.description // "No description")"' 2>/dev/null || echo $line
            end
        end
    end

    # Generic CloudTrail log viewer
    function ct-view --description "Search and analyze AWS CloudTrail logs in S3 buckets"
        set -l bucket $argv[1]
        set -l pattern $argv[2]
        set -l prefix $argv[3]
        
        if test -z "$bucket"
            echo "Usage: ct-view <bucket> [pattern] [prefix]"
            echo "Example: ct-view my-cloudtrail-bucket AssumeRole AWSLogs/"
            return 1
        end
        
        test -z "$pattern"; and set pattern "."
        
        set -l grep_args --bucket $bucket --pattern "$pattern"
        test -n "$prefix"; and set grep_args $grep_args --prefix "$prefix"
        
        s3grep $grep_args 2>/dev/null | while read -l line
            # Split on first colon after s3://
            set -l parts (string split -m 1 ".gz:" $line)
            if test (count $parts) -eq 2
                set -l filepath $parts[1].gz
                set -l json $parts[2]
                set -l filename (basename $filepath)
                
                echo "📄 File: $filename"
                echo $json | jq -r '
                    if .Records then 
                        .Records[] | "🔐 \(.eventName // "Unknown") | \(.eventSource // "Unknown")
👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")
🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")  
🕐 Time: \(.eventTime // "Unknown")
───────────────────────────────────────────────────────────────"
                    else 
                        "🔐 Event: \(.eventName // "Unknown") | Source: \(.eventSource // "Unknown")
👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")  
🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")
🕐 Time: \(.eventTime // "Unknown")
───────────────────────────────────────────────────────────────"
                    end' 2>/dev/null || begin
                        echo "Raw JSON (jq failed):"
                        echo $json | head -c 500
                        echo "..."
                    end
                echo ""
            else
                echo $line
            end
        end
    end

    # List S3 bucket contents with date filtering
    function s3-dates --description "List available dates in S3 log buckets with filtering"
        set -l bucket $argv[1]
        set -l prefix $argv[2]
        set -l days $argv[3]
        
        if test -z "$bucket"
            echo "Usage: s3-dates <bucket> [prefix] [days-to-show]"
            echo "Example: s3-dates my-log-bucket AWSLogs/ 10"
            return 1
        end
        
        test -z "$days"; and set days 20
        
        echo "📅 Available dates in s3://$bucket/$prefix:"
        aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null \
            | grep -E '20[0-9]{2}/[0-9]{2}/[0-9]{2}/' \
            | awk '{print $4}' \
            | grep -oE '20[0-9]{2}/[0-9]{2}/[0-9]{2}' \
            | sort | uniq | tail -$days
    end

    # Interactive S3 log browser
    function s3-browse --description "Interactive browser for exploring S3 log buckets"
        set -l bucket $argv[1]
        
        if test -z "$bucket"
            echo "Usage: s3-browse <bucket>"
            echo ""
            echo "Your configured log buckets:"
            aws s3 ls 2>/dev/null | grep -E "(log|trail|guard)" | awk '{print "  - " $3}'
            return 1
        end
        
        echo "S3 Log Browser: $bucket"
        echo "======================"
        
        # List top-level prefixes
        echo "Available prefixes:"
        aws s3 ls s3://$bucket/ 2>/dev/null | grep PRE | awk '{print "  - " $2}'
        
        echo ""
        read -P "Enter prefix to explore (or 'q' to quit): " prefix
        test "$prefix" = "q"; and return 0
        
        # Show recent files
        echo ""
        echo "Recent files in $prefix:"
        aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null | tail -10 | awk '{print $4}'
        
        echo ""
        read -P "Enter search pattern (or press enter to skip): " pattern
        test -z "$pattern"; and set pattern "."
        
        echo ""
        echo "Searching..."
        s3-logs $bucket "$pattern" "$prefix" | head -50
    end

    # Quick log analysis with auto-detection
    function logs --description "Quick AWS log search with auto-detection of common buckets"
        set -l pattern $argv[1]
        set -l bucket $argv[2]
        
        if test -z "$pattern"
            echo "Usage: logs <pattern> [bucket]"
            echo "Examples:"
            echo "  logs AssumeRole                    # Search in default buckets"
            echo "  logs '\"severity\":[5-9]' my-bucket  # Search specific bucket"
            echo ""
            echo "Common patterns:"
            echo "  AssumeRole           - Role assumptions"
            echo "  CreateBucket         - Bucket creation events"
            echo "  UnauthorizedAccess   - GuardDuty unauthorized access"
            echo "  '\"severity\":[5-9]'  - GuardDuty medium+ severity"
            echo "  root                 - Root account usage"
            return 1
        end
        
        if test -n "$bucket"
            # Search specific bucket
            s3-logs $bucket "$pattern"
        else
            # Search common log buckets
            echo "Searching common log buckets..."
            
            # Try CloudTrail bucket
            if aws s3 ls s3://petlab-centralize-logging/ >/dev/null 2>&1
                echo "🔍 Searching CloudTrail logs..."
                s3-logs petlab-centralize-logging "$pattern" "AWSLogs/" | head -10
            end
            
            # Try GuardDuty bucket
            if aws s3 ls s3://petlab-guardduty-logging/ >/dev/null 2>&1
                echo "🔍 Searching GuardDuty logs..."
                s3-logs petlab-guardduty-logging "$pattern" "AWSLogs/" | head -10
            end
        end
    end


    # Set environment variables
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx LANG en_US.UTF-8
    set -gx LC_ALL en_US.UTF-8
    # Let terminal/VS Code set TERM appropriately
    # set -gx TERM xterm-256color

    # Configure tmux.fish
    status is-interactive; and begin
        set fish_tmux_autostart true
        set fish_tmux_autoconnect true
        set fish_tmux_autoname_session true
    end

    # Tmux function with correct TERM
    function tmux
        env TERM=xterm-256color /opt/homebrew/bin/tmux $argv
    end

    # Git worktree functions
    function gwtaf --description "Add worktree for existing branch in ../repo-branch format"
        # Add worktree in ../repo-name-branch format
        if test -z "$argv[1]"
            echo "Usage: gwtaf <existing-branch>"
            return 1
        end
        set branch $argv[1]
        set repo (basename (git rev-parse --show-toplevel))
        git worktree add ../$repo-$branch $branch
    end

    function gwtabf --description "Create new branch + worktree in ../repo-branch format"
        # Create branch + worktree in ../repo-name-branch format
        if test -z "$argv[1]"
            echo "Usage: gwtabf <new-branch>"
            return 1
        end
        set branch $argv[1]
        set repo (basename (git rev-parse --show-toplevel))
        git worktree add -b $branch ../$repo-$branch
    end

    # Enhanced git worktree functions with fzf
    function gwtl --description "List git worktrees or switch to one with fzf"
        # Check if we're in a git repository
        if not git rev-parse --git-dir >/dev/null 2>&1
            echo "Not in a git repository"
            return 1
        end
        
        set -l worktrees (git worktree list 2>/dev/null)
        
        if test -z "$worktrees"
            echo "No git worktrees found"
            return 1
        end
        
        # If stdout is a terminal, use fzf for selection
        if isatty stdout
            set -l selected (printf '%s\n' $worktrees | fzf --height=40% --reverse --prompt="Switch to worktree: " | awk '{print $1}')
            if test -n "$selected"
                cd "$selected"
                echo "Switched to: $selected"
            end
        else
            # Non-interactive mode, just list
            printf '%s\n' $worktrees
        end
    end

    function gwtr --description "Remove git worktree with fzf selection"
        # Check if we're in a git repository
        if not git rev-parse --git-dir >/dev/null 2>&1
            echo "Not in a git repository"
            return 1
        end
        
        set -l worktrees (git worktree list 2>/dev/null | grep -v '(bare)')
        
        if test -z "$worktrees"
            echo "No git worktrees to remove"
            return 1
        end
        
        set -l selected (printf '%s\n' $worktrees | fzf --height=40% --reverse --prompt="Remove worktree: " | awk '{print $1}')
        
        if test -n "$selected"
            echo "Removing worktree: $selected"
            git worktree remove "$selected"
        end
    end

    # Custom Atuin wrapper functions for different filter modes
    function _atuin_search_directory --description "Atuin search with directory filter"
        set -l keymap_mode
        switch $fish_key_bindings
            case fish_vi_key_bindings
                switch $fish_bind_mode
                    case default
                        set keymap_mode vim-normal
                    case insert
                        set keymap_mode vim-insert
                end
            case '*'
                set keymap_mode emacs
        end

        set -l ATUIN_H (ATUIN_SHELL_FISH=t ATUIN_LOG=error ATUIN_QUERY=(commandline -b) atuin search --keymap-mode=$keymap_mode --filter-mode=directory -i 3>&1 1>&2 2>&3 | string collect)

        if test -n "$ATUIN_H"
            if string match --quiet '__atuin_accept__:*' "$ATUIN_H"
                set -l ATUIN_HIST (string replace "__atuin_accept__:" "" -- "$ATUIN_H" | string collect)
                commandline -r "$ATUIN_HIST"
                commandline -f repaint
                commandline -f execute
                return
            else
                commandline -r "$ATUIN_H"
            end
        end

        commandline -f repaint
    end

    function _atuin_search_session --description "Atuin search with session filter"
        set -l keymap_mode
        switch $fish_key_bindings
            case fish_vi_key_bindings
                switch $fish_bind_mode
                    case default
                        set keymap_mode vim-normal
                    case insert
                        set keymap_mode vim-insert
                end
            case '*'
                set keymap_mode emacs
        end

        set -l ATUIN_H (ATUIN_SHELL_FISH=t ATUIN_LOG=error ATUIN_QUERY=(commandline -b) atuin search --keymap-mode=$keymap_mode --filter-mode=session -i 3>&1 1>&2 2>&3 | string collect)

        if test -n "$ATUIN_H"
            if string match --quiet '__atuin_accept__:*' "$ATUIN_H"
                set -l ATUIN_HIST (string replace "__atuin_accept__:" "" -- "$ATUIN_H" | string collect)
                commandline -r "$ATUIN_HIST"
                commandline -f repaint
                commandline -f execute
                return
            else
                commandline -r "$ATUIN_H"
            end
        end

        commandline -f repaint
    end

    function _atuin_search_global --description "Atuin search with global filter"
        set -l keymap_mode
        switch $fish_key_bindings
            case fish_vi_key_bindings
                switch $fish_bind_mode
                    case default
                        set keymap_mode vim-normal
                    case insert
                        set keymap_mode vim-insert
                end
            case '*'
                set keymap_mode emacs
        end

        set -l ATUIN_H (ATUIN_SHELL_FISH=t ATUIN_LOG=error ATUIN_QUERY=(commandline -b) atuin search --keymap-mode=$keymap_mode --filter-mode=global -i 3>&1 1>&2 2>&3 | string collect)

        if test -n "$ATUIN_H"
            if string match --quiet '__atuin_accept__:*' "$ATUIN_H"
                set -l ATUIN_HIST (string replace "__atuin_accept__:" "" -- "$ATUIN_H" | string collect)
                commandline -r "$ATUIN_HIST"
                commandline -f repaint
                commandline -f execute
                return
            else
                commandline -r "$ATUIN_H"
            end
        end

        commandline -f repaint
    end

    # Custom Atuin keybindings for different filter modes
    # Up arrow - directory search (default behavior)
    bind \e\[A _atuin_search_directory
    bind -M insert \e\[A _atuin_search_directory
end

# Note: Additional git+fzf functionality is provided in conf.d/plugins.fish

# FZF-Atuin integration - Custom history search
if status is-interactive
    # Override the default Ctrl-R binding from plugins.fish
    bind \cr atuin_fzf_search
    bind -M insert \cr atuin_fzf_search
end


