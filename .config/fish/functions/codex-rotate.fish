function codex-rotate --description "Run codex with automatic account rotation (round-robin + failover)"
    set -l accounts_dir "$HOME/.codex/accounts"
    set -l accounts_file "$accounts_dir/.accounts"
    set -l current_file "$accounts_dir/.current"
    set -l codex_auth "$HOME/.codex/auth.json"

    # If no accounts enrolled, fall through to plain codex
    if not test -f "$accounts_file"
        echo "codex-rotate: No accounts enrolled. Running plain codex." >&2
        echo "  Enroll accounts with: codex-accounts add <name>" >&2
        codex $argv
        return $status
    end

    set -l names (cat "$accounts_file")
    set -l total (count $names)

    if test $total -eq 0
        codex $argv
        return $status
    end

    # Read current index, advance to next (round-robin)
    set -l current_idx 0
    if test -f "$current_file"
        set current_idx (cat "$current_file" 2>/dev/null; or echo 0)
    end
    set -l start_idx (math "($current_idx + 1) % $total")

    # Try each account starting from the next in rotation
    set -l tried 0
    set -l idx $start_idx

    while test $tried -lt $total
        set -l name $names[(math $idx + 1)]
        set -l acct_auth "$accounts_dir/$name/auth.json"

        if not test -f "$acct_auth"
            echo "codex-rotate: Account '$name' missing auth.json, skipping." >&2
            set tried (math $tried + 1)
            set idx (math "($idx + 1) % $total")
            continue
        end

        # Activate this account
        cp "$acct_auth" "$codex_auth"
        echo $idx >"$current_file"
        echo "codex-rotate: Using account '$name'" >&2

        # Run codex, capture exit code and stderr
        set -l stderr_file (mktemp)
        codex $argv 2>$stderr_file
        set -l exit_code $status
        set -l stderr_content (cat "$stderr_file" 2>/dev/null)
        rm -f "$stderr_file"

        # Check for usage limit error
        if test $exit_code -ne 0; and string match -qi "*usage limit*" "$stderr_content"
            echo "codex-rotate: Account '$name' hit usage limit, trying next..." >&2
            set tried (math $tried + 1)
            set idx (math "($idx + 1) % $total")
            continue
        end

        # Not a usage-limit error (or success) -- return as-is
        if test -n "$stderr_content"
            echo "$stderr_content" >&2
        end
        return $exit_code
    end

    echo "codex-rotate: All $total accounts exhausted (usage limits). Try again later." >&2
    echo "codex-rotate: Accounts tried:" >&2
    for name in $names
        set -l info (_codex_accounts_decode_jwt "$accounts_dir/$name/auth.json")
        echo "  - $name: $info" >&2
    end
    return 1
end
