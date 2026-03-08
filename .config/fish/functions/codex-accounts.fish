function codex-accounts --description "Manage Codex CLI OAuth account profiles for rotation"
    set -l accounts_dir "$HOME/.codex/accounts"
    set -l accounts_file "$accounts_dir/.accounts"
    set -l current_file "$accounts_dir/.current"

    set -l subcmd $argv[1]
    set -e argv[1]

    switch "$subcmd"
        case add
            # Usage: codex-accounts add <name>
            if test (count $argv) -lt 1
                echo "Usage: codex-accounts add <name>" >&2
                return 1
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"

            if test -d "$acct_dir"
                echo "Account '$name' already exists. Use 'codex-accounts remove $name' first." >&2
                return 1
            end

            # Run codex login (opens browser OAuth flow)
            echo "Logging in for account '$name'..."
            echo "A browser window will open. Sign in with the account you want to use for '$name'."
            codex logout 2>/dev/null
            codex login
            if test $status -ne 0
                echo "Login failed." >&2
                return 1
            end

            # Copy auth.json to profile directory
            mkdir -p "$acct_dir"
            cp "$HOME/.codex/auth.json" "$acct_dir/auth.json"

            # Append to accounts list (if not already present)
            mkdir -p "$accounts_dir"
            touch "$accounts_file"
            if not grep -qx "$name" "$accounts_file" 2>/dev/null
                echo "$name" >>"$accounts_file"
            end

            # Show confirmation with decoded JWT info
            _codex_accounts_show_info "$acct_dir/auth.json" "$name"
            echo "Account '$name' enrolled successfully."

        case remove rm
            if test (count $argv) -lt 1
                echo "Usage: codex-accounts remove <name>" >&2
                return 1
            end
            set -l name $argv[1]
            set -l acct_dir "$accounts_dir/$name"

            if not test -d "$acct_dir"
                echo "Account '$name' not found." >&2
                return 1
            end

            rm -rf "$acct_dir"
            # Remove from accounts list
            if test -f "$accounts_file"
                set -l tmp (mktemp)
                grep -vx "$name" "$accounts_file" >"$tmp"
                mv "$tmp" "$accounts_file"
            end
            echo "Account '$name' removed."

        case list ls
            if not test -f "$accounts_file"
                echo "No accounts enrolled. Use 'codex-accounts add <name>' to add one."
                return 0
            end
            set -l current_idx 0
            if test -f "$current_file"
                set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
            end
            set -l names (cat "$accounts_file")
            set -l count (count $names)
            echo "Codex accounts ($count enrolled):"
            echo ""
            for i in (seq (count $names))
                set -l name $names[$i]
                set -l marker "  "
                # .current is 0-indexed, fish seq is 1-indexed
                if test (math $i - 1) -eq $current_idx
                    set marker "> "
                end
                set -l auth_file "$accounts_dir/$name/auth.json"
                if test -f "$auth_file"
                    set -l info (_codex_accounts_decode_jwt "$auth_file")
                    echo "$marker$name: $info"
                else
                    echo "$marker$name: (auth.json missing)"
                end
            end

        case status
            if not test -f "$accounts_file"
                echo "No accounts enrolled."
                return 0
            end
            set -l names (cat "$accounts_file")
            set -l current_idx 0
            if test -f "$current_file"
                set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
            end
            set -l next_idx (math "($current_idx + 1) % "(count $names))
            echo "Total accounts: "(count $names)
            echo "Last used:      $names["(math $current_idx + 1)"]"
            echo "Next up:        $names["(math $next_idx + 1)"]"

        case '*'
            echo "Usage: codex-accounts <add|remove|list|status> [args]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  add <name>      Enroll a new account (opens browser login)" >&2
            echo "  remove <name>   Remove an enrolled account" >&2
            echo "  list            Show all enrolled accounts" >&2
            echo "  status          Show rotation state" >&2
            return 1
    end
end

function _codex_accounts_decode_jwt --description "Decode JWT from auth.json to extract email and plan"
    set -l auth_file $argv[1]
    python3 -c "
import json, base64, sys
auth = json.load(open('$auth_file'))
token = auth.get('tokens', {}).get('id_token', '')
if not token:
    print('no id_token')
    sys.exit(0)
payload = token.split('.')[1]
payload += '=' * (4 - len(payload) % 4)
data = json.loads(base64.urlsafe_b64decode(payload))
email = data.get('email', 'unknown')
plan = data.get('https://api.openai.com/auth', {}).get('chatgpt_plan_type', 'unknown')
print(f'{email} ({plan})')
" 2>/dev/null; or echo "decode error"
end

function _codex_accounts_show_info --description "Display account info from auth.json"
    set -l auth_file $argv[1]
    set -l name $argv[2]
    set -l info (_codex_accounts_decode_jwt "$auth_file")
    echo "  Account: $name"
    echo "  Details: $info"
end
