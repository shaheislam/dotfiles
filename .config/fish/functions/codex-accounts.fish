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
            # Push a local account to 1Password via temp file (no secrets in CLI args)
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l name ""
            set -l vault Private
            set -l force false
            set -l i 1
            while test $i -le (count $argv)
                switch $argv[$i]
                    case --vault
                        set i (math $i + 1)
                        set vault $argv[$i]
                    case --force
                        set force true
                    case '*'
                        set name $argv[$i]
                end
                set i (math $i + 1)
            end
            if test -z "$name"
                echo "Usage: codex-accounts 1p-push <name> [--vault VAULT] [--force]" >&2
                return 1
            end
            set -l acct_auth "$accounts_dir/$name/auth.json"
            if not test -f "$acct_auth"
                echo "Error: Local account '$name' not found (no auth.json)." >&2
                return 1
            end

            # Validate local auth.json structure before pushing
            if not _codex_accounts_validate_auth "$acct_auth"
                echo "Error: Local auth.json for '$name' is invalid." >&2
                return 1
            end

            set -l meta_file "$accounts_dir/$name/.1p-meta"
            set -l local_hash (_codex_accounts_hash "$acct_auth")
            set -l info (_codex_accounts_decode_jwt "$acct_auth")
            set -l email (string split " (" -- $info | head -1)
            set -l plan (string split " (" -- $info | tail -1 | string trim --chars=")")

            # Check if item already exists (by stored ID or title lookup)
            set -l item_id (_codex_accounts_get_item_id "$name" "$meta_file" "$vault")

            if test -n "$item_id"
                # Conflict detection: check if remote changed since last sync
                if test "$force" = false; and test -f "$meta_file"
                    set -l stored_hash (grep "^content_hash=" "$meta_file" 2>/dev/null | string replace "content_hash=" "")
                    if test -n "$stored_hash"; and test "$stored_hash" != "$local_hash"
                        # Local changed. Check if remote also changed.
                        set -l remote_updated (op item get "$item_id" --vault "$vault" --format=json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('updated_at',''))" 2>/dev/null)
                        set -l stored_updated (grep "^remote_updated=" "$meta_file" 2>/dev/null | string replace "remote_updated=" "")
                        if test -n "$stored_updated"; and test -n "$remote_updated"; and test "$remote_updated" != "$stored_updated"
                            echo "Conflict: Both local and remote changed for '$name' since last sync." >&2
                            echo "  Local hash:     $local_hash (was: $stored_hash)" >&2
                            echo "  Remote updated: $remote_updated (was: $stored_updated)" >&2
                            echo "  Use --force to overwrite remote." >&2
                            return 1
                        end
                    end
                end

                # Update existing item via temp template file
                set -l result (_codex_accounts_op_update "$item_id" "$vault" "$acct_auth" "$email" "$plan")
                if test $status -ne 0
                    echo "Error: Failed to update '$name' in 1Password." >&2
                    return 1
                end
                # Refresh remote updated_at after our push
                set -l new_updated (op item get "$item_id" --vault "$vault" --format=json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('updated_at',''))" 2>/dev/null)
                _codex_accounts_write_meta "$meta_file" "$item_id" "$local_hash" "$new_updated"
                echo "Updated '$name' in 1Password (vault: $vault)"
            else
                # Create new item via temp template file
                set -l new_id (_codex_accounts_op_create "$name" "$vault" "$acct_auth" "$email" "$plan")
                if test $status -ne 0; or test -z "$new_id"
                    echo "Error: Failed to create '$name' in 1Password." >&2
                    return 1
                end
                set -l new_updated (op item get "$new_id" --vault "$vault" --format=json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('updated_at',''))" 2>/dev/null)
                _codex_accounts_write_meta "$meta_file" "$new_id" "$local_hash" "$new_updated"
                echo "Pushed '$name' to 1Password (vault: $vault, id: $new_id)"
            end

        case 1p-pull
            # Pull account(s) from 1Password to local
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l vault Private
            set -l target_name ""
            set -l force false
            set -l i 1
            while test $i -le (count $argv)
                switch $argv[$i]
                    case --vault
                        set i (math $i + 1)
                        set vault $argv[$i]
                    case --force
                        set force true
                    case '*'
                        set target_name $argv[$i]
                end
                set i (math $i + 1)
            end

            if test -n "$target_name"
                # Pull a single account
                _codex_accounts_pull_one "$target_name" "$vault" "$force" "$accounts_dir" "$accounts_file"
            else
                # Pull all codex accounts from 1Password
                set -l items (op item list --tags codex-account --vault "$vault" --format=json 2>/dev/null)
                if test -z "$items"; or test "$items" = "[]"
                    echo "No codex accounts found in 1Password (vault: $vault)."
                    return 0
                end
                set -l pulled 0
                for acct_name in (echo "$items" | python3 -c "
import json, sys
for i in json.load(sys.stdin):
    t = i.get('title', '')
    print(t[7:] if t.startswith('Codex: ') else t)
" 2>/dev/null)
                    if _codex_accounts_pull_one "$acct_name" "$vault" "$force" "$accounts_dir" "$accounts_file"
                        set pulled (math $pulled + 1)
                    end
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
    item_id = item.get('id', '?')[:8]
    print(f'  {name} (updated: {updated}, id: {item_id}...)')
" 2>/dev/null

        case 1p-sync
            # Local-first sync: push local accounts, then pull remote-only accounts.
            # Does NOT overwrite existing accounts in either direction without --force.
            if not command -q op
                echo "Error: 1Password CLI (op) not found. Install with: brew install 1password-cli" >&2
                return 1
            end
            set -l vault Private
            set -l force false
            set -l i 1
            while test $i -le (count $argv)
                switch $argv[$i]
                    case --vault
                        set i (math $i + 1)
                        set vault $argv[$i]
                    case --force
                        set force true
                    case '*'
                        true
                end
                set i (math $i + 1)
            end

            set -l force_flag
            if test "$force" = true
                set force_flag --force
            end

            # Phase 1: Push local accounts (with conflict detection)
            set -l push_count 0
            set -l push_skipped 0
            if test -f "$accounts_file"
                set -l names (cat "$accounts_file")
                for name in $names
                    if test -f "$accounts_dir/$name/auth.json"
                        codex-accounts 1p-push "$name" --vault "$vault" $force_flag >/dev/null
                        if test $status -eq 0
                            set push_count (math $push_count + 1)
                        else
                            set push_skipped (math $push_skipped + 1)
                            echo "  Skipped push '$name' (conflict or error)" >&2
                        end
                    end
                end
            end

            # Phase 2: Pull remote-only accounts (never overwrites existing local)
            set -l pull_count 0
            set -l items (op item list --tags codex-account --vault "$vault" --format=json 2>/dev/null)
            if test -n "$items"; and test "$items" != "[]"
                for acct_name in (echo "$items" | python3 -c "
import json, sys
for i in json.load(sys.stdin):
    t = i.get('title', '')
    print(t[7:] if t.startswith('Codex: ') else t)
" 2>/dev/null)
                    if not test -d "$accounts_dir/$acct_name"
                        codex-accounts 1p-pull "$acct_name" --vault "$vault" >/dev/null
                        if test $status -eq 0
                            set pull_count (math $pull_count + 1)
                        end
                    end
                end
            end
            echo "Sync complete: pushed $push_count, pulled $pull_count, skipped $push_skipped"

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
            echo "  1p-sync           Local-first sync (push local, pull remote-only)" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  --vault VAULT     1Password vault (default: Private)" >&2
            echo "  --force           Overwrite on conflict (for push/pull/sync)" >&2
            return 1
    end
end

# --- Helper functions ---

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

function _codex_accounts_validate_auth --description "Validate auth.json has expected structure"
    set -l auth_file $argv[1]
    python3 -c "
import json, sys
try:
    auth = json.load(open('$auth_file'))
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(f'Invalid JSON: {e}', file=sys.stderr)
    sys.exit(1)
tokens = auth.get('tokens', {})
if not isinstance(tokens, dict):
    print('Missing or invalid tokens object', file=sys.stderr)
    sys.exit(1)
required = ['access_token', 'refresh_token']
missing = [k for k in required if not tokens.get(k)]
if missing:
    print(f'Missing token fields: {missing}', file=sys.stderr)
    sys.exit(1)
# Check size (auth.json should be < 50KB)
import os
size = os.path.getsize('$auth_file')
if size > 50000:
    print(f'auth.json too large ({size} bytes, max 50000)', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
    return $status
end

function _codex_accounts_hash --description "SHA256 hash of file content"
    shasum -a 256 $argv[1] 2>/dev/null | string split " " | head -1
end

function _codex_accounts_write_meta --description "Write .1p-meta file for conflict tracking"
    set -l meta_file $argv[1]
    set -l item_id $argv[2]
    set -l content_hash $argv[3]
    set -l remote_updated $argv[4]
    mkdir -p (dirname "$meta_file")
    printf "item_id=%s\ncontent_hash=%s\nremote_updated=%s\nlast_sync=%s\n" \
        "$item_id" "$content_hash" "$remote_updated" (date -u +%Y-%m-%dT%H:%M:%SZ) >"$meta_file"
    chmod 600 "$meta_file"
end

function _codex_accounts_get_item_id --description "Get 1Password item ID from meta file or title lookup"
    set -l name $argv[1]
    set -l meta_file $argv[2]
    set -l vault $argv[3]

    # Prefer stored ID from meta file
    if test -f "$meta_file"
        set -l stored_id (grep "^item_id=" "$meta_file" 2>/dev/null | string replace "item_id=" "")
        if test -n "$stored_id"
            # Verify it still exists
            if op item get "$stored_id" --vault "$vault" >/dev/null 2>&1
                echo "$stored_id"
                return 0
            end
        end
    end

    # Fallback: lookup by title
    set -l item_title "Codex: $name"
    set -l found_id (op item get "$item_title" --vault "$vault" --format=json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    if test -n "$found_id"
        echo "$found_id"
        return 0
    end

    return 1
end

function _codex_accounts_op_create --description "Create 1Password item via template file (no secrets in CLI args)"
    set -l name $argv[1]
    set -l vault $argv[2]
    set -l auth_file $argv[3]
    set -l email $argv[4]
    set -l plan $argv[5]

    set -l template (mktemp)
    chmod 600 "$template"

    python3 -c "
import json, sys
auth_content = open('$auth_file').read().strip()
template = {
    'title': 'Codex: $name',
    'category': 'SECURE_NOTE',
    'tags': ['codex-account'],
    'fields': [
        {'id': 'auth_json', 'label': 'auth_json', 'type': 'CONCEALED', 'value': auth_content},
        {'id': 'email', 'label': 'email', 'type': 'STRING', 'value': '$email'},
        {'id': 'plan', 'label': 'plan', 'type': 'STRING', 'value': '$plan'}
    ]
}
json.dump(template, open('$template', 'w'))
" 2>/dev/null

    set -l result (op item create --vault "$vault" --template "$template" --format=json 2>/dev/null)
    set -l op_status $status
    rm -f "$template"

    if test $op_status -ne 0
        return 1
    end

    # Return the new item ID
    echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
end

function _codex_accounts_op_update --description "Update 1Password item via template file (no secrets in CLI args)"
    set -l item_id $argv[1]
    set -l vault $argv[2]
    set -l auth_file $argv[3]
    set -l email $argv[4]
    set -l plan $argv[5]

    # Build a template with updated fields, write to temp file with restrictive perms
    set -l template (mktemp)
    chmod 600 "$template"

    python3 -c "
import json
auth_content = open('$auth_file').read().strip()
template = {
    'fields': [
        {'id': 'auth_json', 'label': 'auth_json', 'type': 'CONCEALED', 'value': auth_content},
        {'id': 'email', 'label': 'email', 'type': 'STRING', 'value': '$email'},
        {'id': 'plan', 'label': 'plan', 'type': 'STRING', 'value': '$plan'}
    ]
}
json.dump(template, open('$template', 'w'))
" 2>/dev/null

    op item edit "$item_id" --vault "$vault" --template "$template" >/dev/null 2>&1
    set -l op_status $status
    rm -f "$template"
    return $op_status
end

function _codex_accounts_pull_one --description "Pull a single account from 1Password with validation"
    set -l target_name $argv[1]
    set -l vault $argv[2]
    set -l force $argv[3]
    set -l accounts_dir $argv[4]
    set -l accounts_file $argv[5]

    set -l meta_file "$accounts_dir/$target_name/.1p-meta"

    # Resolve item ID
    set -l item_id (_codex_accounts_get_item_id "$target_name" "$meta_file" "$vault")
    set -l item_json ""

    if test -n "$item_id"
        set item_json (op item get "$item_id" --vault "$vault" --format=json --reveal 2>/dev/null)
    else
        # Fallback to title lookup
        set item_json (op item get "Codex: $target_name" --vault "$vault" --format=json --reveal 2>/dev/null)
    end

    if test -z "$item_json"
        echo "Error: Account '$target_name' not found in 1Password (vault: $vault)." >&2
        return 1
    end

    # Extract item ID if we don't have it
    if test -z "$item_id"
        set item_id (echo "$item_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    end

    # Extract and validate auth_json
    set -l auth_json (echo "$item_json" | python3 -c "
import json, sys
item = json.load(sys.stdin)
for f in item.get('fields', []):
    if f.get('label') == 'auth_json':
        raw = f.get('value', '')
        # Validate it's parseable JSON with expected structure
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f'INVALID: {e}', file=sys.stderr)
            sys.exit(1)
        tokens = parsed.get('tokens', {})
        if not isinstance(tokens, dict) or not tokens.get('access_token'):
            print('INVALID: missing tokens.access_token', file=sys.stderr)
            sys.exit(1)
        # Re-serialize with proper formatting
        print(json.dumps(parsed, indent=2))
        sys.exit(0)
print('INVALID: no auth_json field found', file=sys.stderr)
sys.exit(1)
" 2>/dev/null)
    if test $status -ne 0; or test -z "$auth_json"
        echo "Error: Invalid or missing auth data for '$target_name' in 1Password." >&2
        return 1
    end

    # Conflict detection: if local exists and has changed since last sync
    if test "$force" != true; and test -f "$accounts_dir/$target_name/auth.json"; and test -f "$meta_file"
        set -l stored_hash (grep "^content_hash=" "$meta_file" 2>/dev/null | string replace "content_hash=" "")
        set -l local_hash (_codex_accounts_hash "$accounts_dir/$target_name/auth.json")
        if test -n "$stored_hash"; and test "$stored_hash" != "$local_hash"
            echo "Conflict: Local '$target_name' changed since last sync. Use --force to overwrite." >&2
            return 1
        end
    end

    # Write auth.json with restrictive permissions
    mkdir -p "$accounts_dir/$target_name"
    echo "$auth_json" >"$accounts_dir/$target_name/auth.json"
    chmod 600 "$accounts_dir/$target_name/auth.json"

    # Ensure account is in the roster
    mkdir -p "$accounts_dir"
    touch "$accounts_file"
    if not grep -qx "$target_name" "$accounts_file" 2>/dev/null
        echo "$target_name" >>"$accounts_file"
    end

    # Update sync metadata
    set -l new_hash (_codex_accounts_hash "$accounts_dir/$target_name/auth.json")
    set -l remote_updated (echo "$item_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('updated_at',''))" 2>/dev/null)
    _codex_accounts_write_meta "$meta_file" "$item_id" "$new_hash" "$remote_updated"

    set -l info (_codex_accounts_decode_jwt "$accounts_dir/$target_name/auth.json")
    echo "  Pulled '$target_name': $info"
    return 0
end
