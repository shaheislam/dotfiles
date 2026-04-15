function opencode-accounts --description "Manage OpenCode OpenAI account profiles for rotation"
    set -l accounts_dir "$HOME/.opencode/accounts"
    set -l accounts_file "$accounts_dir/.accounts"
    set -l current_file "$accounts_dir/.current"
    set -l auth_file "$HOME/.local/share/opencode/auth.json"
    set -l usage_check "$HOME/dotfiles/scripts/opencode/usage-check.sh"

    set -l subcmd $argv[1]
    set -e argv[1]

    switch "$subcmd"
        case add
            if test (count $argv) -lt 1
                echo "Usage: opencode-accounts add <name>" >&2
                return 1
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"

            if test -d "$acct_dir"
                echo "Account '$name' already exists. Use 'opencode-accounts remove $name' first." >&2
                return 1
            end

            echo "Logging in for account '$name'..."
            echo "A browser window will open. Sign in with the OpenAI account for '$name'."
            env PATH="$HOME/dotfiles/scripts/bin:$PATH" opencode auth login --provider openai --method "ChatGPT Pro/Plus (browser)"
            if test $status -ne 0
                echo "Login failed." >&2
                return 1
            end

            # Wait briefly for auth.json to be written
            sleep 1

            if not test -f "$auth_file"
                echo "Error: auth.json not found after login." >&2
                return 1
            end

            set -l openai_entry (jq '.openai // empty' "$auth_file" 2>/dev/null)
            if test -z "$openai_entry"
                echo "Error: No OpenAI entry in auth.json after login." >&2
                return 1
            end

            mkdir -p "$acct_dir"
            jq '.openai' "$auth_file" >"$acct_dir/openai-auth.json"
            chmod 600 "$acct_dir/openai-auth.json"

            mkdir -p "$accounts_dir"
            touch "$accounts_file"
            if not grep -qx "$name" "$accounts_file" 2>/dev/null
                echo "$name" >>"$accounts_file"
            end

            _opencode_accounts_show_info "$acct_dir/openai-auth.json" "$name"
            echo "Account '$name' enrolled successfully."
            _ai_accounts_sync to-codex "$name" "$acct_dir/openai-auth.json"

        case capture
            if test (count $argv) -lt 1
                echo "Usage: opencode-accounts capture <name>" >&2
                return 1
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"

            if not test -f "$auth_file"
                echo "Error: No OpenCode auth found at $auth_file" >&2
                return 1
            end

            set -l openai_entry (jq '.openai // empty' "$auth_file" 2>/dev/null)
            if test -z "$openai_entry"
                echo "Error: No OpenAI entry in current auth.json" >&2
                return 1
            end

            mkdir -p "$accounts_dir" "$acct_dir"
            jq '.openai' "$auth_file" >"$acct_dir/openai-auth.json"
            chmod 600 "$acct_dir/openai-auth.json"

            touch "$accounts_file"
            if not grep -qx "$name" "$accounts_file" 2>/dev/null
                echo "$name" >>"$accounts_file"
            end

            _opencode_accounts_show_info "$acct_dir/openai-auth.json" "$name"
            echo "Account '$name' captured from current OpenCode session."
            _ai_accounts_sync to-codex "$name" "$acct_dir/openai-auth.json"

        case refresh
            if test (count $argv) -lt 1
                echo "Usage: opencode-accounts refresh <name>" >&2
                return 1
            end
            set -l name $argv[1]
            _opencode_refresh_profile "$name"

        case remove rm
            if test (count $argv) -lt 1
                set -l picked (_opencode_accounts_fzf_pick "Remove")
                if test -z "$picked"
                    return 1
                end
                set argv $picked
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"

            if not test -d "$acct_dir"
                echo "Account '$name' not found." >&2
                return 1
            end

            rm -rf "$acct_dir"
            if test -f "$accounts_file"
                set -l tmp (mktemp)
                grep -vx "$name" "$accounts_file" >"$tmp"
                mv "$tmp" "$accounts_file"
            end
            echo "Account '$name' removed."
            _ai_accounts_sync remove-codex "$name"

        case list ls
            if not test -f "$accounts_file"
                echo "No accounts enrolled. Use 'opencode-accounts add <name>' to add one."
                return 0
            end
            set -l current_idx 0
            if test -f "$current_file"
                set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
            end
            set -l names (cat "$accounts_file")
            echo "OpenCode accounts ("(count $names)" enrolled):"
            echo ""
            for i in (seq (count $names))
                set -l name $names[$i]
                set -l marker "  "
                if test (math $i - 1) -eq $current_idx
                    set marker "> "
                end
                set -l acct_auth "$accounts_dir/$name/openai-auth.json"
                if test -f "$acct_auth"
                    set -l info (_opencode_accounts_decode_jwt "$acct_auth")
                    echo "$marker$name: $info"
                else
                    echo "$marker$name: (auth missing)"
                end
            end

        case status
            if not test -f "$accounts_file"
                echo "No accounts enrolled."
                return 0
            end
            set -l names (cat "$accounts_file")
            set -l total (count $names)
            set -l current_idx 0
            if test -f "$current_file"
                set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
            end
            set -l next_idx (math "($current_idx + 1) % $total")
            echo "Total accounts: $total"
            echo "Last used:      $names["(math $current_idx + 1)"]"
            echo "Next up:        $names["(math $next_idx + 1)"]"
            echo ""
            # Show current active account
            if test -f "$auth_file"
                set -l current_info (_opencode_accounts_decode_jwt_from_auth "$auth_file")
                echo "Active account: $current_info"
            end

        case switch sw
            if test (count $argv) -lt 1
                set -l picked (_opencode_accounts_fzf_pick "Switch to")
                if test -z "$picked"
                    return 1
                end
                set argv $picked
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"
            set -l acct_auth "$acct_dir/openai-auth.json"

            if not test -f "$acct_auth"
                echo "Error: Account '$name' not found or missing auth." >&2
                return 1
            end

            if not test -f "$auth_file"
                echo "Error: OpenCode auth.json not found at $auth_file" >&2
                return 1
            end

            # Merge: replace only the .openai key, preserve other providers
            set -l openai_data (cat "$acct_auth")
            set -l tmp (mktemp)
            jq --argjson openai "$openai_data" '.openai = $openai' "$auth_file" >"$tmp"
            mv "$tmp" "$auth_file"

            # Update rotation pointer
            if test -f "$accounts_file"
                set -l names (cat "$accounts_file")
                for i in (seq (count $names))
                    if test "$names[$i]" = "$name"
                        echo (math $i - 1) >"$current_file"
                        break
                    end
                end
            end

            set -l info (_opencode_accounts_decode_jwt "$acct_auth")
            echo "Switched to account '$name': $info"

        case check
            # Check usage for a profile or current auth
            if test (count $argv) -lt 1; and command -q fzf; and test -f "$accounts_file"
                set -l picked (_opencode_accounts_fzf_pick "Check")
                if test -n "$picked"
                    set argv $picked
                end
            end
            set -l target_token ""
            if test (count $argv) -ge 1
                set -l name $argv[1]
                set -l acct_auth "$accounts_dir/$name/openai-auth.json"
                if not test -f "$acct_auth"
                    echo "Error: Account '$name' not found." >&2
                    return 1
                end
                set target_token (jq -r '.access // empty' "$acct_auth" 2>/dev/null)
            end

            if test -n "$target_token"
                bash "$usage_check" --token "$target_token"
            else
                bash "$usage_check"
            end
            return $status

        case check-and-rotate
            # Auto-rotation: save current, try profiles, fall back to login
            echo "Checking available accounts..." >&2

            # Auto-capture current auth if not already saved
            if test -f "$auth_file"
                set -l current_hash (jq -r '.openai.accountId // .openai.access' "$auth_file" 2>/dev/null | shasum -a 256 | string split " " | head -1)
                set -l already_saved false
                if test -f "$accounts_file"
                    for name in (cat "$accounts_file")
                        set -l acct_auth "$accounts_dir/$name/openai-auth.json"
                        if test -f "$acct_auth"
                            set -l acct_hash (jq -r '.accountId // .access' "$acct_auth" 2>/dev/null | shasum -a 256 | string split " " | head -1)
                            if test "$acct_hash" = "$current_hash"
                                set already_saved true
                                break
                            end
                        end
                    end
                end
                if not $already_saved
                    set -l auto_name "auto-"(date +%s)
                    echo "  Saving current auth as '$auto_name'..." >&2
                    mkdir -p "$accounts_dir/$auto_name"
                    jq '.openai' "$auth_file" >"$accounts_dir/$auto_name/openai-auth.json" 2>/dev/null
                    chmod 600 "$accounts_dir/$auto_name/openai-auth.json"
                    touch "$accounts_file"
                    echo "$auto_name" >>"$accounts_file"
                end
            end

            # Try each saved profile
            if test -f "$accounts_file"
                for name in (cat "$accounts_file")
                    set -l acct_auth "$accounts_dir/$name/openai-auth.json"
                    if not test -f "$acct_auth"
                        continue
                    end

                    # Check if expired and try refresh
                    set -l expires (jq -r '.expires // 0' "$acct_auth" 2>/dev/null)
                    set -l now (date +%s)"000"
                    if test "$expires" -gt 0; and test "$now" -gt "$expires"
                        echo "  Account '$name' is expired. Attempting refresh..." >&2
                        if _opencode_refresh_profile "$name" --quiet
                            echo "  Account '$name' refreshed." >&2
                        else
                            echo "  Account '$name' refresh failed." >&2
                        end
                    end

                    set -l token (jq -r '.access // empty' "$acct_auth" 2>/dev/null)
                    if test -z "$token"
                        continue
                    end
                    set -l info (_opencode_accounts_decode_jwt "$acct_auth")
                    echo "  Checking '$name' ($info)..." >&2
                    bash "$usage_check" --quiet --token "$token"
                    if test $status -eq 0
                        echo "  Account '$name' is available. Switching..." >&2
                        opencode-accounts switch "$name"
                        return 0
                    else
                        echo "  Account '$name' is rate-limited." >&2
                    end
                end
            end

            # No available profiles — fall back to login
            echo "" >&2
            echo "All saved accounts are rate-limited." >&2
            echo "Opening OpenCode login to authenticate a new account..." >&2
            echo "" >&2
            env BROWSER="$HOME/dotfiles/scripts/bin/open-url" opencode auth login --provider openai --method "ChatGPT Pro/Plus (browser)"
            if test $status -eq 0
                echo ""
                echo "Login successful. You may want to save this account:"
                echo "  opencode-accounts capture <name>"
            end

        case login
            env BROWSER="$HOME/dotfiles/scripts/bin/open-url" opencode auth login --provider openai --method "ChatGPT Pro/Plus (browser)"
            if test $status -eq 0
                echo ""
                echo "Login successful. Save this account with:"
                echo "  opencode-accounts capture <name>"
            end

        case sync-codex
            echo "Syncing opencode accounts to codex..."
            _ai_accounts_sync all --to-codex

        case help --help -h ''
            echo "Usage: opencode-accounts <command> [args]"
            echo ""
            echo "Commands:"
            echo "  add <name>            Login and save as a new profile"
            echo "  capture <name>        Save current OpenAI auth to profile"
            echo "  switch <name>         Activate a saved profile"
            echo "  remove <name>         Delete a profile"
            echo "  list                  Show all profiles"
            echo "  status                Show rotation state"
            echo "  check [<name>]        Test if a profile (or current) is rate-limited"
            echo "  check-and-rotate      Auto-rotate to an available profile"
            echo "  login                 Open OpenCode login for OpenAI"
            echo ""
            echo "Profiles stored in: $accounts_dir"

        case '*'
            echo "Unknown command: $subcmd (try 'opencode-accounts help')" >&2
            return 1
    end
