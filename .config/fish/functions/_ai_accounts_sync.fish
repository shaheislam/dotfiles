function _ai_accounts_sync --description "Cross-sync account profiles between Codex CLI and OpenCode"
    set -l subcmd $argv[1]
    set -e argv[1]

    switch "$subcmd"
        case to-opencode
            # Usage: _ai_accounts_sync to-opencode <name> <codex_auth_json_path>
            set -q AI_ACCOUNTS_NO_SYNC; and return 0
            set -l name $argv[1]
            set -l codex_auth $argv[2]
            set -l oc_accounts_dir "$HOME/.opencode/accounts"
            set -l oc_accounts_file "$oc_accounts_dir/.accounts"
            set -l oc_acct_dir "$oc_accounts_dir/$name"

            if not test -f "$codex_auth"
                return 1
            end

            mkdir -p "$oc_acct_dir"
            python3 -c "
import json, base64, sys
try:
    data = json.load(open('$codex_auth'))
    tokens = data.get('tokens', {})
    access = tokens.get('access_token', '')
    refresh = tokens.get('refresh_token', '')
    account_id = tokens.get('account_id', '')
    expires = 0
    if access:
        try:
            payload = access.split('.')[1]
            payload += '=' * (-len(payload) % 4)
            claims = json.loads(base64.urlsafe_b64decode(payload))
            expires = int(claims.get('exp', 0)) * 1000
        except Exception:
            pass
    result = {
        'type': 'oauth',
        'refresh': refresh,
        'access': access,
        'expires': expires,
        'accountId': account_id
    }
    json.dump(result, open('$oc_acct_dir/openai-auth.json', 'w'), indent=2)
except Exception as e:
    print(f'sync error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
            if test $status -ne 0
                echo "  (cross-sync to opencode failed for '$name')" >&2
                return 1
            end
            chmod 600 "$oc_acct_dir/openai-auth.json"
            mkdir -p "$oc_accounts_dir"
            touch "$oc_accounts_file"
            if not grep -qx "$name" "$oc_accounts_file" 2>/dev/null
                echo "$name" >>"$oc_accounts_file"
            end
            echo "  (synced '$name' to opencode)" >&2

        case to-codex
            # Usage: _ai_accounts_sync to-codex <name> <opencode_auth_json_path>
            set -q AI_ACCOUNTS_NO_SYNC; and return 0
            set -l name $argv[1]
            set -l oc_auth $argv[2]
            set -l codex_accounts_dir "$HOME/.codex/accounts"
            set -l codex_accounts_file "$codex_accounts_dir/.accounts"
            set -l codex_acct_dir "$codex_accounts_dir/$name"

            if not test -f "$oc_auth"
                return 1
            end

            mkdir -p "$codex_acct_dir"
            python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    data = json.load(open('$oc_auth'))
    access = data.get('access', '')
    refresh = data.get('refresh', '')
    account_id = data.get('accountId', '')
    result = {
        'OPENAI_API_KEY': None,
        'tokens': {
            'id_token': None,
            'access_token': access,
            'refresh_token': refresh,
            'account_id': account_id
        },
        'last_refresh': datetime.now(timezone.utc).isoformat()
    }
    json.dump(result, open('$codex_acct_dir/auth.json', 'w'), indent=2)
except Exception as e:
    print(f'sync error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
            if test $status -ne 0
                echo "  (cross-sync to codex failed for '$name')" >&2
                return 1
            end
            chmod 600 "$codex_acct_dir/auth.json"
            mkdir -p "$codex_accounts_dir"
            touch "$codex_accounts_file"
            if not grep -qx "$name" "$codex_accounts_file" 2>/dev/null
                echo "$name" >>"$codex_accounts_file"
            end
            echo "  (synced '$name' to codex)" >&2

        case remove-opencode
            set -q AI_ACCOUNTS_NO_SYNC; and return 0
            set -l name $argv[1]
            set -l oc_accounts_dir "$HOME/.opencode/accounts"
            set -l oc_accounts_file "$oc_accounts_dir/.accounts"
            if test -d "$oc_accounts_dir/$name"
                rm -rf "$oc_accounts_dir/$name"
            end
            if test -f "$oc_accounts_file"
                set -l tmp (mktemp)
                grep -vx "$name" "$oc_accounts_file" >"$tmp" 2>/dev/null
                mv "$tmp" "$oc_accounts_file"
            end
            echo "  (removed '$name' from opencode)" >&2

        case remove-codex
            set -q AI_ACCOUNTS_NO_SYNC; and return 0
            set -l name $argv[1]
            set -l codex_accounts_dir "$HOME/.codex/accounts"
            set -l codex_accounts_file "$codex_accounts_dir/.accounts"
            if test -d "$codex_accounts_dir/$name"
                rm -rf "$codex_accounts_dir/$name"
            end
            if test -f "$codex_accounts_file"
                set -l tmp (mktemp)
                grep -vx "$name" "$codex_accounts_file" >"$tmp" 2>/dev/null
                mv "$tmp" "$codex_accounts_file"
            end
            echo "  (removed '$name' from codex)" >&2

        case all
            set -l codex_dir "$HOME/.codex/accounts"
            set -l codex_file "$codex_dir/.accounts"
            set -l oc_dir "$HOME/.opencode/accounts"
            set -l oc_file "$oc_dir/.accounts"
            set -l direction $argv[1]
            set -l synced 0

            # Codex → OpenCode
            if test "$direction" != "--to-codex"
                if test -f "$codex_file"
                    for name in (cat "$codex_file")
                        set -l codex_auth "$codex_dir/$name/auth.json"
                        set -l oc_auth "$oc_dir/$name/openai-auth.json"
                        if test -f "$codex_auth"; and not test -f "$oc_auth"
                            _ai_accounts_sync to-opencode "$name" "$codex_auth"
                            set synced (math $synced + 1)
                        end
                    end
                end
            end

            # OpenCode → Codex
            if test "$direction" != "--to-opencode"
                if test -f "$oc_file"
                    for name in (cat "$oc_file")
                        set -l oc_auth "$oc_dir/$name/openai-auth.json"
                        set -l codex_auth "$codex_dir/$name/auth.json"
                        if test -f "$oc_auth"; and not test -f "$codex_auth"
                            _ai_accounts_sync to-codex "$name" "$oc_auth"
                            set synced (math $synced + 1)
                        end
                    end
                end
            end

            echo "Synced $synced account(s)."
    end
end
