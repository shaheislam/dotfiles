# Nushell Configuration
# Migrated from Fish shell configuration

# ==================== Core Settings ====================

# Disable welcome message
$env.config = {
    show_banner: false
    
    # Use vi mode for keybindings
    edit_mode: vi
    
    # History settings
    history: {
        max_size: 100_000
        sync_on_enter: true
        file_format: "sqlite"
        isolation: false
    }
    
    # Completion settings
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
        external: {
            enable: true
            max_results: 100
            completer: null
        }
        use_ls_colors: true
    }
    
    # Table settings
    table: {
        mode: rounded
        index_mode: always
        show_empty: true
        padding: { left: 1, right: 1 }
        trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
            truncating_suffix: "..."
        }
        header_on_separator: false
        # abbreviated_row_count: 10
    }
    
    # Shell integration
    shell_integration: {
        osc2: true
        osc7: true
        osc8: true
        osc9_9: false
        osc133: true
        osc633: true
        reset_application_mode: true
    }
    
    cursor_shape: {
        vi_insert: line
        vi_normal: block
    }
    
    buffer_editor: "nvim"
}

# ==================== Tool Integrations ====================

# Initialize Starship prompt
use ~/.cache/starship/init.nu

# Initialize zoxide
source ~/.zoxide.nu

# Initialize atuin (if available)
# Note: atuin init nu needs to be run first to generate the script
let atuin_path = $"($env.HOME)/.local/share/atuin/init.nu"
if ($atuin_path | path exists) {
    source ($atuin_path)
}

# Initialize direnv
# Note: direnv hook nu needs to be configured

# Initialize carapace completions
# Note: carapace _carapace nu needs to be configured

# ==================== Aliases ====================

# Basic aliases
alias python = python3
alias mkdir = mkdir -p

# Enhanced eza aliases
alias ls = eza --icons --group-directories-first
alias ll = eza -la --icons --group-directories-first --git
alias la = eza -a --icons --group-directories-first
alias l = eza -lah --icons --group-directories-first --git
alias tree = eza --tree --icons --level=2
alias lt = eza --tree --icons --level=3

# Kubernetes aliases
alias k = kubectl
alias kctx = kubie ctx
alias kns = kubie ns

# Editor aliases
alias vi = nvim
alias vim = nvim
alias n = nvim

# Development tools
alias lg = lazygit
alias ld = lazydocker

# Utility aliases
alias fixterm = stty sane
alias tmp = tmpmail --generate
alias tmpm = tmpmail
alias altair = open -a 'Altair GraphQL Client'

# GitHub Gist aliases
alias gispub = gis
alias gispriv = gh gist create

# System monitoring aliases
alias top = btop
alias htop = htop --tree
alias ps = procs
alias pst = procs --tree
alias net = sudo bandwhich
alias dig = doggo
alias dns = doggo

# Security & DevSecOps Tools
alias scan = trivy
alias vuln = grype
alias sbom = syft
alias tfscan = tfsec
alias iacscan = checkov
alias semscan = semgrep
alias dockerlint = hadolint

# Better File/System Tools
alias du = dust
alias ncdu = ncdu --color dark
alias sedd = sd  # Use 'sedd' for the sd tool
alias cut = choose
alias loc = tokei
alias duf = duf

# Network Tools
alias http = xh
alias grpc = grpcurl
alias trace = mtr
alias ping = gping
alias bench = hyperfine
alias load = oha

# Infrastructure Tools
alias tf = terraform
alias tg = terragrunt
alias tfdoc = terraform-docs
alias tfcost = infracost

# Monitoring & Performance
alias mon = glances
alias logs = lnav
alias flame = flamegraph

# Development Tools
alias watch = watchexec
alias j = just
alias t = task
alias act = act --container-architecture linux/amd64

# AI Tools
alias claude-router = command ccr code

# Utility aliases
alias wea = curl --silent wttr.in/Didsbury_uk | grep -v Follow
alias save = ~/sesh.sh save
alias rest = ~/sesh.sh restore
alias tr = sh -c "clear; ~/dotfiles/scripts/tmux/tmux-smart-restore.sh"
alias ts = tmux run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh'
alias tk = ~/dotfiles/scripts/tmux/tmux-safe-kill-server.sh
alias tkf = tmux kill-server

# Security aliases
alias vetf = vet --force

# Git worktree aliases
alias gwta = git worktree add
alias gwtab = git worktree add -b
alias gwtp = git worktree prune
alias gwtm = git worktree move

# ==================== Functions ====================