end

function _opencode_accounts_decode_jwt --description "Decode OpenCode OpenAI auth to email and plan"
    set -l acct_auth $argv[1]
    python3 -c "
import json, base64
try:
    data = json.load(open('$acct_auth'))
    token = data.get('access', '')
    if not token:
        print('no token')
        raise SystemExit(0)
    payload = token.split('.')[1]
    payload += '=' * (-len(payload) % 4)
    claims = json.loads(base64.urlsafe_b64decode(payload))
    auth_meta = claims.get('https://api.openai.com/auth', {})
    profile = claims.get('https://api.openai.com/profile', {})
    email = profile.get('email') or claims.get('email') or 'unknown'
    plan = auth_meta.get('chatgpt_plan_type', 'unknown')
    user_id = auth_meta.get('chatgpt_user_id', '')
    short_id = user_id[-8:] if user_id else '?'
    print(f'{email} ({plan}, uid: ...{short_id})')
except Exception as e:
    print(f'decode error: {e}')
" 2>/dev/null; or echo "decode error"
end

function _opencode_accounts_decode_jwt_from_auth --description "Decode active auth.json OpenAI entry"
    set -l auth_file $argv[1]
    set -l tmp (mktemp)
    jq '.openai' "$auth_file" >"$tmp" 2>/dev/null
    set -l result (_opencode_accounts_decode_jwt "$tmp")
    rm -f "$tmp"
    echo "$result"
