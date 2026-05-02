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
            # Optional name arg is treated as a sanity-check; canonical name is derived from auth.
            set -l requested_name ""
            if test (count $argv) -ge 1
                set requested_name $argv[1]
            end

            echo "Logging in for OpenCode/OpenAI..."
            echo "A browser window will open. Sign in with the OpenAI account you want to enroll."
            bash "$HOME/dotfiles/scripts/opencode/auth-login-autoopen.sh"
            if test $status -ne 0
                echo "Login failed." >&2
                return 1
            end

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

            set -l name (_ai_accounts_canonical_name "$auth_file")
            if test -z "$name"
                echo "Error: Could not derive canonical name from auth (missing email claim)." >&2
                return 1
            end

            if test -n "$requested_name"; and test "$requested_name" != "$name"
                echo "Error: Logged-in account is '$name', not '$requested_name'." >&2
                echo "Profile names are derived from the account email — re-run as 'opencode-accounts add' (no name) or 'opencode-accounts add $name'." >&2
                return 1
            end

            set -l acct_dir "$accounts_dir/$name"
            set -l login_required_file "$acct_dir/.login-required"

            if test -d "$acct_dir"
                echo "Account '$name' already enrolled — refreshing its auth from the new login."
            end

            mkdir -p "$acct_dir"
            jq '.openai' "$auth_file" >"$acct_dir/openai-auth.json"
            chmod 600 "$acct_dir/openai-auth.json"
            rm -f "$login_required_file"

            mkdir -p "$accounts_dir"
            touch "$accounts_file"
            if not grep -qx "$name" "$accounts_file" 2>/dev/null
                echo "$name" >>"$accounts_file"
            end

            _opencode_accounts_show_info "$acct_dir/openai-auth.json" "$name"
            echo "Account '$name' enrolled successfully."
            _ai_accounts_sync to-codex "$name" "$acct_dir/openai-auth.json"

        case capture
            if not test -f "$auth_file"
                echo "Error: No OpenCode auth found at $auth_file" >&2
                return 1
            end

            set -l openai_entry (jq '.openai // empty' "$auth_file" 2>/dev/null)
            if test -z "$openai_entry"
                echo "Error: No OpenAI entry in current auth.json" >&2
                return 1
            end

            set -l requested_name ""
            if test (count $argv) -ge 1
                set requested_name $argv[1]
            end

            set -l name (_ai_accounts_canonical_name "$auth_file")
            if test -z "$name"
                echo "Error: Could not derive canonical name from auth (missing email claim)." >&2
                return 1
            end

            if test -n "$requested_name"; and test "$requested_name" != "$name"
                echo "Error: Current OpenCode session belongs to '$name', not '$requested_name'." >&2
                echo "Profile names are derived from the account email — re-run as 'opencode-accounts capture' (no name) or 'opencode-accounts capture $name'." >&2
                return 1
            end

            set -l acct_dir "$accounts_dir/$name"
            set -l login_required_file "$acct_dir/.login-required"

            mkdir -p "$accounts_dir" "$acct_dir"
            jq '.openai' "$auth_file" >"$acct_dir/openai-auth.json"
            chmod 600 "$acct_dir/openai-auth.json"
            rm -f "$login_required_file"

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
            # Use --slurpfile to read directly from file — avoids fish splitting multi-line JSON
            set -l tmp (mktemp)
            if not jq --slurpfile openai "$acct_auth" '.openai = $openai[0]' "$auth_file" >"$tmp"
                rm -f "$tmp"
                echo "Error: failed to merge auth for '$name'" >&2
                return 1
            end
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

            # Probe current account first — only rotate if it's actually rate-limited
            if test -f "$auth_file"
                set -l current_token (jq -r '.openai.access // empty' "$auth_file" 2>/dev/null)
                if test -n "$current_token"
                    bash "$usage_check" --quiet --token "$current_token"
                    if test $status -eq 0
                        return 0
                    end
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
            bash "$HOME/dotfiles/scripts/opencode/auth-login-autoopen.sh"
            if test $status -eq 0
                echo ""
                echo "Login successful. You may want to save this account:"
                echo "  opencode-accounts capture <name>"
            end

        case login
            bash "$HOME/dotfiles/scripts/opencode/auth-login-autoopen.sh"
            if test $status -eq 0
                echo ""
                echo "Login successful. Save this account with:"
                echo "  opencode-accounts capture <name>"
            end

        case sync-codex
            echo "Syncing opencode accounts to codex..."
            _ai_accounts_sync all --to-codex

        case dedupe
            _opencode_accounts_dedupe

        case help --help -h ''
            echo "Usage: opencode-accounts <command> [args]"
            echo ""
            echo "Profile names are derived from the OpenAI account email (local-part)."
            echo ""
            echo "Commands:"
            echo "  add [<name>]          Login and save as a profile (name auto-derived)"
            echo "  capture [<name>]      Save current OpenAI auth to profile"
            echo "  switch <name>         Activate a saved profile"
            echo "  remove <name>         Delete a profile"
            echo "  list                  Show all profiles"
            echo "  status                Show rotation state"
            echo "  check [<name>]        Test if a profile (or current) is rate-limited"
            echo "  check-and-rotate      Auto-rotate to an available profile"
            echo "  login                 Open OpenCode login for OpenAI"
            echo "  dedupe                Rename/remove profiles to canonical email-derived names"
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

