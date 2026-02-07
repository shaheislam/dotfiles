function claude-sub --description "Manage Claude subscription profiles"
    # Usage: claude-sub <command> [args...]
    #
    # Manages multiple Claude Max subscription profiles. Each profile gets its
    # own config directory (~/.claude-<name>) with shared config symlinked from
    # the primary ~/.claude/ and isolated credentials/runtime data.
    #
    # Commands:
    #   setup <name> [--org-uuid UUID]  Create profile with shared config
    #   list                            List profiles with org/plan info
    #   current                         Show which profile is active
    #   login <name>                    Re-authenticate a profile
    #   help                            Show help

    set -l cmd $argv[1]
    set -l rest
    if test (count $argv) -gt 1
        set rest $argv[2..]
    end

    switch "$cmd"
        case setup
            _claude_sub_setup $rest

        case list ls
            _claude_sub_list

        case current
            _claude_sub_current

        case login
            if test (count $rest) -eq 0
                echo "Usage: claude-sub login <name>"
                return 1
            end
            _claude_sub_login $rest[1]

        case help --help -h ''
            echo "claude-sub - Manage Claude subscription profiles"
            echo ""
            echo "USAGE:"
            echo "  claude-sub <command> [args...]"
            echo ""
            echo "COMMANDS:"
            echo "  setup <name> [--org-uuid UUID]  Create profile with shared config"
            echo "  list                            List profiles with org/plan info"
            echo "  current                         Show active profile"
            echo "  login <name>                    Re-authenticate a profile"
            echo "  help                            Show this help"
            echo ""
            echo "EXAMPLES:"
            echo "  claude-sub setup personal                     # Create 'personal' profile"
            echo "  claude-sub setup work --org-uuid abc-123      # Create with org UUID"
            echo "  claude-sub list                               # Show all profiles"
            echo "  claude-sub login personal                     # Re-authenticate"
            echo ""
            echo "PROFILE DIRECTORIES:"
            echo "  ~/.claude/              Default profile (primary)"
            echo "  ~/.claude-<name>/       Named profiles"
            echo ""
            echo "USAGE WITH OTHER COMMANDS:"
            echo "  gwt-ticket \"Fix bug\" \"Details\" --sub personal"
            echo "  gwt-claude feature/auth --sub work"
            echo "  gwt-queue add \"Fix bug\" --sub personal"

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'claude-sub help' for usage"
            return 1
    end
end

function _claude_sub_setup --description "Create a new subscription profile"
    set -l name ""
    set -l org_uuid ""
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        set -l arg $argv[$i]
        switch $arg
            case --org-uuid
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set org_uuid $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --org-uuid requires a UUID"
                    return 1
                end
            case '-*'
                echo "Error: Unknown option: $arg"
                return 1
            case '*'
                if test -z "$name"
                    set name $arg
                end
        end
    end

    if test -z "$name"
        echo "Usage: claude-sub setup <name> [--org-uuid UUID]"
        return 1
    end

    # Validate name (alphanumeric + hyphens only)
    if not string match -qr '^[a-zA-Z0-9-]+$' "$name"
        echo "Error: Profile name must be alphanumeric (hyphens allowed)"
        return 1
    end

    set -l profile_dir "$HOME/.claude-$name"

    if test -d "$profile_dir"
        echo "Profile '$name' already exists at $profile_dir"
        echo "Use 'claude-sub login $name' to re-authenticate"
        return 1
    end

    echo "Creating profile: $name"
    echo "Directory: $profile_dir"
    echo ""

    # Create profile directory
    mkdir -p "$profile_dir"

    # Symlink shared items from primary ~/.claude/
    # These are config managed by stow (dotfiles -> ~/.claude/)
    set -l symlink_dirs hooks commands templates backups logs audio usage
    set -l symlink_files \
        settings.json settings.local.json bash_commands.json \
        bun_enforcement.json .superclaude-metadata.json \
        AGENTS.md COMMANDS.md FLAGS.md MCP.md MODES.md \
        ORCHESTRATOR.md PRINCIPLES.md RULES.md

    echo "Symlinking shared config..."
    for dir in $symlink_dirs
        if test -e "$HOME/.claude/$dir"
            ln -sf "$HOME/.claude/$dir" "$profile_dir/$dir"
            echo "  $dir/ -> ~/.claude/$dir"
        end
    end

    for file in $symlink_files
        if test -e "$HOME/.claude/$file"
            ln -sf "$HOME/.claude/$file" "$profile_dir/$file"
            echo "  $file -> ~/.claude/$file"
        end
    end

    # Symlink plugins directory (shared across profiles)
    if test -e "$HOME/.claude/plugins"
        ln -sf "$HOME/.claude/plugins" "$profile_dir/plugins"
        echo "  plugins/ -> ~/.claude/plugins"
    end

    # Create runtime directories (profile-specific, not shared)
    set -l runtime_dirs cache debug file-history paste-cache plans projects session-env shell-snapshots todos telemetry statsig ide downloads
    echo ""
    echo "Creating runtime directories..."
    for dir in $runtime_dirs
        mkdir -p "$profile_dir/$dir"
    end

    # If org UUID provided, write it to .claude.json for forced login
    if test -n "$org_uuid"
        echo "Setting org UUID: $org_uuid"
        python3 -c "