end

function _opencode_accounts_show_info --description "Display profile info after enrollment"
    set -l acct_auth $argv[1]
    set -l name $argv[2]
    set -l info (_opencode_accounts_decode_jwt "$acct_auth")
    echo "  Profile: $name"
    echo "  Account: $info"
end

function _opencode_accounts_fzf_pick --description "Interactive fzf picker for enrolled accounts"
    set -l header $argv[1]
    set -l accounts_dir "$HOME/.opencode/accounts"
    set -l accounts_file "$accounts_dir/.accounts"
    set -l current_file "$accounts_dir/.current"
    set -l auth_file "$HOME/.local/share/opencode/auth.json"

    if not command -q fzf
        echo "fzf not installed. Pass account name as argument." >&2
        return 1
    end

    if not test -f "$accounts_file"
        echo "No accounts enrolled." >&2
        return 1
    end

    set -l current_idx 0
    if test -f "$current_file"
        set current_idx (string trim (cat "$current_file"))
    end

    set -l lines
    set -l idx 0
    for name in (cat "$accounts_file")
        set -l acct_auth "$accounts_dir/$name/openai-auth.json"
        set -l info ""
        if test -f "$acct_auth"
            set info (_opencode_accounts_decode_jwt "$acct_auth")
        end
        set -l marker "  "
        if test "$idx" = "$current_idx"
            set marker "> "
        end
        set -a lines "$marker$name\t$info"
        set idx (math $idx + 1)
    end

    set -l picked (printf '%s\n' $lines | fzf --ansi --header="$header account:" --delimiter='\t' --with-nth=1,2 --no-sort | string trim)
    if test -z "$picked"
        return 1
    end

    # Extract just the account name (strip marker, take first column)
    echo $picked | string replace -r '^\s*>\s*' '' | string replace -r '\t.*' '' | string trim