function _opencode_accounts_identity --description "Return stable OpenAI account identity"
    set -l auth_json $argv[1]
    python3 -c "import base64, json; data=json.load(open('$auth_json')); data=data.get('openai', data) if isinstance(data, dict) else data; token=data.get('access','') if isinstance(data, dict) else ''; account_id=data.get('accountId','') if isinstance(data, dict) else ''; email='';
if token:
    payload=token.split('.')[1]; payload += '=' * (-len(payload) % 4); claims=json.loads(base64.urlsafe_b64decode(payload)); auth_meta=claims.get('https://api.openai.com/auth', {}); profile=claims.get('https://api.openai.com/profile', {}); account_id=account_id or auth_meta.get('chatgpt_account_id') or ''; email=profile.get('email') or claims.get('email') or ''
print('|'.join([part for part in (account_id, email) if part]))" 2>/dev/null
end

function _opencode_accounts_find_matching_profile --description "Find another saved profile with same OpenAI identity"
    set -l source_auth $argv[1]
    set -l skip_name $argv[2]
    set -l accounts_dir "$HOME/.opencode/accounts"
    set -l accounts_file "$accounts_dir/.accounts"

    if not test -f "$accounts_file"
        return 0
    end

    set -l source_identity (_opencode_accounts_identity "$source_auth")
    if test -z "$source_identity"
        return 0
    end

    for existing_name in (cat "$accounts_file")
        if test -n "$skip_name"; and test "$existing_name" = "$skip_name"
            continue
        end

        set -l existing_auth "$accounts_dir/$existing_name/openai-auth.json"
        if not test -f "$existing_auth"
            continue
        end

        if test "$source_identity" = (_opencode_accounts_identity "$existing_auth")
            echo "$existing_name"
            return 0
        end
    end
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

function _opencode_accounts_dedupe --description "Rename profiles to canonical email-derived names; remove identity duplicates"
    set -l accounts_dir "$HOME/.opencode/accounts"
    set -l accounts_file "$accounts_dir/.accounts"

    if not test -f "$accounts_file"
        echo "No opencode profiles to dedupe."
        return 0
    end

    set -l renamed 0
    set -l removed 0

    # Pass 1: rename non-canonical to canonical when slot is free
    for name in (cat "$accounts_file")
        set -l auth "$accounts_dir/$name/openai-auth.json"
        if not test -f "$auth"
            continue
        end
        set -l canonical (_ai_accounts_canonical_name "$auth")
        if test -z "$canonical"; or test "$canonical" = "$name"
            continue
        end

        set -l canonical_dir "$accounts_dir/$canonical"
        if test -d "$canonical_dir"
            # Canonical slot is taken — leave for pass 2 to resolve as duplicate
            continue
        end

        echo "  Renaming '$name' -> '$canonical'"
        mv "$accounts_dir/$name" "$canonical_dir"
        # Update accounts list
        set -l tmp (mktemp)
        sed "s|^$name\$|$canonical|" "$accounts_file" >"$tmp"
        mv "$tmp" "$accounts_file"
        # Cross-sync: rename codex side too
        _ai_accounts_sync remove-codex "$name" >/dev/null 2>&1
        _ai_accounts_sync to-codex "$canonical" "$canonical_dir/openai-auth.json" >/dev/null 2>&1
        set renamed (math $renamed + 1)
    end

    # Pass 2: drop profiles whose canonical name is already enrolled under a different (canonical) name
    for name in (cat "$accounts_file")
        set -l auth "$accounts_dir/$name/openai-auth.json"
        if not test -f "$auth"
            continue
        end
        set -l canonical (_ai_accounts_canonical_name "$auth")
        if test -z "$canonical"; or test "$canonical" = "$name"
            continue
        end
        set -l canonical_dir "$accounts_dir/$canonical"
        if not test -d "$canonical_dir"
            continue
        end

        echo "  Removing duplicate '$name' (identity matches '$canonical')"
        rm -rf "$accounts_dir/$name"
        set -l tmp (mktemp)
        grep -vx "$name" "$accounts_file" >"$tmp"
        mv "$tmp" "$accounts_file"
        _ai_accounts_sync remove-codex "$name" >/dev/null 2>&1
        set removed (math $removed + 1)
    end

    echo "Dedupe complete: renamed=$renamed removed=$removed"
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
