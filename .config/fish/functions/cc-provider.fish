function cc-provider --description "Manage Claude Code API provider configuration"
    # Usage: cc-provider <command> [args...]
    #
    # Switch Claude Code between API providers: direct (default), bedrock,
    # vertex, foundry, or custom LLM gateway. Provider configs are stored
    # as env-var files in ~/.claude/providers/.
    #
    # Commands:
    #   use <provider>     Activate a provider for the current shell
    #   off                Deactivate provider (revert to direct API)
    #   status             Show active provider and config
    #   list               List available provider profiles
    #   create <provider>  Create a new provider profile interactively
    #   edit <provider>    Open provider profile in $EDITOR
    #   env [provider]     Print env vars for a provider (default: active)
    #   help               Show help

    set -l cmd $argv[1]
    set -l rest
    if test (count $argv) -gt 1
        set rest $argv[2..]
    end

    switch "$cmd"
        case use
            if test (count $rest) -eq 0
                echo "Usage: cc-provider use <provider>"
                echo "Available: "(string join ", " (_cc_provider_list_names))
                return 1
            end
            _cc_provider_use $rest[1]

        case off reset
            _cc_provider_off

        case status st
            _cc_provider_status

        case list ls
            _cc_provider_list

        case create new
            if test (count $rest) -eq 0
                echo "Usage: cc-provider create <name>"
                return 1
            end
            _cc_provider_create $rest[1]

        case edit
            if test (count $rest) -eq 0
                echo "Usage: cc-provider edit <provider>"
                return 1
            end
            _cc_provider_edit $rest[1]

        case env
            if test (count $rest) -gt 0
                _cc_provider_env $rest[1]
            else
                _cc_provider_env_active
            end

        case help --help -h ''
            echo "cc-provider - Manage Claude Code API provider configuration"
            echo ""
            echo "USAGE:"
            echo "  cc-provider <command> [args...]"
            echo ""
            echo "COMMANDS:"
            echo "  use <provider>     Activate provider for current shell"
            echo "  off                Deactivate provider (revert to direct API)"
            echo "  status             Show active provider and configuration"
            echo "  list               List available provider profiles"
            echo "  create <name>      Create a new provider profile"
            echo "  edit <provider>    Open provider profile in \$EDITOR"
            echo "  env [provider]     Print env vars (default: active provider)"
            echo "  help               Show this help"
            echo ""
            echo "PROVIDERS:"
            echo "  bedrock            Amazon Bedrock (AWS credentials)"
            echo "  vertex             Google Vertex AI (GCP credentials)"
            echo "  foundry            Microsoft Foundry (Azure credentials)"
            echo "  gateway            Custom LLM gateway (LiteLLM, etc.)"
            echo ""
            echo "EXAMPLES:"
            echo "  cc-provider create bedrock        # Create Bedrock profile"
            echo "  cc-provider use bedrock            # Switch to Bedrock"
            echo "  cc-provider status                 # Show active provider"
            echo "  cc-provider off                    # Revert to direct API"
            echo "  cc-provider env bedrock            # Show Bedrock env vars"
            echo ""
            echo "PROFILE DIRECTORY:"
            echo "  ~/.claude/providers/               # Provider config files"
            echo ""
            echo "INTEGRATION:"
            echo "  gwt-ticket --provider bedrock      # Use provider in ticket"
            echo "  CLAUDE_PROVIDER=bedrock claude      # One-off via env var"
            echo ""
            echo "See: docs/third-party-integrations.md"

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'cc-provider help' for usage"
            return 1
    end
end

# --- Internal Functions ---

function _cc_provider_dir
    echo "$HOME/.claude/providers"
end