import json
config = {
    'oauthAccount': {
        'organizationId': '$org_uuid'
    }
}
with open('$profile_dir/.claude.json', 'w') as f:
    json.dump(config, f, indent=2)
"
    end

    echo ""
    echo "Profile '$name' created. Launching Claude for authentication..."
    echo "Complete the OAuth login in your browser."
    echo ""

    # Launch Claude with the new profile for one-time OAuth login
    env CLAUDE_CONFIG_DIR="$profile_dir" claude

    # After login, show what we got
    echo ""
    if test -f "$profile_dir/.claude.json"
        echo "Authentication complete. Profile info:"
        _claude_sub_show_profile "$name" "$profile_dir"
    else
        echo "Warning: No .claude.json found after login"
        echo "You may need to run: claude-sub login $name"
    end
end

function _claude_sub_login --description "Re-authenticate a subscription profile"
    set -l name $argv[1]
    set -l profile_dir "$HOME/.claude-$name"

    if not test -d "$profile_dir"
        echo "Error: Profile '$name' not found ($profile_dir)"
        echo "Run: claude-sub setup $name"
        return 1
    end

    echo "Re-authenticating profile: $name"
    echo "Complete the OAuth login in your browser."
    echo ""

    env CLAUDE_CONFIG_DIR="$profile_dir" claude

    echo ""
    if test -f "$profile_dir/.claude.json"
        echo "Authentication updated:"
        _claude_sub_show_profile "$name" "$profile_dir"
    end
end

function _claude_sub_current --description "Show which profile is active"
    if test -n "$CLAUDE_CONFIG_DIR"
        set -l dir_name (basename "$CLAUDE_CONFIG_DIR")
        set -l profile_name (string replace '.claude-' '' "$dir_name")
        if test "$profile_name" = ".claude"
            echo "Active profile: default (~/.claude/)"
        else
            echo "Active profile: $profile_name ($CLAUDE_CONFIG_DIR)"
        end
    else
        echo "Active profile: default (~/.claude/)"
    end
end

function _claude_sub_list --description "List all subscription profiles"
    echo "=== Claude Subscription Profiles ==="
    echo ""

    # Always show default
    printf "%-12s %-40s %s\n" "NAME" "DIRECTORY" "ORG / PLAN"
    printf "%-12s %-40s %s\n" "----" "---------" "----------"

    # Default profile
    set -l default_info (_claude_sub_get_info "$HOME/.claude")
    set -l default_marker ""
    if test -z "$CLAUDE_CONFIG_DIR"; or test "$CLAUDE_CONFIG_DIR" = "$HOME/.claude"
        set default_marker " (active)"
    end
    printf "%-12s %-40s %s\n" "default$default_marker" "~/.claude/" "$default_info"

    # Named profiles
    for dir in $HOME/.claude-*/
        if not test -d "$dir"
            continue
        end
        set -l dir_name (basename "$dir")
        set -l name (string replace '.claude-' '' "$dir_name")
        set -l info (_claude_sub_get_info "$dir")
        set -l marker ""
        if test "$CLAUDE_CONFIG_DIR" = "$dir"
            set marker " (active)"
        end
        printf "%-12s %-40s %s\n" "$name$marker" "~/$dir_name/" "$info"
    end
end

function _claude_sub_get_info --description "Extract org/plan info from profile directory"
    set -l dir $argv[1]
    set -l config_file "$dir/.claude.json"

    if not test -f "$config_file"
        echo "not authenticated"
        return
    end

    python3 -c "
import json, sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    oauth = data.get('oauthAccount', {})
    org_name = oauth.get('organizationName', '')
    org_id = oauth.get('organizationId', '')
    email = oauth.get('emailAddress', '')
    plan = oauth.get('planDisplayName', oauth.get('memberRole', ''))

    parts = []
    if org_name:
        parts.append(org_name)
    elif org_id:
        parts.append(org_id[:12] + '...')
    if plan:
        parts.append(plan)
    if email:
        parts.append(email)

    print(' | '.join(parts) if parts else 'authenticated')
except Exception:
    print('error reading config')
" 2>/dev/null
end

function _claude_sub_show_profile --description "Show details for a profile"
    set -l name $argv[1]
    set -l dir $argv[2]
    set -l config_file "$dir/.claude.json"

    if not test -f "$config_file"
        echo "  Not authenticated"
        return
    end

    python3 -c "
import json
try:
    with open('$config_file') as f:
        data = json.load(f)
    oauth = data.get('oauthAccount', {})
    print(f\"  Profile:  $name\")
    print(f\"  Email:    {oauth.get('emailAddress', 'N/A')}\")
    print(f\"  Org:      {oauth.get('organizationName', 'N/A')}\")
    print(f\"  Org UUID: {oauth.get('organizationId', 'N/A')}\")
    print(f\"  Plan:     {oauth.get('planDisplayName', 'N/A')}\")
    print(f\"  Role:     {oauth.get('memberRole', 'N/A')}\")
except Exception as e:
    print(f'  Error reading config: {e}')
" 2>/dev/null
end