end

function _opencode_refresh_profile --description "Refresh an OpenAI profile using its refresh_token"
    set -l name $argv[1]
    set -l quiet false
    if test "$argv[2]" = --quiet
        set quiet true
    end

    set -l accounts_dir "$HOME/.opencode/accounts"
    set -l acct_dir "$accounts_dir/$name"
    set -l acct_auth "$acct_dir/openai-auth.json"
    set -l refresh_script "$HOME/dotfiles/scripts/opencode/refresh-token.sh"

    if not test -f "$acct_auth"
        if not $quiet
            echo "Error: Profile '$name' not found." >&2
        end
        return 1
    end

    set -l refresh_token (jq -r '.refresh // empty' "$acct_auth" 2>/dev/null)
    if test -z "$refresh_token"
        if not $quiet
            echo "Error: Profile '$name' has no refresh token." >&2
        end
        return 1
    end

    if not $quiet
        echo "Refreshing profile '$name'..." >&2
    end
    set -l refresh_args --token "$refresh_token"
    if $quiet
        set -a refresh_args --quiet
    end

    set -l new_auth (bash "$refresh_script" $refresh_args)
    if test $status -ne 0
        if not $quiet
            echo "Error: Refresh failed for '$name'." >&2
        end
        return 1
    end

    # Save new auth and sync to codex
    echo "$new_auth" >"$acct_auth"
    chmod 600 "$acct_auth"
    _ai_accounts_sync to-codex "$name" "$acct_auth"

    if not $quiet
        echo "Profile '$name' refreshed successfully." >&2
    end
    return 0
end