# Yazi shell wrapper for directory navigation
def yy [...args] {
    let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    yazi ...$args --cwd-file=$tmp
    let cwd = (open $tmp | str trim)
    if $cwd != "" and $cwd != $env.PWD {
        cd $cwd
    }
    rm -f $tmp
}

# Obsidian functions
def obs [] {
    cd ~/obsidian
    nvim .
}

def todo [] {
    cd ~/obsidian
    nvim TODO.md
}

# GitHub Gist functions
def gis [file?: string] {
    if ($file | is-not-empty) {
        gh gist create -p $file | lines | where { |line| $line | str contains "https" } | first | clip
    } else {
        gisls
    }
}

def gisls [] {
    let gists = (gh gist list --limit 100 | complete | get stdout | lines)
    
    if ($gists | is-empty) {
        print "No gists found"
        return
    }
    
    let selected = ($gists | str join "\n" | fzf --prompt="Select gist (ENTER=view, CTRL-E=edit, CTRL-D=delete): " --height=40% --border --header="ENTER=view | CTRL-E=edit | CTRL-D=delete" --bind='ctrl-e:execute(echo edit {})+abort' --bind='ctrl-d:execute(echo delete {})+abort')
    
    if ($selected | is-not-empty) {
        let gist_id = ($selected | split row ' ' | first)
        
        if ($selected | str starts-with "edit") {
            let gist_id = ($selected | split row ' ' | get 1)
            print $"Editing gist: ($gist_id)"
            gh gist edit $gist_id
        } else if ($selected | str starts-with "delete") {
            let gist_id = ($selected | split row ' ' | get 1)
            let confirm = (input $"Delete gist ($gist_id)? (y/N): ")
            if $confirm == "y" {
                gh gist delete $gist_id
                print $"Deleted gist: ($gist_id)"
            }
        } else {
            gh gist view $gist_id
        }
    }
}

def gisdel [] {
    let gists = (gh gist list --limit 100 | complete | get stdout | lines)
    
    if ($gists | is-empty) {
        print "No gists found"
        return
    }
    
    let selected = ($gists | str join "\n" | fzf --multi --prompt="Select gists to delete (TAB for multiple): " --height=40% --border)
    
    if ($selected | is-not-empty) {
        $selected | lines | each { |gist|
            let gist_id = ($gist | split row ' ' | first)
            let confirm = (input $"Delete gist ($gist_id)? (y/N): ")
            if $confirm == "y" {
                gh gist delete $gist_id
                print $"Deleted gist: ($gist_id)"
            }
        }
    }
}

