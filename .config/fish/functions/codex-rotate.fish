function codex-rotate --description "Run codex with automatic account rotation (round-robin + failover)"
    set -l accounts_dir "$HOME/.codex/accounts"
    set -l accounts_file "$accounts_dir/.accounts"
    set -l current_file "$accounts_dir/.current"
    set -l codex_auth "$HOME/.codex/auth.json"
    set -l original_auth_tmp ""
    set -l original_hash ""

    if test -f "$codex_auth"
        set original_auth_tmp (mktemp)
        cp "$codex_auth" "$original_auth_tmp"
        set original_hash (_codex_rotate_hash "$original_auth_tmp")
    end

    # If no accounts enrolled, fall through to plain codex
    if not test -f "$accounts_file"
        echo "codex-rotate: No accounts enrolled. Running plain codex." >&2
        echo "  Enroll accounts with: codex-accounts add <name>" >&2
        codex $argv
        set -l exit_code $status
        _codex_rotate_cleanup_temp "$original_auth_tmp"
        return $exit_code
    end

    set -l names (cat "$accounts_file")
    set -l total (count $names)

    if test $total -eq 0
        codex $argv
        set -l exit_code $status
        _codex_rotate_cleanup_temp "$original_auth_tmp"
        return $exit_code
    end

    # Read current index, advance to next (round-robin)
    set -l current_idx 0
    if test -f "$current_file"
        set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
    end
    set -l start_idx (math "($current_idx + 1) % $total")

    # If a live session exists and is not already enrolled, try it first.
    set -l candidate_names
    set -l candidate_auths
    set -l candidate_slots
    if test -n "$original_hash"
        set -l active_is_enrolled false
        for name in $names
            set -l acct_auth "$accounts_dir/$name/auth.json"
            if test -f "$acct_auth"
                set -l acct_hash (_codex_rotate_hash "$acct_auth")
                if test "$acct_hash" = "$original_hash"
                    set active_is_enrolled true
                    break
                end
            end
        end
        if not $active_is_enrolled
            set -a candidate_names "__active__"
            set -a candidate_auths "$original_auth_tmp"
            set -a candidate_slots -1
        end
    end

    for offset in (seq 0 (math $total - 1))
        set -l idx (math "($start_idx + $offset) % $total")
        set -l name $names[(math $idx + 1)]
        set -a candidate_names "$name"
        set -a candidate_auths "$accounts_dir/$name/auth.json"
        set -a candidate_slots $idx
    end

    set -l tried_names
    set -l tried_infos

    for i in (seq (count $candidate_names))
        set -l name $candidate_names[$i]
        set -l acct_auth $candidate_auths[$i]
        set -l slot $candidate_slots[$i]

        if not test -f "$acct_auth"
            if test "$name" = "__active__"
                echo "codex-rotate: Current live session auth disappeared, skipping." >&2
            else
                echo "codex-rotate: Account '$name' missing auth.json, skipping." >&2
            end
            continue
        end

        # Activate this account
        cp "$acct_auth" "$codex_auth"
        if test $slot -ge 0
            echo $slot >"$current_file"
        end
        set -l info (_codex_rotate_decode_auth "$acct_auth")
        set -a tried_names "$name"
        set -a tried_infos "$info"
        if test "$name" = "__active__"
            echo "codex-rotate: Using current live session ($info)" >&2
        else
            echo "codex-rotate: Using account '$name' ($info)" >&2
        end

        # Run codex, capture exit code and stderr
        set -l stderr_file (mktemp)
        codex $argv 2>$stderr_file
        set -l exit_code $status
        set -l stderr_content (cat "$stderr_file" 2>/dev/null)
        rm -f "$stderr_file"

        # Check for broken codex install (missing native dep or posix_spawn failure)
        if test $exit_code -ne 0; and begin
                string match -qi "*Missing optional dependency*" -- "$stderr_content"; or string match -qi "*spawn Unknown system error*" -- "$stderr_content"
            end
            echo "codex-rotate: Codex binary is broken. Attempting reinstall..." >&2
            bun install -g @openai/codex@latest 2>&1 | tail -1 >&2
            # Retry once after reinstall
            set -l retry_stderr (mktemp)
            codex $argv 2>$retry_stderr
            set -l retry_code $status
            set -l retry_content (cat "$retry_stderr" 2>/dev/null)
            rm -f "$retry_stderr"
            if test -n "$retry_content"
                echo "$retry_content" >&2
            end
            _codex_rotate_cleanup_temp "$original_auth_tmp"
            return $retry_code
        end

        # Check for usage limit error
        if test $exit_code -ne 0; and string match -qi "*usage limit*" "$stderr_content"
            if test "$name" = "__active__"
                echo "codex-rotate: Current live session hit usage limit, trying next..." >&2
            else
                echo "codex-rotate: Account '$name' hit usage limit, trying next..." >&2
            end
            continue
        end

        # Not a usage-limit error (or success) -- return as-is
        if test -n "$stderr_content"
            echo "$stderr_content" >&2
        end
        _codex_rotate_cleanup_temp "$original_auth_tmp"
        return $exit_code
    end

    set -l tried_total (count $tried_names)
    echo "codex-rotate: All $tried_total accounts exhausted (usage limits). Try again later." >&2
    echo "codex-rotate: Accounts tried:" >&2
    for i in (seq (count $tried_names))
        set -l name $tried_names[$i]
        set -l info $tried_infos[$i]
        if test "$name" = "__active__"
            echo "  - current live session: $info" >&2
        else
            echo "  - $name: $info" >&2
        end
    end
    _codex_rotate_cleanup_temp "$original_auth_tmp"
    return 1
end

function _codex_rotate_hash --description "SHA256 hash of auth file"
    if not test -f "$argv[1]"
        return 1
    end
    shasum -a 256 "$argv[1]" 2>/dev/null | string split " " | head -1
end

function _codex_rotate_decode_auth --description "Decode auth.json to email, plan, and default org"
    set -l auth_file $argv[1]
    python3 -c "
import json, base64
try:
    auth = json.load(open('$auth_file'))
    token = auth.get('tokens', {}).get('id_token', '')
    if not token:
        print('unknown (unknown, org: unknown)')
        raise SystemExit(0)
    payload = token.split('.')[1]
    payload += '=' * (-len(payload) % 4)
    data = json.loads(base64.urlsafe_b64decode(payload))
    auth_meta = data.get('https://api.openai.com/auth', {})
    orgs = auth_meta.get('organizations', []) or []
    default_org = None
    for org in orgs:
        if isinstance(org, dict) and org.get('is_default'):
            default_org = org
            break
    if default_org is None and orgs:
        default_org = orgs[0]
    email = data.get('email', 'unknown')
    plan = auth_meta.get('chatgpt_plan_type', 'unknown')
    org_title = (default_org or {}).get('title', 'unknown')
    print(f'{email} ({plan}, org: {org_title})')
except Exception:
    print('decode error')
" 2>/dev/null; or echo "decode error"
end

function _codex_rotate_cleanup_temp --description "Delete temp auth snapshot if present"
    if test -n "$argv[1]"; and test -f "$argv[1]"
        rm -f "$argv[1]"
    end
end
