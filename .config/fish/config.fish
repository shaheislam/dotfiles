# Fish Shell Configuration
# Integrated configuration combining dotfiles setup with extended functionality

# Only run in interactive sessions
if status is-interactive
    # Set key timeout (equivalent to KEYTIMEOUT in zsh)
    set -g fish_key_bindings fish_default_key_bindings
    set -g fish_escape_delay_ms 500

    # Environment Variables
    set -x BAT_THEME tokyonight_night
    set -x STARSHIP_CONFIG $HOME/.config/starship.toml

    # Additional environment variables from extended config
    set -x PYTHONPATH /opt/homebrew/lib/python3.12/site-packages

    # Path configuration - combining both configs
    fish_add_path /opt/homebrew/bin
    fish_add_path $HOME/bin
    fish_add_path $HOME/.local/bin
    fish_add_path /usr/local/bin
    fish_add_path $HOME/Library/Python/3.9/bin
    fish_add_path $HOME/.cargo/env
    fish_add_path $HOME/.rd/bin

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
        atuin init fish | source
    end

    # Source asdf
    if test -f "/opt/homebrew/opt/asdf/libexec/asdf.fish"
        source /opt/homebrew/opt/asdf/libexec/asdf.fish
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
    alias cd="z"
    alias ls="eza"
    alias la="eza -al"
    alias l="eza -hal"
    alias cat="bat --theme Dracula -P"
    alias k=kubectl
    alias kubectl=kubecolor
    alias vi=nvim
    alias vim=nvim
    alias n=nvim
    alias c=clear
    alias lg=lazygit
    alias ld=lazydocker
    alias fixterm="stty sane"

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

    # Functions from extended config
    function gis
        if test -n "$argv[1]"
            gh gist create -p $argv[1] | grep https | tee >(pbcopy)
        else
            gisls
        end
    end

        function ssmc
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
    function aws-sso
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
end

# Note: Additional git+fzf functionality is provided in conf.d/plugins.fish
