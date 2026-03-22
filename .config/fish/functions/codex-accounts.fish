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

        case 1p-push
            # Push a local account to 1Password
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            if test (count $argv) -lt 1
                echo "Usage: codex-accounts 1p-push <name> [--vault VAULT]" >&2
                return 1
            end
            set -l name $argv[1]
            set -l vault Private
            if test (count $argv) -ge 3; and test "$argv[2]" = --vault
                set vault $argv[3]
            end
            set -l acct_auth "$accounts_dir/$name/auth.json"
            if not test -f "$acct_auth"
                echo "Error: Local account '$name' not found (no auth.json)." >&2
                return 1
            end

            set -l auth_content (cat "$acct_auth")
            set -l info (_codex_accounts_decode_jwt "$acct_auth")
            set -l email (string split " (" -- $info | head -1)
            set -l plan (string split " (" -- $info | tail -1 | string trim --chars=")")

            set -l item_title "Codex: $name"

            # Check if item already exists
            if op item get "$item_title" --vault "$vault" >/dev/null 2>&1
                # Update existing item
                op item edit "$item_title" --vault "$vault" \
                    "auth_json[password]=$auth_content" \
                    "email[text]=$email" \
                    "plan[text]=$plan" >/dev/null
                echo "Updated '$name' in 1Password (vault: $vault)"
            else
                # Create new item
                op item create --category "Secure Note" \
                    --title "$item_title" \
                    --vault "$vault" \
                    --tags codex-account \
                    "auth_json[password]=$auth_content" \
                    "email[text]=$email" \
                    "plan[text]=$plan" >/dev/null
                echo "Pushed '$name' to 1Password (vault: $vault)"
            end

        case 1p-pull
            # Pull account(s) from 1Password to local
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l vault Private
            set -l target_name ""
            set -l i 1
            while test $i -le (count $argv)
                switch $argv[$i]
                    case --vault
                        set i (math $i + 1)
                        set vault $argv[$i]
                    case '*'
                        set target_name $argv[$i]
                end
                set i (math $i + 1)
            end

            if test -n "$target_name"
                # Pull a single account (use --format=json to avoid CSV-escaping)
                set -l item_title "Codex: $target_name"
                set -l item_json (op item get "$item_title" --vault "$vault" --format=json --reveal 2>/dev/null)
                if test -z "$item_json"
                    echo "Error: Account '$target_name' not found in 1Password (vault: $vault)." >&2
                    return 1
                end
                set -l auth_json (echo "$item_json" | python3 -c "
import json, sys
item = json.load(sys.stdin)
for f in item.get('fields', []):
    if f.get('label') == 'auth_json':
        # Re-serialize to get proper JSON formatting
        print(json.dumps(json.loads(f['value']), indent=2))
        break
" 2>/dev/null)
                if test -z "$auth_json"
                    echo "Error: Could not extract auth data for '$target_name'." >&2
                    return 1
                end
                mkdir -p "$accounts_dir/$target_name"
                echo "$auth_json" >"$accounts_dir/$target_name/auth.json"
                # Ensure account is in the roster
                mkdir -p "$accounts_dir"
                touch "$accounts_file"
                if not grep -qx "$target_name" "$accounts_file" 2>/dev/null
                    echo "$target_name" >>"$accounts_file"
                end
                set -l info (_codex_accounts_decode_jwt "$accounts_dir/$target_name/auth.json")
                echo "Pulled '$target_name': $info"
            else
                # Pull all codex accounts from 1Password
                set -l items (op item list --tags codex-account --vault "$vault" --format=json 2>/dev/null)
                if test -z "$items"
                    echo "No codex accounts found in 1Password (vault: $vault)."
                    return 0
                end
                set -l pulled 0
                for item_id in (echo "$items" | python3 -c "import json,sys; [print(i['id']) for i in json.load(sys.stdin)]" 2>/dev/null)
                    set -l item_json (op item get "$item_id" --vault "$vault" --format=json --reveal 2>/dev/null)
                    if test -z "$item_json"
                        continue
                    end
                    # Extract name from title "Codex: <name>"
                    set -l acct_name (echo "$item_json" | python3 -c "
import json, sys
item = json.load(sys.stdin)
title = item.get('title', '')
if title.startswith('Codex: '):
    print(title[7:])
else:
    print(title)
" 2>/dev/null)
                    if test -z "$acct_name"
                        continue
                    end
                    # Extract auth_json field and re-serialize for proper formatting
                    set -l auth_json (echo "$item_json" | python3 -c "
import json, sys
item = json.load(sys.stdin)
for f in item.get('fields', []):
    if f.get('label') == 'auth_json':
        print(json.dumps(json.loads(f['value']), indent=2))
        break
" 2>/dev/null)
                    if test -z "$auth_json"
                        continue
                    end
                    mkdir -p "$accounts_dir/$acct_name"
                    echo "$auth_json" >"$accounts_dir/$acct_name/auth.json"
                    mkdir -p "$accounts_dir"
                    touch "$accounts_file"
                    if not grep -qx "$acct_name" "$accounts_file" 2>/dev/null
                        echo "$acct_name" >>"$accounts_file"
                    end
                    set -l info (_codex_accounts_decode_jwt "$accounts_dir/$acct_name/auth.json")
                    echo "  Pulled '$acct_name': $info"
                    set pulled (math $pulled + 1)
                end
                echo "Pulled $pulled account(s) from 1Password (vault: $vault)"
            end

        case 1p-list
            # List codex accounts in 1Password
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l vault Private
            if test (count $argv) -ge 2; and test "$argv[1]" = --vault
                set vault $argv[2]
            end
            set -l items (op item list --tags codex-account --vault "$vault" --format=json 2>/dev/null)
            if test -z "$items"; or test "$items" = "[]"
                echo "No codex accounts in 1Password (vault: $vault)."
                return 0
            end
            echo "Codex accounts in 1Password (vault: $vault):"
            echo ""
            echo "$items" | python3 -c "
import json, sys
items = json.load(sys.stdin)
for item in items:
    title = item.get('title', 'unknown')
    name = title[7:] if title.startswith('Codex: ') else title
    updated = item.get('updated_at', 'unknown')[:10]
    print(f'  {name} (updated: {updated})')
" 2>/dev/null

        case 1p-sync
            # Push all local accounts to 1Password, then pull any remote-only accounts
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l vault Private
            if test (count $argv) -ge 2; and test "$argv[1]" = --vault
                set vault $argv[2]
            end

            # Phase 1: Push local accounts
            if test -f "$accounts_file"
                set -l names (cat "$accounts_file")
                for name in $names
                    if test -f "$accounts_dir/$name/auth.json"
                        echo "Pushing '$name'..."
                        codex-accounts 1p-push "$name" --vault "$vault"
                    end
                end
            end

            # Phase 2: Pull remote accounts not present locally
            set -l items (op item list --tags codex-account --vault "$vault" --format=json 2>/dev/null)
            if test -n "$items"; and test "$items" != "[]"
                for acct_name in (echo "$items" | python3 -c "
import json, sys
items = json.load(sys.stdin)
for item in items:
    title = item.get('title', '')
    name = title[7:] if title.startswith('Codex: ') else title
    print(name)
" 2>/dev/null)
                    if not test -d "$accounts_dir/$acct_name"
                        echo "Pulling '$acct_name' (remote-only)..."
                        codex-accounts 1p-pull "$acct_name" --vault "$vault"
                    end
                end
            end
            echo "Sync complete."

        case '*'
            echo "Usage: codex-accounts <command> [args]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  add <name>        Enroll a new account (opens browser login)" >&2
            echo "  remove <name>     Remove an enrolled account" >&2
            echo "  list              Show all enrolled accounts" >&2
            echo "  status            Show rotation state" >&2
            echo "" >&2
            echo "1Password:" >&2
            echo "  1p-push <name>    Push account to 1Password" >&2
            echo "  1p-pull [name]    Pull account(s) from 1Password" >&2
            echo "  1p-list           List accounts in 1Password" >&2
            echo "  1p-sync           Sync local <-> 1Password" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  --vault VAULT     1Password vault (default: Private)" >&2
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
