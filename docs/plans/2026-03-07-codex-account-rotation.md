# Codex Account Rotation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rotate Codex CLI through multiple OAuth-authenticated accounts using round-robin with automatic failover on usage limit errors.

**Architecture:** Fish functions manage account enrollment (`codex-accounts`) and rotation (`codex-rotate`). Auth profiles stored in `~/.codex/accounts/<name>/auth.json` (machine-local, gitignored). A simple file counter tracks round-robin state. `gwt-ticket --codex` calls `codex-rotate` instead of `codex` directly.

**Tech Stack:** Fish shell, JWT base64 decoding (python3 one-liner), Codex CLI OAuth

---

### Task 1: Create `codex-accounts` Fish Function

**Files:**
- Create: `.config/fish/functions/codex-accounts.fish`

**Step 1: Write the function**

```fish
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
            echo ""
            echo "Commands:"
            echo "  add <name>      Enroll a new account (opens browser login)"
            echo "  remove <name>   Remove an enrolled account"
            echo "  list            Show all enrolled accounts"
            echo "  status          Show rotation state"
            return 1
    end
end
```

**Step 2: Write the JWT decode helper function**

Create a helper that extracts email + plan from the auth.json JWT.

```fish
# In the same file or as a separate private function
function _codex_accounts_decode_jwt --description "Decode JWT from auth.json to extract email and plan"
    set -l auth_file $argv[1]
    # Extract id_token, decode payload (2nd dot-separated segment)
    python3 -c "
import json, base64, sys
auth = json.load(open('$auth_file'))
token = auth.get('tokens', {}).get('id_token', '')
if not token:
    print('no id_token')
    sys.exit(0)
payload = token.split('.')[1]
# Fix base64url padding
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
```

**Step 3: Verify function loads**

Run: `source .config/fish/functions/codex-accounts.fish && codex-accounts`
Expected: Usage help text

**Step 4: Commit**

```bash
git add .config/fish/functions/codex-accounts.fish
git commit -m "feat: add codex-accounts for multi-account enrollment"
```

---

### Task 2: Create `codex-rotate` Fish Function

**Files:**
- Create: `.config/fish/functions/codex-rotate.fish`

**Step 1: Write the rotation wrapper**

```fish
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

        # Not a usage-limit error (or success) — return as-is
        # Print captured stderr (minus any we already handled)
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
```

**Step 2: Verify function loads**

Run: `source .config/fish/functions/codex-rotate.fish && codex-rotate --help`
Expected: codex help output (passthrough) with "No accounts enrolled" warning if none enrolled

**Step 3: Commit**

```bash
git add .config/fish/functions/codex-rotate.fish
git commit -m "feat: add codex-rotate for round-robin account rotation with failover"
```

---

### Task 3: Integrate with `gwt-ticket`

**Files:**
- Modify: `.config/fish/functions/gwt-ticket.fish:1362` (codex exec command)
- Modify: `.config/fish/functions/gwt-ticket.fish:1461` (codex interactive command)

**Step 1: Change primary codex command to use codex-rotate**

At line 1362, change:
```fish
set -l codex_cmd "codex exec --full-auto"
```
to:
```fish
set -l codex_cmd "codex-rotate exec --full-auto"
```

**Step 2: Change secondary (interactive) codex command**

At line 1461, change:
```fish
set -l codex_cmd_interactive "codex --full-auto"
```
to:
```fish
set -l codex_cmd_interactive "codex-rotate --full-auto"
```

**Step 3: Verify the changes are syntactically correct**

Run: `fish -n .config/fish/functions/gwt-ticket.fish`
Expected: No output (no syntax errors)

**Step 4: Commit**

```bash
git add .config/fish/functions/gwt-ticket.fish
git commit -m "feat: integrate codex-rotate into gwt-ticket for account rotation"
```

---

### Task 4: Handle stderr capture edge case in launch scripts

**Context:** `gwt-ticket` writes launch scripts that pipe codex output. The stderr capture in `codex-rotate` uses a temp file and `2>` redirection. This works because the rotation wrapper runs *inside* the launch script — it captures stderr for limit detection but re-emits non-limit stderr.

However, the codex exec invocation in the launch script reads the prompt from a file:
```fish
set -a _ls (printf '%s "(cat \'%s\')"' "$codex_cmd" "$prompt_cmd_file")
```

This constructs: `codex-rotate exec --full-auto "(cat '/path/to/prompt.txt')"`

**Step 1: Verify the prompt passthrough works**

The `codex-rotate` function passes `$argv` directly to `codex`, so the prompt argument flows through unchanged. No modification needed — just verify.

Run: `fish -n .config/fish/functions/codex-rotate.fish`
Expected: No output (no syntax errors)

**Step 2: Commit** (if any changes were needed)

No commit needed if no changes — just verification.

---

### Task 5: Add Fish completions for `codex-accounts`

**Files:**
- Create: `.config/fish/completions/codex-accounts.fish`

**Step 1: Write completions**

```fish
# Completions for codex-accounts
complete -c codex-accounts -f

# Subcommands
complete -c codex-accounts -n "__fish_use_subcommand" -a add -d "Enroll a new account"
complete -c codex-accounts -n "__fish_use_subcommand" -a remove -d "Remove an enrolled account"
complete -c codex-accounts -n "__fish_use_subcommand" -a rm -d "Remove an enrolled account"
complete -c codex-accounts -n "__fish_use_subcommand" -a list -d "Show all enrolled accounts"
complete -c codex-accounts -n "__fish_use_subcommand" -a ls -d "Show all enrolled accounts"
complete -c codex-accounts -n "__fish_use_subcommand" -a status -d "Show rotation state"

# For remove: complete with enrolled account names
complete -c codex-accounts -n "__fish_seen_subcommand_from remove rm" -a "(cat ~/.codex/accounts/.accounts 2>/dev/null)"
```

**Step 2: Commit**

```bash
git add .config/fish/completions/codex-accounts.fish
git commit -m "feat: add fish completions for codex-accounts"
```

---

### Task 6: Verify end-to-end flow

**Step 1: Source all functions**

```bash
source .config/fish/functions/codex-accounts.fish
source .config/fish/functions/codex-rotate.fish
```

**Step 2: Test codex-accounts add**

```bash
codex-accounts add test1
```
Expected: Browser opens, after login shows email + plan, "enrolled successfully"

**Step 3: Test codex-accounts list**

```bash
codex-accounts list
```
Expected: Shows `test1` with email and plan type, `>` marker on current

**Step 4: Test codex-rotate passthrough**

```bash
codex-rotate --version
```
Expected: Shows codex version with "Using account 'test1'" on stderr

**Step 5: Clean up test account**

```bash
codex-accounts remove test1
```

**Step 6: Final commit (if any adjustments)**

```bash
git add -A && git commit -m "fix: adjustments from end-to-end testing"
```