# AWS SSM Connect function
def ssmc [profile?: string] {
    print "Fetching EC2 instances..."
    
    # Try to get instances
    mut instances = (aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' --output text | complete | get stdout | lines)
    
    # If no instances and we have a profile, try with profile
    if ($instances | is-empty) and ($profile | is-not-empty) {
        print $"Retrying with profile: ($profile)"
        $instances = (aws ec2 describe-instances --profile $profile --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' --output text | complete | get stdout | lines)
    }
    
    # If still no instances and no profile, try default
    if ($instances | is-empty) and ($profile | is-empty) {
        let profile = "petlab"
        print $"Trying default profile: ($profile)"
        $instances = (aws ec2 describe-instances --profile $profile --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PrivateIpAddress]' --output text | complete | get stdout | lines)
    }
    
    if ($instances | is-empty) {
        print "No running instances found"
        print "Tip: If using Granted, run 'assume <profile>' first"
        return
    }
    
    # Get SSM connection status
    print "Checking SSM connectivity..."
    let ssm_instances = (aws ssm describe-instance-information --query 'InstanceInformationList[*].InstanceId' --output text | complete | get stdout | split row ' ')
    
    # Format instances for selection
    let formatted = ($instances | each { |line|
        let parts = ($line | split row "\t")
        let name = if ($parts | get 0) == "None" or ($parts | get 0 | is-empty) { "Unnamed" } else { $parts | get 0 }
        let instance_id = ($parts | get 1)
        let instance_type = ($parts | get 2)
        let ip = ($parts | get 3)
        
        let ssm_status = if ($instance_id in $ssm_instances) { "✅ SSM Ready" } else { "❌ SSM Offline" }
        
        $"($name) \(($instance_type)\) - ($instance_id) - ($ip) [($ssm_status)]"
    })
    
    let selected = ($formatted | str join "\n" | fzf --prompt="Select instance to connect: " --height=60% --border)
    
    if ($selected | is-not-empty) {
        let instance_id = ($selected | parse '{name} ({type}) - {id} - {ip} [{status}]' | get id | first)
        
        if ($selected | str contains "❌ SSM Offline") {
            print $"Warning: Instance ($instance_id) does not have SSM connectivity"
            print "The instance may not have the SSM agent installed or running"
            let confirm = (input "Try to connect anyway? (y/N): ")
            if $confirm != "y" {
                return
            }
        }
        
        print $"Connecting to ($instance_id)..."
        if ($profile | is-not-empty) {
            aws ssm start-session --target $instance_id --profile $profile
        } else {
            aws ssm start-session --target $instance_id
        }
    }
}

# AWS CloudTrail viewer
def ct-view [bucket?: string, ...args] {
    if ($bucket | is-empty) {
        print "Usage: ct-view <bucket-name> [search-terms...]"
        print "Available buckets:"
        aws s3 ls | lines | each { |line| $line | split row ' ' | last }
        return
    }
    
    let search_terms = if ($args | is-empty) { "" } else { $args | str join " " }
    
    print $"Searching CloudTrail logs in ($bucket)..."
    if ($search_terms | is-not-empty) {
        s3grep --bucket $bucket --expression $search_terms | jq -r '.Records[]' | jq -s '.' | less
    } else {
        s3grep --bucket $bucket | jq -r '.Records[]' | jq -s '.' | less
    }
}

# GuardDuty viewer
def gd-view [bucket?: string, ...args] {
    if ($bucket | is-empty) {
        print "Usage: gd-view <bucket-name> [search-terms...]"
        print "Available buckets:"
        aws s3 ls | lines | each { |line| $line | split row ' ' | last }
        return
    }
    
    let search_terms = if ($args | is-empty) { "" } else { $args | str join " " }
    
    print $"Searching GuardDuty findings in ($bucket)..."
    if ($search_terms | is-not-empty) {
        s3grep --bucket $bucket --expression $search_terms --file-pattern "*.json" | jq -r '.' | less
    } else {
        s3grep --bucket $bucket --file-pattern "*.json" | jq -r '.' | less
    }
}

# S3 log search
def s3-logs [bucket?: string, ...args] {
    if ($bucket | is-empty) {
        print "Usage: s3-logs <bucket-name> [search-terms...]"
        print "Available buckets:"
        aws s3 ls | lines | each { |line| $line | split row ' ' | last }
        return
    }
    
    let search_terms = if ($args | is-empty) { "" } else { $args | str join " " }
    
    if ($search_terms | is-not-empty) {
        s3grep --bucket $bucket --expression $search_terms | jq -r '.' | less
    } else {
        print "Please provide search terms for s3-logs"
    }
}

# S3 date browser
def s3-dates [bucket?: string] {
    if ($bucket | is-empty) {
        print "Usage: s3-dates <bucket-name>"
        print "Available buckets:"
        aws s3 ls | lines | each { |line| $line | split row ' ' | last }
        return
    }
    
    print $"Listing available dates in ($bucket)..."
    aws s3 ls $"s3://($bucket)/" --recursive | lines | parse '{date} {time} {size} {path}' | get path | each { |p| $p | path dirname } | uniq | sort
}

# S3 interactive browser
def s3-browse [bucket?: string] {
    if ($bucket | is-empty) {
        print "Usage: s3-browse <bucket-name>"
        print "Available buckets:"
        aws s3 ls | lines | each { |line| $line | split row ' ' | last }
        return
    }
    
    print $"Browsing ($bucket)..."
    # This would need a more complex implementation for interactive browsing
    aws s3 ls $"s3://($bucket)/" --recursive | less
}

# Quick AWS log search
def logs [...args] {
    let search = ($args | str join " ")
    
    if ($search | is-empty) {
        print "Usage: logs <search-terms>"
        print "Common searches: AssumeRole, CreateBucket, RunInstances, UnauthorizedAccess, root"
        return
    }
    
    # Try common log buckets
    let buckets = [
        "cloudtrail-logs"
        "aws-cloudtrail"
        "guardduty-findings"
        "security-logs"
    ]
    
    for bucket in $buckets {
        let exists = (aws s3 ls $"s3://($bucket)" | complete | get exit_code) == 0
        if $exists {
            print $"Searching in ($bucket)..."
            s3grep --bucket $bucket --expression $search | jq -r '.' | less
            return
        }
    }
    
    print "No standard log buckets found. Please specify bucket with ct-view or gd-view"
}

# AWS SSO login
def aws-sso [profile?: string] {
    if ($profile | is-empty) {
        print "Available profiles:"
        aws configure list-profiles
        return
    }
    
    print $"Logging into AWS SSO profile: ($profile)"
    aws sso login --profile $profile
    
    # Export credentials
    let creds = (aws configure export-credentials --profile $profile --format env)
    if ($creds | is-not-empty) {
        $creds | lines | each { |line|
            let parts = ($line | split column '=' key value)
            if ($parts | length) > 0 {
                let key = ($parts.0.key | str replace 'export ' '')
                let value = ($parts.0.value? | default '')
                load-env { $key: $value }
            }
        }
        print "AWS credentials exported to environment"
    }
}

# Git worktree functions
def gwtl [] {
    let worktrees = (git worktree list | lines)
    if ($worktrees | is-empty) {
        print "No worktrees found"
        return
    }
    
    let selected = ($worktrees | str join "\n" | fzf --prompt="Select worktree: " --height=40% --border)
    if ($selected | is-not-empty) {
        let path = ($selected | split row ' ' | first)
        cd $path
    }
}

def gwtr [] {
    let worktrees = (git worktree list | lines | skip 1)  # Skip main worktree
    if ($worktrees | is-empty) {
        print "No additional worktrees to remove"
        return
    }
    
    let selected = ($worktrees | str join "\n" | fzf --prompt="Select worktree to remove: " --height=40% --border)
    if ($selected | is-not-empty) {
        let path = ($selected | split row ' ' | first)
        let confirm = (input $"Remove worktree at ($path)? (y/N): ")
        if $confirm == "y" {
            git worktree remove $path
            print $"Removed worktree: ($path)"
        }
    }
}

# Helper function to load AWS completions
def-env complete-aws-s3-buckets [] {
    if ("AWS_PROFILE" in $env) {
        aws s3 ls | complete | get stdout | lines | each { |line| $line | split row ' ' | last } | take 20
    } else {
        []
    }
}

def-env complete-aws-profiles [] {
    aws configure list-profiles | complete | get stdout | lines
}

# Command timer functionality
# Note: Nushell has built-in command timing, but we can add custom notifications
$env.config = ($env.config | upsert hooks {
    pre_prompt: [{ ||
        # This runs before each prompt
        null
    }]
    pre_execution: [{ ||
        # Store command start time
        $env.LAST_COMMAND_START = (date now)
    }]
    env_change: {
        PWD: [{ |before, after|
            # Directory change hook
            null
        }]
    }
})

# Note: Some features like splash log colorization and thefuck integration
# need different approaches in Nushell or may not be directly portable

# ==================== Additional Functions ====================

# Quick navigation with fzf
def fcd [] {
    let dir = (fd --type d --hidden --exclude .git | fzf --preview 'eza --tree --icons --level=2 --color=always {}')
    if ($dir | is-not-empty) {
        cd $dir
    }
}

# Quick file open with fzf
def fv [] {
    let file = (fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=numbers,changes --line-range=:500 {}')
    if ($file | is-not-empty) {
        nvim $file
    }
}

# Process search and kill
def psg [query: string] {
    procs | lines | grep $query
}

def psk [] {
    let process = (procs | lines | fzf --prompt="Select process to kill: " --height=40% --border)
    if ($process | is-not-empty) {
        let pid = ($process | split row ' ' | where { |x| $x =~ '\d+' } | first)
        let confirm = (input $"Kill process ($pid)? (y/N): ")
        if $confirm == "y" {
            kill $pid
            print $"Killed process: ($pid)"
        }
    }
}

# ==================== Initialize External Tools ====================

# Run initialization commands for tools that need them
def init_tools [] {
    # Generate starship init if not exists
    let starship_init = $"($env.HOME)/.cache/starship/init.nu"
    if not ($starship_init | path exists) {
        mkdir ~/.cache/starship
        starship init nu | save -f $starship_init
    }
    
    # Generate zoxide init if not exists
    let zoxide_init = $"($env.HOME)/.zoxide.nu"
    if not ($zoxide_init | path exists) {
        zoxide init nushell | save -f $zoxide_init
    }
    
    # Generate atuin init if available
    let atuin_init = $"($env.HOME)/.local/share/atuin/init.nu"
    if (which atuin | is-not-empty) and not ($atuin_init | path exists) {
        mkdir ~/.local/share/atuin
        atuin init nu | save -f $atuin_init
    }
}

# Initialize tools on first run
init_tools

# Add thefuck integration if available
if (which thefuck | is-not-empty) {
    alias fuck = thefuck $"(history | last 1 | get command)"
}

# Enhanced history search with fzf
def search-history [] {
    let cmd = (history | get command | uniq | reverse | str join "\n" | fzf --height=40% --border)
    if ($cmd | is-not-empty) {
        commandline edit --replace $cmd
    }
}

# Quick directory jump with fzf
def z [] {
    let dir = (zoxide query -l | fzf --height=40% --border)
    if ($dir | is-not-empty) {
        cd $dir
    }
}

print "Nushell configuration loaded successfully!"