function _cc_provider_list_names
    set -l dir (_cc_provider_dir)
    if test -d "$dir"
        for f in $dir/*.conf
            if test -f "$f"
                basename "$f" .conf
            end
        end
    end
end

function _cc_provider_use --description "Activate a provider"
    set -l name $argv[1]
    set -l conf (_cc_provider_dir)/$name.conf

    if not test -f "$conf"
        echo "Error: Provider '$name' not found"
        echo "Available: "(string join ", " (_cc_provider_list_names))
        echo "Create one: cc-provider create $name"
        return 1
    end

    # Clear any existing provider vars first
    _cc_provider_off --quiet

    # Source the provider config
    set -l vars_set 0
    while read -l line
        # Skip comments and blank lines
        if string match -qr '^\s*#' "$line"; or string match -qr '^\s*$' "$line"
            continue
        end

        # Parse KEY=VALUE (with optional 'export ' prefix)
        set -l kv (string replace -r '^\s*export\s+' '' "$line")
        set -l key (string split -m1 '=' "$kv")[1]
        set -l val (string split -m1 '=' "$kv")[2]

        # Strip surrounding quotes from value
        set val (string trim -c "'" (string trim -c '"' "$val"))

        if test -n "$key" -a -n "$val"
            set -gx $key "$val"
            set vars_set (math $vars_set + 1)
        end
    end <"$conf"

    # Track active provider
    set -gx CLAUDE_PROVIDER "$name"

    echo "Activated provider: $name ($vars_set env vars set)"
    echo "Run 'cc-provider status' to verify"
end

function _cc_provider_off --description "Deactivate provider"
    set -l quiet false
    if contains -- --quiet $argv
        set quiet true
    end

    # List of all provider-related env vars to clear
    set -l provider_vars \
        CLAUDE_CODE_USE_BEDROCK \
        CLAUDE_CODE_USE_VERTEX \
        CLAUDE_CODE_USE_FOUNDRY \
        CLAUDE_CODE_SKIP_BEDROCK_AUTH \
        CLAUDE_CODE_SKIP_VERTEX_AUTH \
        CLAUDE_CODE_SKIP_FOUNDRY_AUTH \
        ANTHROPIC_BEDROCK_BASE_URL \
        ANTHROPIC_VERTEX_BASE_URL \
        ANTHROPIC_FOUNDRY_BASE_URL \
        ANTHROPIC_FOUNDRY_RESOURCE \
        ANTHROPIC_FOUNDRY_API_KEY \
        ANTHROPIC_VERTEX_PROJECT_ID \
        ANTHROPIC_BASE_URL \
        ANTHROPIC_AUTH_TOKEN \
        ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL \
        ANTHROPIC_DEFAULT_HAIKU_MODEL \
        ANTHROPIC_MODEL \
        ANTHROPIC_SMALL_FAST_MODEL \
        ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION \
        ANTHROPIC_CUSTOM_HEADERS \
        CLOUD_ML_REGION \
        DISABLE_PROMPT_CACHING \
        AWS_BEARER_TOKEN_BEDROCK \
        CLAUDE_PROVIDER

    set -l cleared 0
    for var in $provider_vars
        if set -q $var
            set -e $var
            set cleared (math $cleared + 1)
        end
    end

    if not $quiet
        if test $cleared -gt 0
            echo "Provider deactivated ($cleared vars cleared)"
            echo "Claude Code will use direct API (claude.ai authentication)"
        else
            echo "No provider was active"
        end
    end
end

function _cc_provider_status --description "Show active provider"
    echo "Claude Code Provider Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Active provider
    if set -q CLAUDE_PROVIDER
        echo "Active provider: $CLAUDE_PROVIDER"
    else if set -q CLAUDE_CODE_USE_BEDROCK
        echo "Active provider: bedrock (set via env, not cc-provider)"
    else if set -q CLAUDE_CODE_USE_VERTEX
        echo "Active provider: vertex (set via env, not cc-provider)"
    else if set -q CLAUDE_CODE_USE_FOUNDRY
        echo "Active provider: foundry (set via env, not cc-provider)"
    else if set -q ANTHROPIC_BASE_URL; and test "$ANTHROPIC_BASE_URL" != "http://localhost:11434"
        echo "Active provider: gateway (custom ANTHROPIC_BASE_URL)"
    else
        echo "Active provider: direct (claude.ai / API key)"
    end

    echo ""

    # Show relevant env vars that are set
    set -l check_vars \
        CLAUDE_CODE_USE_BEDROCK \
        CLAUDE_CODE_USE_VERTEX \
        CLAUDE_CODE_USE_FOUNDRY \
        AWS_REGION \
        AWS_PROFILE \
        CLOUD_ML_REGION \
        ANTHROPIC_VERTEX_PROJECT_ID \
        ANTHROPIC_FOUNDRY_RESOURCE \
        ANTHROPIC_BASE_URL \
        ANTHROPIC_BEDROCK_BASE_URL \
        ANTHROPIC_VERTEX_BASE_URL \
        ANTHROPIC_FOUNDRY_BASE_URL \
        ANTHROPIC_MODEL \
        ANTHROPIC_SMALL_FAST_MODEL \
        ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL \
        ANTHROPIC_DEFAULT_HAIKU_MODEL \
        HTTPS_PROXY \
        NODE_EXTRA_CA_CERTS \
        CLAUDE_CODE_CLIENT_CERT

    set -l found 0
    for var in $check_vars
        if set -q $var
            set -l val (eval echo \$$var)
            # Mask sensitive values
            if string match -qr 'KEY|TOKEN|CERT|PASSPHRASE' "$var"
                set val (string sub -l 8 "$val")"..."
            end
            printf "  %-40s %s\n" "$var" "$val"
            set found (math $found + 1)
        end
    end

    if test $found -eq 0
        echo "  (no provider env vars set)"
    end

    echo ""

    # Show available profiles
    set -l profiles (_cc_provider_list_names)
    if test (count $profiles) -gt 0
        echo "Available profiles: "(string join ", " $profiles)
    else
        echo "No profiles configured. Run: cc-provider create <name>"
    end

    # Verify claude command
    echo ""
    if command -q claude
        echo "claude CLI: "(claude --version 2>/dev/null | head -1)
    else
        echo "claude CLI: not found"
    end
end

function _cc_provider_list --description "List provider profiles"
    set -l dir (_cc_provider_dir)

    printf "%-14s %-12s %s\n" PROFILE PROVIDER DESCRIPTION
    printf "%-14s %-12s %s\n" ------- -------- -----------

    # Always show direct (default)
    set -l active_marker ""
    if not set -q CLAUDE_PROVIDER
        set active_marker " (active)"
    end
    printf "%-14s %-12s %s\n" "direct$active_marker" anthropic "Direct API via claude.ai or API key"

    if not test -d "$dir"
        return 0
    end

    for conf in $dir/*.conf
        if not test -f "$conf"
            continue
        end
        set -l name (basename "$conf" .conf)
        set -l provider custom
        set -l desc ""

        # Extract provider type and description from comments
        while read -l line
            if string match -qr '^\s*#\s*provider:\s*(.+)' "$line"
                set provider (string match -r '^\s*#\s*provider:\s*(.+)' "$line")[2]
            end
            if string match -qr '^\s*#\s*description:\s*(.+)' "$line"
                set desc (string match -r '^\s*#\s*description:\s*(.+)' "$line")[2]
            end
        end <"$conf"

        set -l marker ""
        if test "$CLAUDE_PROVIDER" = "$name"
            set marker " (active)"
        end

        printf "%-14s %-12s %s\n" "$name$marker" "$provider" "$desc"
    end
end

function _cc_provider_create --description "Create a provider profile"
    set -l name $argv[1]
    set -l dir (_cc_provider_dir)

    # Validate name
    if not string match -qr '^[a-zA-Z0-9_-]+$' "$name"
        echo "Error: Profile name must be alphanumeric (hyphens/underscores allowed)"
        return 1
    end

    mkdir -p "$dir"

    set -l conf "$dir/$name.conf"
    if test -f "$conf"
        echo "Profile '$name' already exists. Use: cc-provider edit $name"
        return 1
    end

    # Determine template based on name or ask
    set -l provider_type ""
    switch "$name"
        case bedrock bedrock-*
            set provider_type bedrock
        case vertex vertex-*
            set provider_type vertex
        case foundry foundry-* azure azure-*
            set provider_type foundry
        case gateway gateway-* litellm litellm-*
            set provider_type gateway
    end

    if test -z "$provider_type"
        echo "Select provider type:"
        echo "  1) bedrock   - Amazon Bedrock"
        echo "  2) vertex    - Google Vertex AI"
        echo "  3) foundry   - Microsoft Foundry"
        echo "  4) gateway   - LLM Gateway (LiteLLM, etc.)"
        read -P "Choice [1-4]: " -l choice
        switch "$choice"
            case 1 bedrock
                set provider_type bedrock
            case 2 vertex
                set provider_type vertex
            case 3 foundry
                set provider_type foundry
            case 4 gateway
                set provider_type gateway
            case '*'
                echo "Invalid choice"
                return 1
        end
    end

    # Write template using helper script (Fish doesn't support heredocs)
    _cc_provider_write_template "$provider_type" "$conf"

    chmod 600 "$conf"
    echo "Created provider profile: $conf"
    echo ""
    echo "Edit the configuration:"
    echo "  cc-provider edit $name"
    echo ""
    echo "Then activate it:"
    echo "  cc-provider use $name"
end

function _cc_provider_write_template --description "Write provider template via bash script"
    set -l provider_type $argv[1]
    set -l output_file $argv[2]

    # Locate the template script (works from dotfiles or stow symlink)
    set -l script_locations \
        (dirname (status filename))/../../../scripts/cc-provider-templates.sh \
        ~/dotfiles/scripts/cc-provider-templates.sh \
        ~/dotfiles-integrations/scripts/cc-provider-templates.sh

    for script in $script_locations
        if test -x "$script"
            bash "$script" "$provider_type" "$output_file"
            return $status
        end
    end

    echo "Error: cc-provider-templates.sh not found" >&2
    return 1
end

function _cc_provider_edit --description "Edit a provider profile"
    set -l name $argv[1]
    set -l conf (_cc_provider_dir)/$name.conf

    if not test -f "$conf"
        echo "Error: Provider '$name' not found"
        echo "Create one: cc-provider create $name"
        return 1
    end

    set -l editor $EDITOR
    if test -z "$editor"
        set editor nvim
    end

    $editor "$conf"
end

function _cc_provider_env --description "Print env vars for a provider"
    set -l name $argv[1]
    set -l conf (_cc_provider_dir)/$name.conf

    if not test -f "$conf"
        echo "Error: Provider '$name' not found"
        return 1
    end

    echo "# Environment variables for provider: $name"
    echo "# Source with: eval (cc-provider env $name)"
    echo ""

    while read -l line
        if string match -qr '^\s*#' "$line"; or string match -qr '^\s*$' "$line"
            continue
        end
        set -l kv (string replace -r '^\s*export\s+' '' "$line")
        set -l key (string split -m1 '=' "$kv")[1]
        set -l val (string split -m1 '=' "$kv")[2]
        if test -n "$key" -a -n "$val"
            echo "set -gx $key $val"
        end
    end <"$conf"
end

function _cc_provider_env_active --description "Print env vars for active provider"
    if not set -q CLAUDE_PROVIDER
        echo "No provider active (using direct API)"
        echo "Activate one: cc-provider use <provider>"
        return 0
    end
    _cc_provider_env $CLAUDE_PROVIDER
end
