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

    # API Keys for Claude Code Router
    # Load from ~/dotfiles/.env if it exists (after stow symlink)
    if test -f ~/.env
        for line in (cat ~/.env | grep -v '^#' | grep -v '^$')
            set pair (string split -m 1 '=' $line)
            set key (string replace 'export ' '' $pair[1])
            set value (string trim -c '"' $pair[2])
            set -gx $key $value
        end
    end

    # Path configuration - combining both configs
    fish_add_path /opt/homebrew/bin
    fish_add_path $HOME/bin
    fish_add_path $HOME/.local/bin
    fish_add_path /usr/local/bin
    fish_add_path $HOME/Library/Python/3.9/bin
    fish_add_path $HOME/.cargo/bin
    fish_add_path $HOME/.rd/bin
    fish_add_path $HOME/.bun/bin
    fish_add_path $HOME/dotfiles/scripts/bin

    # Add VSCode bin to PATH if it exists
    if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
        fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    end

    # Add Cursor bin to PATH if it exists
    if test -d "/Applications/Cursor.app/Contents/Resources/app/bin"
        fish_add_path "/Applications/Cursor.app/Contents/Resources/app/bin"
    end

    # Initialize tools
    if command -v starship >/dev/null
        starship init fish | source
        # Enable transient prompt for cleaner terminal history
        enable_transience
    end

    if command -v zoxide >/dev/null
        # Disable zoxide doctor warnings
        set -x _ZO_DOCTOR 0
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

    # FZF theme colors - Tokyo Night theme to match tmux and other tools
    set -l fg "#c0caf5"          # Foreground
    set -l bg "#1a1b26"          # Background
    set -l bg_highlight "#283457" # Current Line/Selection
    set -l purple "#9d7cd8"       # Purple
    set -l blue "#7aa2f7"         # Blue
    set -l cyan "#7dcfff"         # Cyan
    set -l green "#9ece6a"        # Green
    set -l orange "#ff9e64"       # Orange
    set -l red "#f7768e"          # Red
    set -l yellow "#e0af68"       # Yellow
    set -l magenta "#bb9af7"      # Magenta

    set -gx FZF_DEFAULT_OPTS "--color=fg:$fg,bg:$bg,hl:$blue,fg+:$fg,bg+:$bg_highlight,hl+:$magenta,info:$yellow,prompt:$cyan,pointer:$blue,marker:$green,spinner:$cyan,header:$purple"

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
    alias k=kubectl
    alias vi=nvim
    alias vim=nvim
    alias tmp="tmpmail --generate"  # Quick temp email generation
    alias tmpm="tmpmail"  # Check temp mailbox
    alias altair="open -a 'Altair GraphQL Client'"  # Open Altair GraphQL Client

    # Yazi shell wrapper for directory navigation
    function yy --description "Navigate with yazi and change directory on exit"
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # Splash log colorizer integration
    # Automatically pipe common log-producing commands through splash
    if command -v splash >/dev/null
        # Docker commands
        function docker --description "Docker with colored logs"
            if test "$argv[1]" = "logs"
                command docker $argv | splash
            else if test "$argv[1]" = "compose"; and test "$argv[2]" = "logs"
                command docker $argv | splash
            else
                command docker $argv
            end
        end

        # Kubectl commands with kubecolor and splash
        function kubectl --description "Kubectl with kubecolor and colored logs"
            if test "$argv[1]" = "logs"
                # Use regular kubectl for logs and pipe through splash
                command kubectl $argv | splash
            else if command -v kubecolor >/dev/null
                # Use kubecolor for other kubectl commands
                kubecolor $argv
            else
                # Fallback to regular kubectl
                command kubectl $argv
            end
        end

        # Systemctl/journalctl logs
        function journalctl --description "Journalctl with colored output"
            command journalctl $argv | splash
        end

        # Tail with splash for log files
        function tail --description "Tail with automatic log colorization"
            # Check if we're tailing a log file or using -f flag
            if string match -q -- "*-f*" "$argv"; or string match -q -- "*.log" "$argv"
                command tail $argv | splash
            else
                command tail $argv
            end
        end

        # Cat for log files
        function cat --description "Cat with automatic log colorization"
            # Check if we're viewing a log file
            if string match -q -- "*.log" "$argv"; or string match -q -- "*.json" "$argv"
                command cat $argv | splash
            else
                # Use bat for other files if available, otherwise regular cat
                if command -v bat >/dev/null
                    bat $argv
                else
                    command cat $argv
                end
            end
        end

        # Less for log files (using process substitution)
        function less --description "Less with automatic log colorization"
            if string match -q -- "*.log" "$argv"; or string match -q -- "*.json" "$argv"
                command cat $argv | splash | command less -R
            else
                command less $argv
            end
        end

        # Terraform commands that produce logs
        function terraform --description "Terraform with colored output"
            if test "$argv[1]" = "plan"; or test "$argv[1]" = "apply"; or test "$argv[1]" = "destroy"
                command terraform $argv | splash
            else
                command terraform $argv
            end
        end

        # Go commands
        function go --description "Go with colored output for logs"
            # Check for SPLASH_ARGS environment variable for custom splash options
            if test "$argv[1]" = "run"; or test "$argv[1]" = "test"; or test "$argv[1]" = "build"
                if set -q SPLASH_ARGS
                    # Use custom splash arguments if set
                    command go $argv 2>&1 | splash $SPLASH_ARGS
                else
                    # Default splash without arguments
                    command go $argv 2>&1 | splash
                end
            else
                command go $argv
            end
        end

        # npm/yarn/pnpm commands
        function npm --description "npm with colored logs"
            if test "$argv[1]" = "run"; or test "$argv[1]" = "start"; or test "$argv[1]" = "test"
                command npm $argv 2>&1 | splash
            else
                command npm $argv
            end
        end

        function yarn --description "yarn with colored logs"
            if test "$argv[1]" = "run"; or test "$argv[1]" = "start"; or test "$argv[1]" = "test"
                command yarn $argv 2>&1 | splash
            else
                command yarn $argv
            end
        end

        function pnpm --description "pnpm with colored logs"
            if test "$argv[1]" = "run"; or test "$argv[1]" = "start"; or test "$argv[1]" = "test"
                command pnpm $argv 2>&1 | splash
            else
                command pnpm $argv
            end
        end

        # Helper function to manually colorize any command
        function logs --description "Run any command with splash colorization"
            $argv | splash
        end

        # Alias for quick log viewing with search
        function logsearch --description "View logs with highlighted search term"
            if test (count $argv) -lt 2
                echo "Usage: logsearch <file> <search-term>"
                return 1
            end
            cat $argv[1] | splash -s $argv[2]
        end

        # Helper functions for highlighted command output
        function gos --description "Run go command with highlighted search term"
            if test (count $argv) -lt 2
                echo "Usage: gos <search-term> <go-command>"
                echo "Example: gos ERROR go test ./..."
                return 1
            end
            set -l search_term $argv[1]
            set -e argv[1]
            command go $argv 2>&1 | splash -s "$search_term"
        end

        function gor --description "Run go command with regex highlighting"
            if test (count $argv) -lt 2
                echo "Usage: gor <regex> <go-command>"
                echo "Example: gor 'FAIL|ERROR' go test ./..."
                return 1
            end
            set -l regex $argv[1]
            set -e argv[1]
            command go $argv 2>&1 | splash -r "$regex"
        end

        # Generic helper for any command with search highlighting
        function runs --description "Run any command with splash search highlighting"
            if test (count $argv) -lt 2
                echo "Usage: runs <search-term> <command...>"
                echo "Example: runs ERROR npm test"
                return 1
            end
            set -l search_term $argv[1]
            set -e argv[1]
            $argv 2>&1 | splash -s "$search_term"
        end

        function runr --description "Run any command with splash regex highlighting"
            if test (count $argv) -lt 2
                echo "Usage: runr <regex> <command...>"
                echo "Example: runr '[45]\\d\\d' curl api.example.com"
                return 1
            end
            set -l regex $argv[1]
            set -e argv[1]
            $argv 2>&1 | splash -r "$regex"
        end

        # Function to set splash arguments for the current session
        function splash-set --description "Set splash arguments for automatic commands"
            if test (count $argv) -eq 0
                if set -q SPLASH_ARGS
                    echo "Current SPLASH_ARGS: $SPLASH_ARGS"
                else
                    echo "No SPLASH_ARGS set"
                end
                echo ""
                echo "Usage: splash-set <args>"
                echo "Examples:"
                echo "  splash-set -s ERROR        # Highlight ERROR in all auto-splash commands"
                echo "  splash-set -r '[45]\\d\\d'  # Highlight 4xx and 5xx HTTP codes"
                echo "  splash-set --dark          # Force dark theme"
                echo "  splash-set ''              # Clear splash arguments"
            else if test "$argv[1]" = ""
                set -e SPLASH_ARGS
                echo "SPLASH_ARGS cleared"
            else
                set -gx SPLASH_ARGS $argv
                echo "SPLASH_ARGS set to: $argv"
            end
        end

        # Alias for convenience
        alias splash-clear="splash-set ''"
    end

    alias n=nvim
    alias lg=lazygit
    alias ld=lazydocker
    alias fixterm="stty sane"
    alias footyres="$HOME/dotfiles/scripts/bin/footyres"  # Football results CLI

    # Obsidian Aliases
    function obs --description "Navigate to Obsidian vault and open nvim"
        cd ~/obsidian && nvim .
    end
    
    function todo --description "Navigate to Obsidian vault and open TODO.md"
        cd ~/obsidian && nvim TODO.md
    end

    # Kubernetes aliases
    alias kctx="kubie ctx"
    alias kns="kubie ns"

    # GitHub Gist aliases (enhanced with fzf functions below)
    alias gispub="gis"
    alias gispriv="gh gist create"

    # System monitoring aliases
    alias top="btop"  # Use btop as default process viewer
    alias htop="htop --tree"  # Show htop with tree view by default
    alias ps="procs"  # Use procs as modern ps replacement
    alias pst="procs --tree"  # Process tree view
    alias psg="procs | grep"  # Search processes
    alias net="sudo bandwhich"  # Network monitoring (requires sudo)
    alias dig="doggo"  # Modern DNS lookup
    alias dns="doggo"  # Alternative DNS alias

    # Security & DevSecOps Tools
    alias scan="trivy"  # Vulnerability scanner
    alias vuln="grype"  # Container vulnerability scanner
    alias sbom="syft"  # Generate SBOM
    alias tfscan="tfsec"  # Terraform security scanner
    alias iacscan="checkov"  # IaC security scanner
    alias semscan="semgrep"  # Static analysis
    alias dockerlint="hadolint"  # Dockerfile linter

    # Kubernetes & Container Tools
    alias k="kubectl"  # Kubernetes CLI shorthand
    alias kx="kubie ctx"  # Switch kubernetes context
    alias kns="kubie ns"  # Switch namespace
    alias kdive="dive"  # Docker image explorer
    alias kctop="ctop"  # Container metrics

    # Better File/System Tools
    alias du="dust"  # Better disk usage
    alias ncdu="ncdu --color dark"  # NCurses disk usage
    alias sed="sd"  # Better sed replacement
    alias cut="choose"  # Better cut/awk
    alias loc="tokei"  # Code statistics
    alias duf="duf"  # Better df

    # Network Tools
    alias http="xh"  # Friendly HTTP client
    alias grpc="grpcurl"  # gRPC client
    alias trace="mtr"  # Better traceroute
    alias ping="gping"  # Ping with graph
    alias bench="hyperfine"  # Command benchmarking
    alias load="oha"  # HTTP load testing

    # Infrastructure Tools
    alias tf="terraform"  # Terraform shorthand
    alias tg="terragrunt"  # Terragrunt shorthand
    alias tfdoc="terraform-docs"  # Terraform docs
    alias tfcost="infracost"  # Infrastructure cost

    # Monitoring & Performance
    alias mon="glances"  # System monitoring
    alias logs="lnav"  # Log navigator
    alias flame="flamegraph"  # Performance visualization

    # Development Tools
    alias watch="watchexec"  # Execute on file change
    alias j="just"  # Command runner
    alias t="task"  # Task runner
    alias act="act --container-architecture linux/amd64"  # GitHub Actions locally with ARM64 compatibility

    # AI Tools
    # Use 'ccr code' or just 'ccr' to start Claude Code Router
    alias claude-router="command ccr code"  # Alternative alias for Claude Code Router

    # Utility aliases
    alias wea="curl --silent wttr.in/Didsbury_uk | grep -v Follow"
    alias save="~/sesh.sh save"
    alias rest="~/sesh.sh restore"
    alias tr="clear; ~/dotfiles/scripts/tmux-smart-restore.sh"
    alias ts="tmux run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh'"
    alias tk="~/dotfiles/scripts/tmux-safe-kill-server.sh"  # Safe kill with auto-save
    alias tkf="tmux kill-server"  # Force kill without save (use with caution)

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

    # Enhanced GitHub Gist management with fzf
    function gisls --description "List and manage GitHub gists with fzf"
        set -l gists (gh gist list --limit 100 2>/dev/null)

        if test -z "$gists"
            echo "No gists found"
            return 1
        end

        set -l selected (printf '%s\n' $gists | fzf --prompt="Select gist (ENTER=view, CTRL-E=edit, CTRL-D=delete): " \
            --height=40% --border \
            --header="ENTER=view | CTRL-E=edit | CTRL-D=delete" \
            --bind='ctrl-e:execute(echo edit {})+abort' \
            --bind='ctrl-d:execute(echo delete {})+abort')

        if test -n "$selected"
            set -l gist_id (echo $selected | awk '{print $1}')

            # Check if user wants to edit or delete
            if string match -q "edit *" "$selected"
                set gist_id (echo $selected | awk '{print $2}' | awk '{print $1}')
                echo "Editing gist: $gist_id"
                gh gist edit $gist_id
            else if string match -q "delete *" "$selected"
                set gist_id (echo $selected | awk '{print $2}' | awk '{print $1}')
                read -P "Delete gist $gist_id? (y/N): " confirm
                if test "$confirm" = "y"
                    gh gist delete $gist_id
                    echo "Deleted gist: $gist_id"
                end
            else
                # Default action: view the gist
                gh gist view $gist_id
            end
        end
    end

    function gisdel --description "Delete GitHub gists with fzf selection"
        set -l gists (gh gist list --limit 100 2>/dev/null)

        if test -z "$gists"
            echo "No gists found"
            return 1
        end

        set -l selected (printf '%s\n' $gists | fzf --multi --prompt="Select gists to delete (TAB for multiple): " --height=40% --border)

        if test -n "$selected"
            for gist in $selected
                set -l gist_id (echo $gist | awk '{print $1}')
                read -P "Delete gist $gist_id? (y/N): " confirm
                if test "$confirm" = "y"
                    gh gist delete $gist_id
                    echo "Deleted gist: $gist_id"
                end
            end
        end
    end

    function ssmc --description "Connect to EC2 instances via AWS SSM with interactive selection"
        set -l profile $argv[1]
        
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
            set profile "petlab"
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
            set -l ip_address $parts[4]

            # Handle instances without Name tag
            if test "$name" = "None" -o -z "$name"
                set name "Unnamed"
            end
            
            # Check if instance has SSM connectivity
            set -l ssm_status "❌ SSM Offline"
            if string match -q "*$instance_id*" $ssm_instances
                set ssm_status "✅ SSM Ready"
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
                    echo "⚠️  Warning: Instance $instance_id does not have SSM connectivity"
                    echo "The SSM agent may not be installed or running on this instance"
                    read -P "Try to connect anyway? (y/N): " -n 1 confirm
                    if test "$confirm" != "y" -a "$confirm" != "Y"
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

    function f
        vim (fzf)
    end

    # Enhanced git branch deletion with fzf
    function gx --description "Interactively delete git branches with fzf"
        set -l branches (git branch --list | grep -v "^[ *]*main\$" | sed 's/^[* ]*//')

        if test -z "$branches"
            echo "No branches to delete (main is protected)"
            return 1
        end

        set -l selected (printf '%s\n' $branches | fzf --multi --prompt="Select branches to delete (TAB to select multiple): " --height=40% --border)

        if test -n "$selected"
            for branch in $selected
                echo "Deleting branch: $branch"
                git branch -d $branch
            end
        else
            echo "No branches selected"
        end
    end

    function e
        ls -hal | nms -as
    end

    function tb
        nc termbin.com 9999 | pbcopy
    end

    # AWS SSO function with fzf selection
    function aws-sso --description "Authenticate with AWS SSO with fzf profile selection"
        set -l profile $argv[1]

        if test -z "$profile"
            # Use fzf to select profile
            set -l profiles (aws configure list-profiles 2>/dev/null)
            if test -z "$profiles"
                echo "No AWS profiles configured"
                return 1
            end

            set profile (printf '%s\n' $profiles | fzf --prompt="Select AWS SSO profile: " --height=40% --border)
            test -z "$profile"; and return 0
        end

        echo "Logging in to AWS SSO profile: $profile"
        aws sso login --profile "$profile"
        eval (aws configure export-credentials --profile "$profile" --format env)
        set -gx AWS_DEFAULT_PROFILE "$profile"
        set -gx AWS_PROFILE "$profile"

        if aws sts get-caller-identity >/dev/null 2>&1
            echo "✅ Successfully authenticated as:"
            aws sts get-caller-identity --output table
        else
            echo "❌ Failed to get credentials"
            return 1
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

    # GuardDuty log viewer with FZF bucket and path selection
    function gd-view --description "Search and analyze AWS GuardDuty security findings in S3"
        set -l bucket ""
        set -l pattern ""
        set -l prefix ""

        # Parse arguments - if first arg doesn't look like a bucket name, treat it as pattern
        if test (count $argv) -ge 1
            # Check if first arg looks like a search pattern (contains quotes, brackets, colons, etc.)
            if string match -q "*[\"':{\[\]]*" -- $argv[1]; or string match -q "*severity*" -- $argv[1]
                # First arg is a pattern, need to select bucket
                set pattern $argv[1]
                set prefix $argv[2]
            else
                # First arg is a bucket
                set bucket $argv[1]
                set pattern $argv[2]
                set prefix $argv[3]
            end
        end

        # If no bucket specified, use fzf to select
        if test -z "$bucket"
            # Use fzf to select bucket containing GuardDuty logs
            set -l buckets (aws s3 ls 2>/dev/null | grep -E "(guard|security|threat|finding)" | awk '{print $3}')

            if test -z "$buckets"
                # Fallback to all buckets if no GuardDuty-specific ones found
                set buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
            end

            if test -z "$buckets"
                echo "No S3 buckets found"
                return 1
            end

            set bucket (printf '%s\n' $buckets | fzf --prompt="Select GuardDuty bucket: " --height=40% --border)
            test -z "$bucket"; and return 0

            echo "Selected bucket: $bucket"
        end

        # Interactive prefix selection if not provided
        if test -z "$prefix"
            echo "Browsing bucket structure..."
            set -l current_path ""

            while true
                # List prefixes at current level
                set -l prefixes
                if test -z "$current_path"
                    set prefixes (aws s3 ls s3://$bucket/ 2>/dev/null | grep PRE | awk '{print $2}')
                else
                    set prefixes (aws s3 ls s3://$bucket/$current_path 2>/dev/null | grep PRE | awk '{print $2}')
                end

                if test -z "$prefixes"
                    # No more subdirectories, use current path
                    set prefix $current_path
                    break
                end

                # Add options for navigation
                set -l options "📁 Use current path: $current_path"
                if test -n "$current_path"
                    set options $options "⬆️  Go up one level"
                end
                set options $options $prefixes

                set -l selected (printf '%s\n' $options | fzf --prompt="Navigate to prefix (or use current): " --height=40% --border)

                if test -z "$selected"
                    # User cancelled
                    return 0
                else if string match -q "📁 Use current path:*" "$selected"
                    # Use current path
                    set prefix $current_path
                    break
                else if string match -q "⬆️  Go up one level" "$selected"
                    # Go up one directory level
                    set current_path (string replace -r '/[^/]+/$' '/' $current_path)
                    if test "$current_path" = "/"
                        set current_path ""
                    end
                else
                    # Navigate into selected directory
                    set current_path "$current_path$selected"
                end
            end

            echo "Selected prefix: $prefix"
        end

        # Get search pattern if not provided
        if test -z "$pattern"
            read -P "Enter search pattern (default: \"severity\":): " pattern
            test -z "$pattern"; and set pattern '"severity":'
        end

        echo "Searching GuardDuty findings in $bucket..."
        echo "Pattern: $pattern"
        test -n "$prefix"; and echo "Prefix: $prefix"

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

    # CloudTrail log viewer with FZF bucket and path selection
    function ct-view --description "Search and analyze AWS CloudTrail logs in S3 buckets"
        set -l bucket ""
        set -l pattern ""
        set -l prefix ""

        # Parse arguments - if first arg is not a bucket, assume it's a pattern
        if test (count $argv) -ge 1
            # Check if first arg is likely a bucket name (no special chars, looks like S3 naming)
            if string match -q "*-*" -- $argv[1]; and not string match -q "*[/:\"']*" -- $argv[1]
                # Looks like a bucket name
                set bucket $argv[1]
                set pattern $argv[2]
                set prefix $argv[3]
            else
                # First arg is probably a pattern (event name, etc.)
                set pattern $argv[1]
                set prefix $argv[2]
            end
        end

        # If no bucket specified, use fzf to select
        if test -z "$bucket"
            # Use fzf to select bucket containing CloudTrail logs
            set -l buckets (aws s3 ls 2>/dev/null | grep -E "(trail|cloudtrail|audit|log|central)" | awk '{print $3}')

            if test -z "$buckets"
                # Fallback to all buckets if no CloudTrail-specific ones found
                set buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
            end

            if test -z "$buckets"
                echo "No S3 buckets found"
                return 1
            end

            set bucket (printf '%s\n' $buckets | fzf --prompt="Select CloudTrail bucket: " --height=40% --border)
            test -z "$bucket"; and return 0

            echo "Selected bucket: $bucket"
        end

        # Interactive prefix selection if not provided
        if test -z "$prefix"
            echo "Browsing bucket structure..."
            set -l current_path ""

            while true
                # List prefixes at current level
                set -l prefixes
                if test -z "$current_path"
                    set prefixes (aws s3 ls s3://$bucket/ 2>/dev/null | grep PRE | awk '{print $2}')
                else
                    set prefixes (aws s3 ls s3://$bucket/$current_path 2>/dev/null | grep PRE | awk '{print $2}')
                end

                if test -z "$prefixes"
                    # No more subdirectories, use current path
                    set prefix $current_path
                    break
                end

                # Add options for navigation
                set -l options "📁 Use current path: $current_path"
                if test -n "$current_path"
                    set options $options "⬆️  Go up one level"
                end
                set options $options $prefixes

                set -l selected (printf '%s\n' $options | fzf --prompt="Navigate to prefix (or use current): " --height=40% --border)

                if test -z "$selected"
                    # User cancelled
                    return 0
                else if string match -q "📁 Use current path:*" "$selected"
                    # Use current path
                    set prefix $current_path
                    break
                else if string match -q "⬆️  Go up one level" "$selected"
                    # Go up one directory level
                    set current_path (string replace -r '/[^/]+/$' '/' $current_path)
                    if test "$current_path" = "/"
                        set current_path ""
                    end
                else
                    # Navigate into selected directory
                    set current_path "$current_path$selected"
                end
            end

            echo "Selected prefix: $prefix"
        end

        # Get search pattern if not provided
        if test -z "$pattern"
            read -P "Enter search pattern (or press enter for all): " pattern
            test -z "$pattern"; and set pattern "."
        end

        echo "Searching CloudTrail events in $bucket..."
        echo "Pattern: $pattern"
        test -n "$prefix"; and echo "Prefix: $prefix"

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

    # List S3 bucket contents with date filtering and fzf selection
    function s3-dates --description "List and explore S3 log dates with fzf selection"
        set -l bucket $argv[1]
        set -l prefix $argv[2]
        set -l days $argv[3]

        if test -z "$bucket"
            # Use fzf to select bucket if not provided
            set -l buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
            if test -z "$buckets"
                echo "No S3 buckets found"
                return 1
            end

            set bucket (printf '%s\n' $buckets | fzf --prompt="Select S3 bucket: " --height=40% --border)
            test -z "$bucket"; and return 0
        end

        test -z "$days"; and set days 30

        echo "📅 Fetching dates from s3://$bucket/$prefix..."
        set -l dates (aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null \
            | grep -E '20[0-9]{2}/[0-9]{2}/[0-9]{2}/' \
            | awk '{print $4}' \
            | grep -oE '20[0-9]{2}/[0-9]{2}/[0-9]{2}' \
            | sort -r | uniq | head -$days)

        if test -z "$dates"
            echo "No dates found in bucket"
            return 1
        end

        # Use fzf to select a date to explore
        set -l selected_date (printf '%s\n' $dates | fzf --prompt="Select date to explore: " --height=40% --border)

        if test -n "$selected_date"
            echo "Exploring logs for date: $selected_date"
            set -l date_path (string replace -a "/" "/" $selected_date)

            # List files for selected date
            echo "Files for $selected_date:"
            set -l files (aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null | grep "$date_path" | awk '{print $4}' | head -20)

            if test -n "$files"
                set -l selected_file (printf '%s\n' $files | fzf --prompt="Select file to view: " --height=40% --border)

                if test -n "$selected_file"
                    echo "Viewing: $selected_file"
                    aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100 | jq '.' 2>/dev/null || aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100
                end
            else
                echo "No files found for date: $selected_date"
            end
        end
    end

    # Interactive S3 log browser with fzf
    function s3-browse --description "Interactive browser for exploring S3 log buckets with fzf"
        set -l bucket $argv[1]

        if test -z "$bucket"
            # Use fzf to select from available buckets
            set -l buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
            if test -z "$buckets"
                echo "No S3 buckets found"
                return 1
            end

            set bucket (printf '%s\n' $buckets | fzf --prompt="Select S3 bucket: " --height=40% --border)
            test -z "$bucket"; and return 0
        end

        echo "S3 Log Browser: $bucket"
        echo "======================"

        # Use fzf to select prefix
        set -l prefixes (aws s3 ls s3://$bucket/ 2>/dev/null | grep PRE | awk '{print $2}')

        if test -n "$prefixes"
            set -l prefix (printf '%s\n' $prefixes | fzf --prompt="Select prefix to explore: " --height=40% --border)
            test -z "$prefix"; and return 0

            # Use fzf to select from recent files or enter custom pattern
            echo "Fetching recent files in $prefix..."
            set -l files (aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null | tail -20 | awk '{print $4}')

            if test -n "$files"
                echo "Recent files found. Select one to view or press ESC to search with pattern."
                set -l selected_file (printf '%s\n' $files | fzf --prompt="Select file or ESC for pattern search: " --height=40% --border)

                if test -n "$selected_file"
                    # View specific file
                    echo "Viewing: $selected_file"
                    aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100 | jq '.' 2>/dev/null || aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100
                    return 0
                end
            end

            # Pattern search
            read -P "Enter search pattern (or press enter for all): " pattern
            test -z "$pattern"; and set pattern "."

            echo "Searching..."
            s3-logs $bucket "$pattern" "$prefix" | head -50
        else
            echo "No prefixes found in bucket"
        end
    end

    # Quick log analysis with fzf bucket selection
    function logs --description "Quick AWS log search with fzf bucket selection"
        set -l pattern $argv[1]
        set -l bucket $argv[2]

        if test -z "$pattern"
            echo "Usage: logs <pattern> [bucket]"
            echo "Examples:"
            echo "  logs AssumeRole                    # Search with bucket selection"
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

        if test -z "$bucket"
            # Use fzf to select bucket or search all log buckets
            set -l log_buckets (aws s3 ls 2>/dev/null | grep -E "(log|trail|guard|audit)" | awk '{print $3}')

            if test -n "$log_buckets"
                # Add option to search all
                set -l options "Search all log buckets"
                set options $options $log_buckets

                set -l selected (printf '%s\n' $options | fzf --prompt="Select bucket to search: " --height=40% --border)

                if test "$selected" = "Search all log buckets"
                    echo "Searching all log buckets..."
                    for b in $log_buckets
                        echo "🔍 Searching $b..."
                        s3-logs $b "$pattern" | head -5
                    end
                else if test -n "$selected"
                    set bucket $selected
                    echo "Searching $bucket..."
                    s3-logs $bucket "$pattern"
                end
            else
                # Fallback to known buckets
                echo "No log buckets found, trying default buckets..."

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
        else
            # Search specific bucket
            echo "Searching $bucket..."
            s3-logs $bucket "$pattern"
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

    # Git checkout with fzf
    function gco --description "Git checkout branch/tag with fzf"
        set -l branches (git branch -a 2>/dev/null | grep -v HEAD | sed 's/.* //' | sed 's|remotes/[^/]*/||' | sort -u)

        if test -z "$branches"
            echo "No branches found"
            return 1
        end

        set -l selected (printf '%s\n' $branches | fzf --prompt="Checkout branch: " --height=40% --border)

        if test -n "$selected"
            git checkout $selected
        end
    end

    # Git stash management with fzf
    function gstash --description "Manage git stashes with fzf"
        set -l stashes (git stash list 2>/dev/null)

        if test -z "$stashes"
            echo "No stashes found"
            return 1
        end

        set -l selected (printf '%s\n' $stashes | fzf --prompt="Select stash (ENTER=apply, CTRL-P=pop, CTRL-D=drop): " \
            --height=40% --border \
            --header="ENTER=apply | CTRL-P=pop | CTRL-D=drop" \
            --bind='ctrl-p:execute(echo pop {})+abort' \
            --bind='ctrl-d:execute(echo drop {})+abort')

        if test -n "$selected"
            set -l stash_id (echo $selected | command cut -d: -f1)

            if string match -q "pop *" "$selected"
                set stash_id (echo $selected | awk '{print $2}' | command cut -d: -f1)
                echo "Popping stash: $stash_id"
                git stash pop $stash_id
            else if string match -q "drop *" "$selected"
                set stash_id (echo $selected | awk '{print $2}' | command cut -d: -f1)
                read -P "Drop stash $stash_id? (y/N): " confirm
                if test "$confirm" = "y"
                    git stash drop $stash_id
                    echo "Dropped stash: $stash_id"
                end
            else
                # Default action: apply stash
                echo "Applying stash: $stash_id"
                git stash apply $stash_id
            end
        end
    end

    # Docker container management with fzf
    function dps --description "Select Docker container with fzf for various operations"
        set -l containers (docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | tail -n +2)

        if test -z "$containers"
            echo "No Docker containers found"
            return 1
        end

        set -l selected (printf '%s\n' $containers | fzf --prompt="Select container (ENTER=logs, CTRL-S=shell, CTRL-R=restart, CTRL-D=delete): " \
            --height=40% --border \
            --header="ENTER=logs | CTRL-S=shell | CTRL-R=restart | CTRL-D=delete" \
            --bind='ctrl-s:execute(echo shell {})+abort' \
            --bind='ctrl-r:execute(echo restart {})+abort' \
            --bind='ctrl-d:execute(echo delete {})+abort')

        if test -n "$selected"
            set -l container_id (echo $selected | awk '{print $1}')

            if string match -q "shell *" "$selected"
                set container_id (echo $selected | awk '{print $2}')
                echo "Opening shell in container: $container_id"
                docker exec -it $container_id sh
            else if string match -q "restart *" "$selected"
                set container_id (echo $selected | awk '{print $2}')
                echo "Restarting container: $container_id"
                docker restart $container_id
            else if string match -q "delete *" "$selected"
                set container_id (echo $selected | awk '{print $2}')
                read -P "Delete container $container_id? (y/N): " confirm
                if test "$confirm" = "y"
                    docker rm -f $container_id
                    echo "Deleted container: $container_id"
                end
            else
                # Default action: show logs
                echo "Showing logs for container: $container_id"
                docker logs -f $container_id
            end
        end
    end

    # System monitoring helper functions with fzf integration
    function killp --description "Kill process with fzf selection"
        set -l processes (procs --color=disable | tail -n +2)

        if test -z "$processes"
            echo "No processes found"
            return 1
        end

        set -l selected (printf '%s\n' $processes | fzf --multi \
            --prompt="Select process to kill (TAB for multiple): " \
            --height=80% \
            --border \
            --header="PID | User | CPU% | MEM% | Command" \
            --preview='echo {}' \
            --preview-window=down:3:wrap)

        if test -n "$selected"
            for proc in $selected
                set -l pid (echo $proc | awk '{print $1}')
                set -l cmd (echo $proc | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^    //')
                if test -n "$pid"
                    echo "Killing PID $pid: $cmd"
                    kill -9 $pid
                end
            end
        end
    end

    function psf --description "Interactive process search with fzf"
        set -l processes (procs --color=disable)

        if test -z "$processes"
            echo "No processes found"
            return 1
        end

        set -l selected (printf '%s\n' $processes | fzf \
            --prompt="Process Search (ENTER=details, CTRL-K=kill, CTRL-R=refresh): " \
            --height=80% \
            --border \
            --header-lines=1 \
            --bind='ctrl-k:execute-silent(kill -9 {1})+reload(procs --color=disable)' \
            --bind='ctrl-r:reload(procs --color=disable)' \
            --preview='procs {1} --tree' \
            --preview-window=right:50%:wrap)

        if test -n "$selected"
            set -l pid (echo $selected | awk '{print $1}')
            if test "$pid" != "PID"  # Skip header if selected
                echo "Details for PID $pid:"
                procs $pid --tree
            end
        end
    end

    function psg --description "Search processes with grep and fzf"
        if test -z "$argv[1]"
            echo "Usage: psg <search_term>"
            echo "Example: psg chrome"
            return 1
        end

        set -l matches (procs --color=disable | grep -i "$argv[1]" 2>/dev/null)

        if test -z "$matches"
            echo "No processes matching '$argv[1]' found"
            return 1
        end

        # Add header from procs
        set -l header (procs --color=disable | head -n 1)
        set -l selected (printf '%s\n%s\n' "$header" "$matches" | fzf \
            --prompt="Processes matching '$argv[1]' (ENTER=details, CTRL-K=kill): " \
            --height=80% \
            --border \
            --header-lines=1 \
            --bind='ctrl-k:execute-silent(kill -9 {1})' \
            --preview='procs {1} --tree' \
            --preview-window=right:50%:wrap)

        if test -n "$selected"
            set -l pid (echo $selected | awk '{print $1}')
            if test "$pid" != "PID"  # Skip header if selected
                echo "Details for PID $pid:"
                procs $pid --tree
            end
        end
    end

    function port --description "Show what's listening on a given port (with fzf if no port specified)"
        if test -z "$argv[1]"
            # No port specified, use fzf to select from all listening ports
            set -l all_ports (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2 | awk '{print $9}' | command cut -d: -f2 | sort -nu)

            if test -z "$all_ports"
                echo "No listening ports found"
                return 1
            end

            set -l selected_port (printf '%s\n' $all_ports | fzf --prompt="Select port to inspect: " --height=40% --border)

            if test -n "$selected_port"
                echo "Port $selected_port:"
                sudo lsof -iTCP:$selected_port -sTCP:LISTEN
            end
        else
            sudo lsof -iTCP:$argv[1] -sTCP:LISTEN
        end
    end

    function ports --description "Show all listening ports with fzf filtering"
        set -l port_info (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2)

        if test -z "$port_info"
            echo "No listening ports found"
            return 1
        end

        printf '%s\n' $port_info | fzf \
            --prompt="Filter listening ports (ESC to exit): " \
            --height=80% \
            --border \
            --header="COMMAND | PID | USER | FD | TYPE | DEVICE | SIZE/OFF | NODE | NAME" \
            --preview='echo {} | awk "{print \"Process: \" \$1 \"\\nPID: \" \$2 \"\\nUser: \" \$3 \"\\nPort: \" \$9}"' \
            --preview-window=right:40%:wrap
    end

    function mem --description "Show memory usage by process with fzf filtering"
        procs --sortd mem | fzf \
            --prompt="Filter processes by memory (ESC to exit): " \
            --height=80% \
            --border \
            --header-lines=1 \
            --preview='echo {} | awk "{print \"PID: \" \$1 \"\\nMemory: \" \$4 \"\\nCPU: \" \$3 \"\\nCommand: \"}" && echo {} | command cut -d" " -f5-' \
            --preview-window=right:40%:wrap
    end

    function cpu --description "Show CPU usage by process with fzf filtering"
        procs --sortd cpu | fzf \
            --prompt="Filter processes by CPU (ESC to exit): " \
            --height=80% \
            --border \
            --header-lines=1 \
            --preview='echo {} | awk "{print \"PID: \" \$1 \"\\nCPU: \" \$3 \"\\nMemory: \" \$4 \"\\nCommand: \"}" && echo {} | command cut -d" " -f5-' \
            --preview-window=right:40%:wrap
    end

    function netstat-tuln --description "Show all listening ports (netstat style) with fzf"
        sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
            --prompt="Filter network connections: " \
            --height=80% \
            --border \
            --header-lines=1 \
            --preview='echo {} | awk "{print \"Process: \" \$1 \"\\nPID: \" \$2 \"\\nPort: \" \$9}"' \
            --preview-window=down:3:wrap
    end

    function procmon --description "Interactive process monitor with fzf"
        while true
            set -l selected (procs --color=disable | fzf \
                --prompt="Process Monitor (ENTER=details, CTRL-K=kill, CTRL-R=refresh, ESC=exit): " \
                --height=100% \
                --border \
                --header-lines=1 \
                --bind='ctrl-k:execute(kill -9 {1})+reload(procs --color=disable)' \
                --bind='ctrl-r:reload(procs --color=disable)' \
                --preview='procs {1} --tree' \
                --preview-window=right:50%:wrap)

            if test -z "$selected"
                break
            end

            set -l pid (echo $selected | awk '{print $1}')
            echo "Details for PID $pid:"
            procs $pid --tree
            read -P "Press Enter to continue..."
        end
    end

    function portmon --description "Interactive port monitor with fzf"
        while true
            set -l selected (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
                --prompt="Port Monitor (ENTER=details, CTRL-K=kill process, CTRL-R=refresh, ESC=exit): " \
                --height=100% \
                --border \
                --header-lines=1 \
                --bind='ctrl-k:execute(kill -9 {2})+reload(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
                --bind='ctrl-r:reload(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
                --preview='echo "Process: {1}\nPID: {2}\nUser: {3}\nPort: {9}"' \
                --preview-window=down:4:wrap)

            if test -z "$selected"
                break
            end

            set -l pid (echo $selected | awk '{print $2}')
            echo "Details for PID $pid:"
            sudo lsof -p $pid
            read -P "Press Enter to continue..."
        end
    end

    # Alternative version that doesn't require sudo (shows only your processes)
    function myports --description "Monitor your own ports (no sudo required)"
        while true
            set -l selected (lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
                --prompt="Your Ports (ENTER=details, CTRL-K=kill, CTRL-R=refresh, ESC=exit): " \
                --height=100% \
                --border \
                --header-lines=1 \
                --bind='ctrl-k:execute(kill -9 {2})+reload(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
                --bind='ctrl-r:reload(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
                --preview='echo "Process: {1}\nPID: {2}\nUser: {3}\nPort: {9}"' \
                --preview-window=down:4:wrap)

            if test -z "$selected"
                break
            end

            set -l pid (echo $selected | awk '{print $2}')
            echo "Details for PID $pid:"
            lsof -p $pid
            read -P "Press Enter to continue..."
        end
    end

    function dnslookup --description "Perform DNS lookup with fzf record type selection"
        if test -z "$argv[1]"
            echo "Usage: dnslookup <domain> [record_type]"
            echo "Example: dnslookup google.com"
            echo "Example: dnslookup google.com MX"
            return 1
        end

        set -l domain $argv[1]
        set -l record_type $argv[2]

        if test -z "$record_type"
            # Use fzf to select record type
            set -l types "ALL (Show all types)" "A (IPv4 Address)" "AAAA (IPv6 Address)" "MX (Mail Exchange)" "TXT (Text Records)" "NS (Name Servers)" "CNAME (Canonical Name)" "SOA (Start of Authority)" "PTR (Pointer)"
            set -l selected (printf '%s\n' $types | fzf --prompt="Select DNS record type: " --height=40% --border)

            if test -z "$selected"
                return 0
            end

            set record_type (echo $selected | command cut -d' ' -f1)
        end

        if test "$record_type" = "ALL"
            # Show all common record types
            echo "🔍 A Records:"
            doggo $domain A
            echo ""
            echo "🔍 AAAA Records:"
            doggo $domain AAAA
            echo ""
            echo "🔍 MX Records:"
            doggo $domain MX
            echo ""
            echo "🔍 TXT Records:"
            doggo $domain TXT
            echo ""
            echo "🔍 NS Records:"
            doggo $domain NS
        else
            echo "🔍 $record_type Records for $domain:"
            doggo $domain $record_type
        end
    end

    function topmon --description "Interactive top-like monitor with btop/htop selection"
        set -l monitors "btop (Beautiful Resource Monitor)" "htop (Interactive Process Viewer)" "procs (Modern Process Viewer)"
        set -l selected (printf '%s\n' $monitors | fzf --prompt="Select monitor: " --height=30% --border)

        if test -n "$selected"
            switch $selected
                case "*btop*"
                    btop
                case "*htop*"
                    htop
                case "*procs*"
                    procs --watch --watch-interval 1
            end
        end
    end

    function sysinfo --description "Show system information summary"
        echo "🖥️  System Information"
        echo "===================="
        fastfetch --logo none --structure "OS:Kernel:Uptime:CPU:Memory:Disk"
        echo ""
        echo "📊 Process Summary"
        echo "=================="
        procs --tree | head -20
        echo ""
        echo "🌐 Network Activity"
        echo "=================="
        if command -v bandwhich >/dev/null
            echo "Run 'net' (sudo bandwhich) for detailed network monitoring"
        end
        echo ""
        echo "Listening Ports:"
        ports | head -10
    end

    # Docker image management with fzf
    function dimg --description "Select Docker image with fzf for various operations"
        set -l images (docker images --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}" | tail -n +2)

        if test -z "$images"
            echo "No Docker images found"
            return 1
        end

        set -l selected (printf '%s\n' $images | fzf --multi --prompt="Select images (TAB for multiple, ENTER=run, CTRL-D=delete): " \
            --height=40% --border \
            --header="ENTER=run | CTRL-D=delete (TAB for multiple)" \
            --bind='ctrl-d:execute(echo delete {})+abort')

        if test -n "$selected"
            if string match -q "delete *" "$selected"
                # Handle deletion
                for img in (echo $selected | tail -n +2)
                    set -l image_id (echo $img | awk '{print $1}')
                    read -P "Delete image $image_id? (y/N): " confirm
                    if test "$confirm" = "y"
                        docker rmi $image_id
                        echo "Deleted image: $image_id"
                    end
                end
            else
                # Default action: run container
                for img in $selected
                    set -l image_name (echo $img | awk '{print $2}')
                    echo "Running container from image: $image_name"
                    docker run -it --rm $image_name
                end
            end
        end
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

    # ==================== DevOps/SRE FZF Integrations ====================

    # Kubernetes context and namespace switcher with fzf
    function kctx --description "Switch Kubernetes context with fzf"
        if not command -v kubectl >/dev/null
            echo "kubectl not installed"
            return 1
        end

        set -l contexts (kubectl config get-contexts -o name 2>/dev/null)
        if test -z "$contexts"
            echo "No Kubernetes contexts found"
            return 1
        end

        set -l selected (printf '%s\n' $contexts | fzf \
            --prompt="Select Kubernetes context: " \
            --height=40% \
            --border \
            --preview='kubectl config view --minify --context={} | head -20')

        if test -n "$selected"
            kubectl config use-context $selected
            echo "Switched to context: $selected"
        end
    end

    function kns --description "Switch Kubernetes namespace with fzf"
        if not command -v kubectl >/dev/null
            echo "kubectl not installed"
            return 1
        end

        set -l namespaces (kubectl get namespaces -o name 2>/dev/null | command cut -d/ -f2)
        if test -z "$namespaces"
            echo "No namespaces found"
            return 1
        end

        set -l selected (printf '%s\n' $namespaces | fzf \
            --prompt="Select namespace: " \
            --height=40% \
            --border \
            --preview='kubectl get pods -n {} 2>/dev/null | head -20')

        if test -n "$selected"
            kubectl config set-context --current --namespace=$selected
            echo "Switched to namespace: $selected"
        end
    end

    # Pod selector with fzf
    function kpod --description "Select Kubernetes pod with fzf"
        if not command -v kubectl >/dev/null
            echo "kubectl not installed"
            return 1
        end

        set -l pods (kubectl get pods --no-headers 2>/dev/null)
        if test -z "$pods"
            echo "No pods found in current namespace"
            return 1
        end

        set -l selected (printf '%s\n' $pods | fzf \
            --prompt="Select pod (ENTER=describe, CTRL-L=logs, CTRL-E=exec, CTRL-D=delete): " \
            --height=80% \
            --border \
            --header="NAME READY STATUS RESTARTS AGE" \
            --bind='ctrl-l:execute(kubectl logs {1})' \
            --bind='ctrl-e:execute(kubectl exec -it {1} -- /bin/sh)' \
            --bind='ctrl-d:execute(kubectl delete pod {1})' \
            --preview='kubectl describe pod {1}')

        if test -n "$selected"
            set -l pod_name (echo $selected | awk '{print $1}')
            kubectl describe pod $pod_name
        end
    end

    # Docker container selector with fzf
    function dcon --description "Select Docker container with fzf"
        if not command -v docker >/dev/null
            echo "Docker not installed"
            return 1
        end

        set -l containers (docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | tail -n +2)
        if test -z "$containers"
            echo "No running containers found"
            return 1
        end

        set -l selected (printf '%s\n' $containers | fzf \
            --prompt="Select container (ENTER=logs, CTRL-E=exec, CTRL-S=stop, CTRL-R=restart): " \
            --height=80% \
            --border \
            --bind='ctrl-e:execute(docker exec -it {1} /bin/sh)' \
            --bind='ctrl-s:execute(docker stop {1})' \
            --bind='ctrl-r:execute(docker restart {1})' \
            --preview='docker logs --tail 50 {1}')

        if test -n "$selected"
            set -l container_id (echo $selected | awk '{print $1}')
            docker logs --tail 100 -f $container_id
        end
    end

    # Terraform workspace selector
    function tfw --description "Switch Terraform workspace with fzf"
        if not command -v terraform >/dev/null
            echo "Terraform not installed"
            return 1
        end

        if not test -d .terraform
            echo "Not in a Terraform directory (no .terraform folder)"
            return 1
        end

        set -l workspaces (terraform workspace list | sed 's/^[* ] //')
        if test -z "$workspaces"
            echo "No Terraform workspaces found"
            return 1
        end

        set -l selected (printf '%s\n' $workspaces | fzf \
            --prompt="Select Terraform workspace: " \
            --height=40% \
            --border)

        if test -n "$selected"
            terraform workspace select $selected
            echo "Switched to workspace: $selected"
        end
    end

    # Helm release selector
    function helmr --description "Select Helm release with fzf"
        if not command -v helm >/dev/null
            echo "Helm not installed"
            return 1
        end

        set -l releases (helm list --all-namespaces --output json 2>/dev/null | jq -r '.[] | "\(.namespace)\t\(.name)\t\(.status)\t\(.chart)"')
        if test -z "$releases"
            echo "No Helm releases found"
            return 1
        end

        set -l selected (printf '%s\n' $releases | fzf \
            --prompt="Select Helm release (ENTER=status, CTRL-V=values, CTRL-D=delete): " \
            --height=80% \
            --border \
            --header="NAMESPACE NAME STATUS CHART" \
            --bind='ctrl-v:execute(helm get values {2} -n {1})' \
            --bind='ctrl-d:execute(helm delete {2} -n {1})' \
            --preview='helm status {2} -n {1}')

        if test -n "$selected"
            set -l namespace (echo $selected | awk '{print $1}')
            set -l release (echo $selected | awk '{print $2}')
            helm status $release -n $namespace
        end
    end

    # AWS profile switcher with fzf
    function awsp --description "Switch AWS profile with fzf"
        set -l profiles (aws configure list-profiles 2>/dev/null)
        if test -z "$profiles"
            echo "No AWS profiles found"
            return 1
        end

        set -l selected (printf '%s\n' $profiles | fzf \
            --prompt="Select AWS profile: " \
            --height=40% \
            --border \
            --preview='aws configure list --profile {}')

        if test -n "$selected"
            set -gx AWS_PROFILE $selected
            echo "Switched to AWS profile: $selected"
            aws sts get-caller-identity
        end
    end

    # Security scanning with fzf
    function secsan --description "Run security scans with fzf selection"
        set -l tools "trivy image" "trivy fs ." "trivy config ." "grype ." "tfsec ." "checkov -d ." "semgrep --config=auto ." "hadolint Dockerfile"

        set -l selected (printf '%s\n' $tools | fzf \
            --prompt="Select security scan to run: " \
            --height=40% \
            --border)

        if test -n "$selected"
            echo "Running: $selected"
            eval $selected
        end
    end

    # Network port scanner with fzf
    function portscan --description "Scan ports with nmap and fzf"
        if not command -v nmap >/dev/null
            echo "nmap not installed"
            return 1
        end

        echo "Enter target (IP or hostname):"
        read target

        if test -z "$target"
            echo "No target specified"
            return 1
        end

        set -l scan_types "Quick scan (-F)" "Top 100 ports" "Common ports (1-1024)" "All ports (-p-)" "Service detection (-sV)" "OS detection (-O)"

        set -l selected (printf '%s\n' $scan_types | fzf \
            --prompt="Select scan type: " \
            --height=40% \
            --border)

        switch "$selected"
            case "Quick scan*"
                sudo nmap -F $target
            case "Top 100*"
                sudo nmap --top-ports 100 $target
            case "Common ports*"
                sudo nmap -p 1-1024 $target
            case "All ports*"
                sudo nmap -p- $target
            case "Service detection*"
                sudo nmap -sV $target
            case "OS detection*"
                sudo nmap -O $target
        end
    end

    # Log viewer with fzf
    function logsf --description "View logs with fzf and lnav"
        set -l log_files (find /var/log $HOME/logs . -name "*.log" -type f 2>/dev/null | head -50)

        if test -z "$log_files"
            echo "No log files found"
            return 1
        end

        set -l selected (printf '%s\n' $log_files | fzf \
            --prompt="Select log file to view: " \
            --height=60% \
            --border \
            --preview='tail -50 {}' \
            --preview-window=right:60%:wrap)

        if test -n "$selected"
            if command -v lnav >/dev/null
                lnav $selected
            else
                less +F $selected
            end
        end
    end

    # Performance benchmarking with fzf
    function benchf --description "Benchmark commands with hyperfine"
        if not command -v hyperfine >/dev/null
            echo "hyperfine not installed"
            return 1
        end

        echo "Enter first command to benchmark:"
        read cmd1
        echo "Enter second command to benchmark (or press Enter to skip):"
        read cmd2

        if test -z "$cmd1"
            echo "No command specified"
            return 1
        end

        if test -n "$cmd2"
            hyperfine --warmup 3 "$cmd1" "$cmd2"
        else
            hyperfine --warmup 3 "$cmd1"
        end
    end

    # Infrastructure cost estimation with fzf
    function tfcostf --description "Estimate infrastructure costs with infracost"
        if not command -v infracost >/dev/null
            echo "infracost not installed"
            return 1
        end

        set -l actions "breakdown" "diff" "configure"

        set -l selected (printf '%s\n' $actions | fzf \
            --prompt="Select infracost action: " \
            --height=40% \
            --border)

        switch "$selected"
            case "breakdown"
                infracost breakdown --path .
            case "diff"
                infracost diff --path .
            case "configure"
                infracost configure
        end
    end

end

# Note: Additional git+fzf functionality is provided in conf.d/plugins.fish

# FZF-Atuin integration - Custom history search
if status is-interactive
    # Override the default Ctrl-R binding from plugins.fish
    bind \cr atuin_fzf_search
    bind -M insert \cr atuin_fzf_search
end
