function subdash --description "Unified subscription dashboard and auth doctor"
    set -l cmd $argv[1]

    switch "$cmd"
        case '' --compact --full --once --interval --no-color --help -h
            "$HOME/dotfiles/scripts/tmux/subscription-dashboard.sh" $argv

        case doctor
            _subdash_doctor

        case fix
            _subdash_fix

        case login
            _subdash_login $argv[2..]

        case help
            _subdash_help

        case '*'
            echo "Unknown subdash command: $cmd" >&2
            _subdash_help >&2
            return 1
    end
end

function _subdash_help --description "Show subdash usage"
    echo "subdash - unified Claude/OpenAI subscription dashboard"
    echo ""
    echo "Usage:"
    echo "  subdash                    Show compact dashboard"
    echo "  subdash --full             Show detailed dashboard"
    echo "  subdash doctor            Check all Claude and OpenAI accounts"
    echo "  subdash fix               Refresh OpenAI accounts and show Claude reauths"
    echo "  subdash login claude      Re-auth default Claude profile"
    echo "  subdash login claude <name>"
    echo "  subdash login openai      Open interactive OpenAI/OpenCode login"
    echo "  subdash login openai <name>"
    echo ""
    echo "Examples:"
    echo "  subdash"
    echo "  subdash --full --once"
    echo "  subdash doctor"
    echo "  subdash fix"
    echo "  subdash login claude code-router"
    echo "  subdash login openai shahedulislam94"
end

function _subdash_claude_profiles --description "List Claude profiles as name<TAB>dir"
    if test -d "$HOME/.claude"
        printf 'default|%s\n' "$HOME/.claude"
    end

    for dir in $HOME/.claude-*/
        if not test -d "$dir"
            continue
        end

        set -l trimmed (string trim -r -c '/' -- "$dir")
        set -l name (basename "$trimmed" | string replace '.claude-' '')
        printf '%s|%s\n' "$name" "$trimmed"
    end
end

function _subdash_classify_claude --description "Map Claude usage errors to a simple state"
    set -l raw $argv[1]
    set -l message (string split '\n' -- "$raw")[1]
    set -l lower (string lower -- "$message")

    if string match -q '*credentials file not found*' -- "$lower"
        printf 'MISSING|missing credentials\n'
    else if string match -q '*cannot read claude code credentials from keychain*' -- "$lower"
        printf 'MISSING|missing keychain auth\n'
    else if string match -q '*oauth token expired*' -- "$lower"; or string match -q '*http 401*' -- "$lower"
        printf 'EXPIRED|auth expired\n'
    else if string match -q '*http 429*' -- "$lower"; or string match -q '*rate limited*' -- "$lower"; or string match -q '*capacity*' -- "$lower"
        printf 'LIMITED|usage limited\n'
    else if string match -q '*http 500*' -- "$lower"; or string match -q '*http 502*' -- "$lower"; or string match -q '*http 503*' -- "$lower"; or string match -q '*http 504*' -- "$lower"
        printf 'WARN|api transient\n'
    else
        printf 'ERROR|%s\n' "$message"
    end
end

function _subdash_check_claude --description "Check a Claude profile"
    set -l name $argv[1]
    set -l dir $argv[2]
    set -l script "$HOME/dotfiles/scripts/ticket-queue/claude-usage.sh"
    set -l cmd "$script" --json

    if test "$name" != default
        set -a cmd --config-dir "$dir"
    end

    set -l output (begin
        $cmd 2>&1
    end)
    set -l rc $status

    if test $rc -eq 0
        printf 'HEALTHY|usage available\n'
        return 0
    end

    _subdash_classify_claude "$output"
end

function _subdash_opencode_profiles --description "List OpenCode profiles by name"
    set -l accounts_file "$HOME/.opencode/accounts/.accounts"
    if test -f "$accounts_file"
        cat "$accounts_file"
    end
end

function _subdash_check_openai --description "Check a saved OpenCode/OpenAI profile"
    set -l name $argv[1]
    set -l acct_auth "$HOME/.opencode/accounts/$name/openai-auth.json"
    set -l usage_check "$HOME/dotfiles/scripts/opencode/usage-check.sh"
    set -l login_required_file "$HOME/.opencode/accounts/$name/.login-required"

    if not test -f "$acct_auth"
        printf 'MISSING|missing saved auth\n'
        return 0
    end

    if test -f "$login_required_file"
        printf 'LOGIN|fresh login required\n'
        return 0
    end

    set -l expires (jq -r '.expires // 0' "$acct_auth" 2>/dev/null)
    set -l now_ms (date +%s)000
    if test "$expires" -gt 0; and test "$now_ms" -gt "$expires"
        printf 'EXPIRED|token expired\n'
        return 0
    end

    set -l tmp_auth (mktemp)
    jq -n --slurpfile openai "$acct_auth" '{openai: $openai[0]}' >"$tmp_auth"

    set -l output (bash "$usage_check" --auth-file "$tmp_auth" 2>&1)
    set -l rc $status
    rm -f "$tmp_auth"

    switch $rc
        case 0
            printf 'AVAILABLE|available\n'
        case 1
            printf 'LIMITED|usage limited\n'
        case 2
            printf 'EXPIRED|auth invalid or expired\n'
        case 3
            printf 'MISSING|missing auth entry\n'
        case '*'
            printf 'ERROR|%s\n' "$output"
    end
end

function _subdash_doctor --description "Check all account states"
    set -l claude_repairs
    set -l openai_repairs
    set -l openai_login_repairs
    set -l openai_fix_repairs

    echo "Subdash Doctor"
    echo ""
    echo "Claude"
    for row in (_subdash_claude_profiles)
        set -l parts (string split '|' -- "$row")
        set -l name $parts[1]
        set -l dir $parts[2]
        set -l status_parts (string split '|' -- (_subdash_check_claude "$name" "$dir"))
        set -l state $status_parts[1]
        set -l detail $status_parts[2]

        printf '  %-14s %-9s %s\n' "$name" "$state" "$detail"

        if test "$state" = EXPIRED; or test "$state" = MISSING; or test "$state" = ERROR
            set -a claude_repairs $name
        end
    end

    echo ""
    echo "OpenAI / OpenCode"
    for name in (_subdash_opencode_profiles)
        set -l status_parts (string split '|' -- (_subdash_check_openai "$name"))
        set -l state $status_parts[1]
        set -l detail $status_parts[2]

        printf '  %-14s %-9s %s\n' "$name" "$state" "$detail"

        if test "$state" = LOGIN; or test "$state" = MISSING
            set -a openai_login_repairs $name
        else if test "$state" = EXPIRED; or test "$state" = ERROR
            set -a openai_fix_repairs $name
        end

        if test "$state" = EXPIRED; or test "$state" = MISSING; or test "$state" = ERROR; or test "$state" = LOGIN
            set -a openai_repairs $name
        end
    end

    echo ""
    echo "Repairs"
    if test (count $openai_repairs) -gt 0
        echo "  OpenAI accounts needing attention: "(string join ', ' $openai_repairs)
        if test (count $openai_fix_repairs) -gt 0
            echo "  Run: subdash fix"
        end
        if test (count $openai_login_repairs) -gt 0
            echo "  OpenAI accounts needing fresh login: "(string join ', ' $openai_login_repairs)
            for name in $openai_login_repairs
                echo "    subdash login openai $name"
            end
        end
    else if test (count $openai_fix_repairs) -gt 0
        echo "  Run: subdash fix"
    else
        echo "  OpenAI accounts look good."
    end

    if test (count $claude_repairs) -gt 0
        echo "  Claude profiles needing browser reauth: "(string join ', ' $claude_repairs)
        for name in $claude_repairs
            if test "$name" = default
                echo "    subdash login claude"
            else
                echo "    subdash login claude $name"
            end
        end
    else
        echo "  Claude profiles look good."
    end
end

function _subdash_fix --description "Refresh OpenAI accounts, then report remaining issues"
    set -l refreshed 0
    set -l failed 0
    set -l skipped 0
    set -l accounts (_subdash_opencode_profiles)
    set -l login_required

    echo "Subdash Fix"
    echo ""
    if test (count $accounts) -eq 0
        echo "No saved OpenAI/OpenCode accounts found."
    else
        echo "Refreshing expired OpenAI/OpenCode accounts..."
        for name in $accounts
            set -l acct_auth "$HOME/.opencode/accounts/$name/openai-auth.json"
            set -l login_required_file "$HOME/.opencode/accounts/$name/.login-required"
            if not test -f "$acct_auth"
                echo "  $name: missing saved auth"
                set failed (math $failed + 1)
                continue
            end

            rm -f "$login_required_file"

            set -l expires (jq -r '.expires // 0' "$acct_auth" 2>/dev/null)
            set -l now_ms (date +%s)000
            if test "$expires" -gt 0; and test "$now_ms" -le "$expires"
                echo "  $name: still valid, skipping refresh"
                set skipped (math $skipped + 1)
                continue
            end

            if opencode-accounts refresh "$name" >/dev/null
                echo "  $name: refreshed"
                set refreshed (math $refreshed + 1)
            else
                echo "  login required" >"$login_required_file"
                echo "  $name: refresh failed, fresh login required"
                set -a login_required $name
                set failed (math $failed + 1)
            end
        end
    end

    echo ""
    echo "OpenAI refresh summary: refreshed=$refreshed skipped=$skipped failed=$failed"
    if test (count $login_required) -gt 0
        echo "OpenAI accounts needing fresh login: "(string join ', ' $login_required)
        for name in $login_required
            echo "  subdash login openai $name"
        end
    end
    echo ""
    _subdash_doctor
end

function _subdash_login --description "Unified login entrypoint"
    set -l provider $argv[1]
    set -l name $argv[2]

    switch "$provider"
        case claude
            if test -z "$name"; or test "$name" = default
                command claude
            else
                claude-sub login "$name"
            end

        case openai
            if test -n "$name"
                opencode-accounts login; and opencode-accounts capture "$name"
            else
                opencode-accounts login
            end

        case ''
            echo "Usage: subdash login <claude|openai> [name]" >&2
            return 1

        case '*'
            echo "Unknown login provider: $provider" >&2
            echo "Usage: subdash login <claude|openai> [name]" >&2
            return 1
    end
end
