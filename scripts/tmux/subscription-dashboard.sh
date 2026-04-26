#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_USAGE_SCRIPT="$DOTFILES_ROOT/scripts/ticket-queue/claude-usage.sh"
OPENCODE_USAGE_SCRIPT="$DOTFILES_ROOT/scripts/opencode/usage-check.sh"

INTERVAL=30
ONCE=false
NO_COLOR=false
COMPACT=true
INTERACTIVE_SESSION=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --once)
            ONCE=true
            shift
            ;;
        --interval)
            INTERVAL="${2:?Error: --interval requires seconds}"
            shift 2
            ;;
        --no-color)
            NO_COLOR=true
            shift
            ;;
        --compact)
            COMPACT=true
            shift
            ;;
        --full)
            COMPACT=false
            shift
            ;;
        --help|-h)
            cat <<'EOF'
subscription-dashboard.sh - Claude + OpenAI subscription usage dashboard

Usage:
  subscription-dashboard.sh            # Interactive auto-refresh view
  subscription-dashboard.sh --once     # Print once and exit
  subscription-dashboard.sh --interval 15
  subscription-dashboard.sh --no-color
  subscription-dashboard.sh --compact
  subscription-dashboard.sh --full
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "Error: --interval must be a positive integer" >&2
    exit 1
fi

if [[ -t 1 && "$NO_COLOR" == false ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_MAGENTA=""
    C_CYAN=""
fi

trim() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

shorten() {
    local value="$1"
    local max_len="$2"
    if (( ${#value} <= max_len )); then
        printf '%s' "$value"
    elif (( max_len <= 3 )); then
        printf '%.*s' "$max_len" "$value"
    else
        printf '%s...' "${value:0:max_len-3}"
    fi
}

colorize_state() {
    local state="$1"
    case "$state" in
        AVAILABLE|HEALTHY)
            printf '%s%s%s' "$C_GREEN" "$state" "$C_RESET"
            ;;
        LIMITED|WARN|TRANSIENT)
            printf '%s%s%s' "$C_YELLOW" "$state" "$C_RESET"
            ;;
        EXPIRED|ERROR|MISSING|LOGIN|DUPLICATE)
            printf '%s%s%s' "$C_RED" "$state" "$C_RESET"
            ;;
        *)
            printf '%s' "$state"
            ;;
    esac
}

colorize_pct() {
    local raw="$1"

    if [[ ! "$raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "$raw"
        return
    fi

    local pct
    pct=$(printf '%.0f' "$raw" 2>/dev/null || printf '0')

    if (( pct >= 90 )); then
        printf '%s%s%%%s' "$C_RED" "$pct" "$C_RESET"
    elif (( pct >= 75 )); then
        printf '%s%s%%%s' "$C_YELLOW" "$pct" "$C_RESET"
    else
        printf '%s%s%%%s' "$C_GREEN" "$pct" "$C_RESET"
    fi
}

format_time() {
    local value="$1"
    python3 - "$value" <<'PY'
import datetime
import sys

value = sys.argv[1].strip()
if not value or value == "null":
    print("n/a")
    raise SystemExit(0)

try:
    dt = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
except Exception:
    print("n/a")
    raise SystemExit(0)

now = datetime.datetime.now(datetime.timezone.utc)
delta = int((dt - now).total_seconds())

if delta <= 0:
    rel = "now"
else:
    hours, rem = divmod(delta, 3600)
    minutes = rem // 60
    if hours >= 24:
        rel = f"{hours // 24}d"
    elif hours > 0:
        rel = f"{hours}h{minutes:02d}"
    else:
        rel = f"{minutes}m"

local_dt = dt.astimezone()
print(f"{rel} {local_dt.strftime('%b%d %H:%M')}")
PY
}

CLAUDE_TOTAL=0
CLAUDE_HEALTHY=0
CLAUDE_WARN=0
CLAUDE_LIMITED=0
CLAUDE_ERROR=0
OPENAI_TOTAL=0
OPENAI_AVAILABLE=0
OPENAI_LIMITED=0
OPENAI_EXPIRED=0
OPENAI_OTHER=0
CLAUDE_REPAIRS=()
OPENAI_FIX_REPAIRS=()
OPENAI_LOGIN_REPAIRS=()
OPENAI_DUPLICATE_REPAIRS=()

reset_summary_counters() {
    CLAUDE_TOTAL=0
    CLAUDE_HEALTHY=0
    CLAUDE_WARN=0
    CLAUDE_LIMITED=0
    CLAUDE_ERROR=0
    OPENAI_TOTAL=0
    OPENAI_AVAILABLE=0
    OPENAI_LIMITED=0
    OPENAI_EXPIRED=0
    OPENAI_OTHER=0
    CLAUDE_REPAIRS=()
    OPENAI_FIX_REPAIRS=()
    OPENAI_LOGIN_REPAIRS=()
    OPENAI_DUPLICATE_REPAIRS=()
}

append_unique() {
    local var_name="$1"
    local value="$2"
    local current=()
    local item

    eval "current=(\"\${${var_name}[@]}\")"
    for item in "${current[@]}"; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done

    eval "$var_name+=(\"\$value\")"
}

join_by() {
    local delimiter="$1"
    shift
    local first=true
    local item

    for item in "$@"; do
        if [[ "$first" == true ]]; then
            printf '%s' "$item"
            first=false
        else
            printf '%s%s' "$delimiter" "$item"
        fi
    done
}

classify_claude_error() {
    local message="$1"
    local lower
    lower=$(printf '%s' "$message" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower" == *"credentials file not found"* ]] || [[ "$lower" == *"cannot read claude code credentials from keychain"* ]]; then
        printf 'MISSING\tmissing auth\n'
    elif [[ "$lower" == *"oauth token expired"* ]] || [[ "$lower" == *"http 401"* ]]; then
        printf 'EXPIRED\tauth expired\n'
    elif [[ "$lower" == *"http 429"* ]] || [[ "$lower" == *"rate limited"* ]] || [[ "$lower" == *"capacity"* ]]; then
        printf 'LIMITED\tusage limited\n'
    elif [[ "$lower" == *"http 403"* ]]; then
        printf 'ERROR\taccess denied\n'
    elif [[ "$lower" == *"http 500"* ]] || [[ "$lower" == *"http 502"* ]] || [[ "$lower" == *"http 503"* ]] || [[ "$lower" == *"http 504"* ]]; then
        printf 'WARN\tapi transient\n'
    else
        printf 'ERROR\t%s\n' "$(shorten "$message" 26)"
    fi
}

count_claude_state() {
    local state="$1"
    CLAUDE_TOTAL=$((CLAUDE_TOTAL + 1))
    case "$state" in
        HEALTHY) CLAUDE_HEALTHY=$((CLAUDE_HEALTHY + 1)) ;;
        WARN) CLAUDE_WARN=$((CLAUDE_WARN + 1)) ;;
        LIMITED) CLAUDE_LIMITED=$((CLAUDE_LIMITED + 1)) ;;
        *) CLAUDE_ERROR=$((CLAUDE_ERROR + 1)) ;;
    esac
}

count_openai_state() {
    local state="$1"
    OPENAI_TOTAL=$((OPENAI_TOTAL + 1))
    case "$state" in
        AVAILABLE) OPENAI_AVAILABLE=$((OPENAI_AVAILABLE + 1)) ;;
        LIMITED) OPENAI_LIMITED=$((OPENAI_LIMITED + 1)) ;;
        EXPIRED) OPENAI_EXPIRED=$((OPENAI_EXPIRED + 1)) ;;
        *) OPENAI_OTHER=$((OPENAI_OTHER + 1)) ;;
    esac
}

render_summary() {
    printf '%sSummary:%s ' "$C_DIM" "$C_RESET"
    printf 'Claude %s/%s healthy' "$CLAUDE_HEALTHY" "$CLAUDE_TOTAL"
    if (( CLAUDE_WARN > 0 )); then
        printf ', %s warn' "$CLAUDE_WARN"
    fi
    if (( CLAUDE_LIMITED > 0 )); then
        printf ', %s limited' "$CLAUDE_LIMITED"
    fi
    if (( CLAUDE_ERROR > 0 )); then
        printf ', %s issues' "$CLAUDE_ERROR"
    fi
    printf ' | OpenAI %s/%s available' "$OPENAI_AVAILABLE" "$OPENAI_TOTAL"
    if (( OPENAI_LIMITED > 0 )); then
        printf ', %s limited' "$OPENAI_LIMITED"
    fi
    if (( OPENAI_EXPIRED > 0 )); then
        printf ', %s expired' "$OPENAI_EXPIRED"
    fi
    if (( OPENAI_OTHER > 0 )); then
        printf ', %s other' "$OPENAI_OTHER"
    fi
    printf '\n'
    printf '%sNote:%s OpenAI shows account health from probe results, not true subscription percentages.\n\n' "$C_DIM" "$C_RESET"
}

render_repairs() {
    if (( ${#CLAUDE_REPAIRS[@]} == 0 && ${#OPENAI_FIX_REPAIRS[@]} == 0 && ${#OPENAI_LOGIN_REPAIRS[@]} == 0 )); then
        return
    fi

    printf '%sRepairs:%s\n' "$C_BOLD" "$C_RESET"

    if (( ${#OPENAI_FIX_REPAIRS[@]} > 0 )); then
        printf '  OpenAI accounts needing attention: %s\n' "$(join_by ', ' "${OPENAI_FIX_REPAIRS[@]}")"
        printf '  Run: %ssubdash fix%s\n' "$C_BOLD" "$C_RESET"
    fi

    if (( ${#OPENAI_LOGIN_REPAIRS[@]} > 0 )); then
        local name
        printf '  OpenAI accounts needing fresh login: %s\n' "$(join_by ', ' "${OPENAI_LOGIN_REPAIRS[@]}")"
        for name in "${OPENAI_LOGIN_REPAIRS[@]}"; do
            printf '    %ssubdash login openai %s%s\n' "$C_BOLD" "$name" "$C_RESET"
        done
    fi

    if (( ${#OPENAI_DUPLICATE_REPAIRS[@]} > 0 )); then
        printf '  OpenAI duplicate profiles: %s\n' "$(join_by ', ' "${OPENAI_DUPLICATE_REPAIRS[@]}")"
    fi

    if (( ${#CLAUDE_REPAIRS[@]} > 0 )); then
        local name
        printf '  Claude profiles needing browser reauth: %s\n' "$(join_by ', ' "${CLAUDE_REPAIRS[@]}")"
        for name in "${CLAUDE_REPAIRS[@]}"; do
            if [[ "$name" == "default" ]]; then
                printf '    %ssubdash login claude%s\n' "$C_BOLD" "$C_RESET"
            else
                printf '    %ssubdash login claude %s%s\n' "$C_BOLD" "$name" "$C_RESET"
            fi
        done
    fi

    if [[ "$INTERACTIVE_SESSION" == true ]]; then
        printf '  Press %sr%s to launch a repair/login action from this popup.\n' "$C_BOLD" "$C_RESET"
    fi

    printf '\n'
}

run_subdash_command() {
    local cmd='source "$HOME/dotfiles/.config/fish/functions/subdash.fish"; subdash'
    local arg

    for arg in "$@"; do
        cmd+=" $(printf '%q' "$arg")"
    done

    fish -lc "$cmd"
}

pause_for_key() {
    printf '\nPress any key to return to the dashboard...'
    read -r -s -n 1 _
}

launch_repair_menu() {
    local entries=()
    local choice
    local idx=1
    local label action provider name

    for name in "${OPENAI_LOGIN_REPAIRS[@]}"; do
        entries+=("OpenAI login: $name|login|openai|$name")
    done

    for name in "${CLAUDE_REPAIRS[@]}"; do
        if [[ "$name" == "default" ]]; then
            entries+=("Claude login: default|login|claude|")
        else
            entries+=("Claude login: $name|login|claude|$name")
        fi
    done

    if (( ${#OPENAI_FIX_REPAIRS[@]} > 0 )); then
        entries+=("Run OpenAI refresh fix|fix||")
    fi

    if (( ${#entries[@]} == 0 )); then
        return
    fi

    while true; do
        clear
        printf '%sRepair Actions%s\n\n' "$C_BOLD$C_BLUE" "$C_RESET"

        idx=1
        for entry in "${entries[@]}"; do
            IFS='|' read -r label _action _provider _name <<<"$entry"
            printf '  [%d] %s\n' "$idx" "$label"
            idx=$((idx + 1))
        done

        printf '  [q] Cancel\n\n'
        read -r -p 'Select action: ' choice

        if [[ "$choice" == "q" || "$choice" == "Q" || -z "$choice" ]]; then
            return
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#entries[@]} )); then
            continue
        fi

        IFS='|' read -r label action provider name <<<"${entries[choice-1]}"

        clear
        printf '%sRunning:%s %s\n\n' "$C_BOLD" "$C_RESET" "$label"

        if [[ "$action" == "fix" ]]; then
            run_subdash_command fix
        elif [[ -n "$name" ]]; then
            run_subdash_command "$action" "$provider" "$name"
        else
            run_subdash_command "$action" "$provider"
        fi

        pause_for_key
        return
    done
}

get_claude_profile_label() {
    local dir="$1"
    if [[ "$dir" == "$HOME/.claude" ]]; then
        printf 'default'
    else
        basename "$dir" | sed 's/^\.claude-//'
    fi
}

get_claude_profile_info() {
    local dir="$1"
    python3 - "$dir" <<'PY'
import json
import os
import sys

config_dir = sys.argv[1]
meta_path = os.path.join(config_dir, ".claude.json")
display = ""
email = ""
billing = ""

try:
    with open(meta_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    acct = data.get("subscriptionAccount") or {}
    display = acct.get("displayName") or ""
    email = acct.get("emailAddress") or ""
    billing = acct.get("billingType") or ""
except Exception:
    pass

print("\t".join([display, email, billing]))
PY
}

get_claude_usage_row() {
    local dir="$1"
    local output
    local cmd=("$CLAUDE_USAGE_SCRIPT" --json)

    if [[ "$dir" != "$HOME/.claude" ]]; then
        cmd+=(--config-dir "$dir")
    fi

    if output=$("${cmd[@]}" 2>&1); then
        python3 - "$output" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
five = payload.get("five_hour") or {}
seven = payload.get("seven_day") or {}
opus = payload.get("seven_day_opus") or {}

five_pct = float(five.get("utilization", 0) or 0)
seven_pct = float(seven.get("utilization", 0) or 0)
opus_pct = float(opus.get("utilization", 0) or 0)

state = "HEALTHY"
if max(five_pct, seven_pct, opus_pct) >= 90:
    state = "LIMITED"
elif max(five_pct, seven_pct, opus_pct) >= 75:
    state = "WARN"

print("\t".join([
    f"{five_pct}",
    f"{seven_pct}",
    f"{opus_pct}",
    five.get("resets_at") or "null",
    seven.get("resets_at") or "null",
    state,
]))
PY
    else
        local status=$?
        local message
        message=$(trim "$(printf '%s' "$output" | awk 'NF {print; exit}')")
        if [[ -z "$message" ]]; then
            message="usage check failed (exit $status)"
        fi
        printf '0\t0\t0\tnull\tnull\tERROR:%s\n' "$message"
    fi
}

openai_saved_auth_info() {
    local auth_file="$1"
    python3 - "$auth_file" <<'PY'
import base64
import json
import sys

path = sys.argv[1]
email = "unknown"
plan = "unknown"
short_id = "?"
access = ""
expires = "0"

try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    access = data.get("access") or ""
    expires = str(data.get("expires") or 0)
    if access:
        payload = access.split(".")[1]
        payload += "=" * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
        auth_meta = claims.get("https://api.openai.com/auth", {})
        profile = claims.get("https://api.openai.com/profile", {})
        email = profile.get("email") or claims.get("email") or email
        plan = auth_meta.get("chatgpt_plan_type") or plan
        user_id = auth_meta.get("chatgpt_user_id") or ""
        if user_id:
            short_id = user_id[-8:]
except Exception:
    pass

print("\t".join([email, plan, short_id, expires, access]))
PY
}

openai_saved_auth_identity() {
    local auth_file="$1"
    python3 - "$auth_file" <<'PY'
import base64
import json
import sys

path = sys.argv[1]
email = ''
account_id = ''

try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    print('')
    raise SystemExit(0)

token = data.get('access') or ''
account_id = data.get('accountId') or ''
if token:
    try:
        payload = token.split('.')[1]
        payload += '=' * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
        auth_meta = claims.get('https://api.openai.com/auth', {})
        profile = claims.get('https://api.openai.com/profile', {})
        account_id = account_id or auth_meta.get('chatgpt_account_id') or ''
        email = profile.get('email') or claims.get('email') or ''
    except Exception:
        pass

parts = [part for part in (account_id, email) if part]
print('|'.join(parts))
PY
}

find_openai_duplicate_profile() {
    local target_name="$1"
    local target_auth="$2"
    local accounts_file="$3"
    local target_identity
    local target_email
    local email_local
    local canonical_name
    local canonical_score=2
    local other_name
    local other_auth
    local other_score

    target_identity="$(openai_saved_auth_identity "$target_auth")"
    if [[ -z "$target_identity" ]]; then
        return
    fi

    target_email="$(printf '%s' "$target_identity" | awk -F'|' '{print $2}')"
    email_local="${target_email%@*}"
    canonical_name="$target_name"
    if [[ "$target_name" == "$email_local" ]]; then
        canonical_score=0
    fi

    while IFS= read -r other_name || [[ -n "$other_name" ]]; do
        [[ -n "$other_name" ]] || continue
        [[ "$other_name" == "$target_name" ]] && continue
        other_auth="$HOME/.opencode/accounts/$other_name/openai-auth.json"
        [[ -f "$other_auth" ]] || continue

        if [[ "$target_identity" == "$(openai_saved_auth_identity "$other_auth")" ]]; then
            other_score=2
            if [[ "$other_name" == "$email_local" ]]; then
                other_score=0
            fi

            if (( other_score < canonical_score )); then
                canonical_name="$other_name"
                canonical_score=$other_score
            fi
        fi
    done <"$accounts_file"

    if [[ "$canonical_name" != "$target_name" ]]; then
        printf '%s' "$canonical_name"
    fi
}

openai_probe_state() {
    local saved_auth="$1"
    local login_required_file
    login_required_file="$(dirname "$saved_auth")/.login-required"

    if [[ -f "$login_required_file" ]]; then
        printf 'LOGIN\tfresh login required\n'
        return
    fi

    local tmp_auth
    tmp_auth="$(mktemp)"

    python3 - "$saved_auth" "$tmp_auth" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as fh:
    data = json.load(fh)
with open(dst, "w", encoding="utf-8") as fh:
    json.dump({"openai": data}, fh)
PY

    local output
    local rc=0
    output=$("$OPENCODE_USAGE_SCRIPT" --auth-file "$tmp_auth" 2>&1) || rc=$?
    rm -f "$tmp_auth"

    case "$rc" in
        0) printf 'AVAILABLE\t%s\n' "$(trim "$output")" ;;
        1) printf 'LIMITED\t%s\n' "$(trim "$output")" ;;
        2)
            if grep -qi 'connection failed\|timeout\|network error\|server error' <<<"$output"; then
                printf 'TRANSIENT\t%s\n' "$(trim "$output")"
            else
                printf 'EXPIRED\t%s\n' "$(trim "$output")"
            fi
            ;;
        3) printf 'MISSING\t%s\n' "$(trim "$output")" ;;
        *) printf 'ERROR\t%s\n' "$(trim "$output")" ;;
    esac
}

format_openai_expiry() {
    local expires_ms="$1"
    python3 - "$expires_ms" <<'PY'
import datetime
import sys

raw = sys.argv[1].strip()
try:
    value = int(raw)
except Exception:
    print("n/a")
    raise SystemExit(0)

if value <= 0:
    print("n/a")
    raise SystemExit(0)

dt = datetime.datetime.fromtimestamp(value / 1000, tz=datetime.timezone.utc)
now = datetime.datetime.now(datetime.timezone.utc)
delta = int((dt - now).total_seconds())

if delta <= 0:
    rel = "expired"
else:
    hours, rem = divmod(delta, 3600)
    minutes = rem // 60
    if hours >= 24:
        rel = f"{hours // 24}d"
    elif hours > 0:
        rel = f"{hours}h{minutes:02d}"
    else:
        rel = f"{minutes}m"

local_dt = dt.astimezone()
print(f"{rel} {local_dt.strftime('%b%d %H:%M')}")
PY
}

humanize_openai_detail() {
    local detail="$1"
    python3 - "$detail" <<'PY'
import datetime
import re
import sys

text = sys.argv[1]
match = re.search(r'expired at (\d{13})', text)
if not match:
    print(text)
    raise SystemExit(0)

value = int(match.group(1))
dt = datetime.datetime.fromtimestamp(value / 1000, tz=datetime.timezone.utc).astimezone()
replacement = f"expired at {dt.strftime('%a %d %b %Y %H:%M:%S %Z')}"
print(text[:match.start()] + replacement + text[match.end():])
PY
}

render_separator() {
    printf '%s\n' "-----------------------------------------------------------------------------------------------"
}

state_rank() {
    local provider="$1"
    local state="$2"

    case "$provider:$state" in
        claude:HEALTHY|openai:AVAILABLE) printf '0' ;;
        claude:WARN|openai:TRANSIENT) printf '1' ;;
        claude:LIMITED|openai:LIMITED) printf '2' ;;
        claude:EXPIRED|openai:EXPIRED) printf '3' ;;
        claude:MISSING|openai:MISSING) printf '4' ;;
        openai:LOGIN) printf '5' ;;
        openai:DUPLICATE) printf '6' ;;
        *) printf '7' ;;
    esac
}

render_claude_section() {
    local claude_dirs=()
    local dir
    local rows=""
    if [[ -d "$HOME/.claude" ]]; then
        claude_dirs+=("$HOME/.claude")
    fi

    shopt -s nullglob
    for dir in "$HOME"/.claude-*; do
        [[ -d "$dir" ]] || continue
        claude_dirs+=("$dir")
    done
    shopt -u nullglob

    printf '%sClaude Code%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    if (( ${#claude_dirs[@]} == 0 )); then
        printf '  %sNo Claude subscription profiles found.%s\n\n' "$C_DIM" "$C_RESET"
        return
    fi

    if [[ "$COMPACT" == true ]]; then
        printf '  %-14s %-8s %-5s %-8s %-10s %-24s\n' \
            "Profile" "Plan" "Max" "State" "Reset" "Account"
    else
        printf '  %-16s %-10s %-7s %-7s %-7s %-15s %-15s %-10s %-26s\n' \
            "Profile" "Plan" "5h" "7d S" "7d O" "Reset 5h" "Reset 7d" "State" "Account"
    fi
    render_separator

    for dir in "${claude_dirs[@]}"; do
        local label display email billing
        local usage five seven opus reset5 reset7 state state_text
        IFS=$'\t' read -r display email billing <<<"$(get_claude_profile_info "$dir")"
        usage="$(get_claude_usage_row "$dir")"
        IFS=$'\t' read -r five seven opus reset5 reset7 state <<<"$usage"
        label="$(get_claude_profile_label "$dir")"
        billing="$(trim "$billing")"
        email="$(trim "$email")"
        state_text="$state"

        if [[ "$state_text" == ERROR:* ]]; then
            IFS=$'\t' read -r state_text email <<<"$(classify_claude_error "${state#ERROR:}")"
            five="n/a"
            seven="n/a"
            opus="n/a"
            reset5="null"
            reset7="null"
        fi

        if [[ -z "$billing" ]]; then
            billing="unknown"
        fi
        if [[ -z "$email" ]]; then
            email="$(trim "$display")"
        fi
        if [[ -z "$email" ]]; then
            email="-"
        fi

        count_claude_state "$state_text"

        if [[ "$state_text" == "EXPIRED" || "$state_text" == "MISSING" || "$state_text" == "ERROR" ]]; then
            append_unique CLAUDE_REPAIRS "$label"
        fi

        rows+="$(state_rank claude "$state_text")|$label|$billing|$five|$seven|$opus|$reset5|$reset7|$state_text|$email"$'\n'
    done

    while IFS='|' read -r _rank label billing five seven opus reset5 reset7 state_text email; do
        [[ -n "$label" ]] || continue
        if [[ "$COMPACT" == true ]]; then
            local max_pct max_reset
            if [[ "$five" =~ ^[0-9]+([.][0-9]+)?$ && "$seven" =~ ^[0-9]+([.][0-9]+)?$ && "$opus" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                max_pct=$(printf '%s\n%s\n%s\n' "$five" "$seven" "$opus" | sort -nr | awk 'NR==1{print; exit}')
            else
                max_pct="n/a"
            fi
            max_reset="$reset5"
            if [[ "$five" =~ ^[0-9]+([.][0-9]+)?$ && "$seven" =~ ^[0-9]+([.][0-9]+)?$ ]] && (( $(printf '%.0f' "$seven" 2>/dev/null || printf '0') >= $(printf '%.0f' "$five" 2>/dev/null || printf '0') )); then
                max_reset="$reset7"
            fi
            printf '  %-14s %-8s %-5s %-8b %-10s %-24s\n' \
                "$(shorten "$label" 14)" \
                "$(shorten "$billing" 8)" \
                "$(colorize_pct "$max_pct")" \
                "$(colorize_state "$state_text")" \
                "$(shorten "$(format_time "$max_reset")" 10)" \
                "$(shorten "$email" 24)"
        else
            printf '  %-16s %-10s %-7s %-7s %-7s %-15s %-15s %-10b %-26s\n' \
                "$(shorten "$label" 16)" \
                "$(shorten "$billing" 10)" \
                "$(colorize_pct "$five")" \
                "$(colorize_pct "$seven")" \
                "$(colorize_pct "$opus")" \
                "$(shorten "$(format_time "$reset5")" 15)" \
                "$(shorten "$(format_time "$reset7")" 15)" \
                "$(colorize_state "$state_text")" \
                "$(shorten "$email" 26)"
        fi
    done < <(printf '%s' "$rows" | sort -t'|' -k1,1n -k2,2)

    printf '\n'
}

render_openai_section() {
    local accounts_dir="$HOME/.opencode/accounts"
    local accounts_file="$accounts_dir/.accounts"
    local current_file="$accounts_dir/.current"
    local live_auth="$HOME/.local/share/opencode/auth.json"
    local current_idx=-1
    local live_access=""
    local rows=""

    printf '%sOpenAI / OpenCode%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"

    if [[ ! -f "$accounts_file" ]]; then
        printf '  %sNo OpenCode account rotation profiles found.%s\n\n' "$C_DIM" "$C_RESET"
        return
    fi

    if [[ -f "$current_file" ]]; then
        current_idx=$(trim "$(<"$current_file")")
    fi

    if [[ -f "$live_auth" ]]; then
        live_access=$(python3 - "$live_auth" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    print((data.get('openai') or {}).get('access') or '')
except Exception:
    print('')
PY
)
    fi

    if [[ "$COMPACT" == true ]]; then
        printf '  %-14s %-8s %-10s %-16s %-24s\n' \
            "Profile" "Plan" "State" "Expires" "Account"
    else
        printf '  %-16s %-10s %-12s %-18s %-10s %-30s\n' \
            "Profile" "Plan" "State" "Expires" "UID" "Account"
    fi
    render_separator

    local idx=0
    while IFS= read -r name || [[ -n "$name" ]]; do
        local acct_auth="$accounts_dir/$name/openai-auth.json"
        local marker=" "
        local email plan uid expires_ms access state detail expires_text duplicate_name

        [[ -n "$name" ]] || continue

        if [[ "$idx" == "$current_idx" ]]; then
            marker="*"
        fi

        if [[ ! -f "$acct_auth" ]]; then
            count_openai_state "MISSING"
            append_unique OPENAI_LOGIN_REPAIRS "$name"
            rows+="$(state_rank openai MISSING)|${marker}${name}|-|-|n/a|MISSING|missing saved auth|missing saved auth"$'\n'
            idx=$((idx + 1))
            continue
        fi

        IFS=$'\t' read -r email plan uid expires_ms access <<<"$(openai_saved_auth_info "$acct_auth")"
        duplicate_name="$(find_openai_duplicate_profile "$name" "$acct_auth" "$accounts_file")"
        if [[ -n "$duplicate_name" ]]; then
            state="DUPLICATE"
            detail="same as $duplicate_name"
        else
            IFS=$'\t' read -r state detail <<<"$(openai_probe_state "$acct_auth")"
        fi
        expires_text="$(format_openai_expiry "$expires_ms")"

        if [[ -n "$live_access" && -n "$access" && "$live_access" == "$access" ]]; then
            marker="*"
        fi

        count_openai_state "$state"

        if [[ "$state" == "DUPLICATE" ]]; then
            append_unique OPENAI_DUPLICATE_REPAIRS "$name ($detail)"
        elif [[ "$state" == "LOGIN" || "$state" == "MISSING" ]]; then
            append_unique OPENAI_LOGIN_REPAIRS "$name"
        elif [[ "$state" == "EXPIRED" || "$state" == "MISSING" || "$state" == "ERROR" ]]; then
            append_unique OPENAI_FIX_REPAIRS "$name"
        fi

        rows+="$(state_rank openai "$state")|${marker}${name}|$plan|$uid|$expires_text|$state|$email|$(humanize_openai_detail "$detail")"$'\n'

        idx=$((idx + 1))
    done <"$accounts_file"

    while IFS='|' read -r _rank name plan uid expires_text state email detail; do
        [[ -n "$name" ]] || continue
        if [[ "$COMPACT" == true ]]; then
            printf '  %-14s %-8s %-10b %-16s %-24s\n' \
                "$(shorten "$name" 14)" \
                "$(shorten "$plan" 8)" \
                "$(colorize_state "$state")" \
                "$(shorten "$expires_text" 16)" \
                "$(shorten "$email" 24)"
        else
            printf '  %-16s %-10s %-12b %-18s %-10s %-30s\n' \
                "$(shorten "$name" 16)" \
                "$(shorten "$plan" 10)" \
                "$(colorize_state "$state")" \
                "$(shorten "$expires_text" 18)" \
                "$(shorten "$uid" 10)" \
                "$(shorten "$email" 30)"

            if [[ -n "$detail" ]]; then
                printf '  %16s %s%s%s\n' "" "$C_DIM" "$(shorten "$detail" 96)" "$C_RESET"
            fi
        fi
    done < <(printf '%s' "$rows" | sort -t'|' -k1,1n -k2,2)

    printf '\n'
}

render_dashboard() {
    local now
    now="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    reset_summary_counters

    printf '%sSubscription Dashboard%s\n' "$C_BOLD$C_BLUE" "$C_RESET"
    printf '%sUpdated:%s %s\n' "$C_DIM" "$C_RESET" "$now"
    printf '%sLegend:%s %sactive%s current profile/account pointer\n\n' "$C_DIM" "$C_RESET" "$C_BOLD*" "$C_RESET"

    render_claude_section
    render_openai_section
    render_summary
    render_repairs
}

run_once() {
    render_dashboard
}

run_interactive() {
    INTERACTIVE_SESSION=true

    while true; do
        clear
        render_dashboard
        if (( ${#CLAUDE_REPAIRS[@]} > 0 || ${#OPENAI_FIX_REPAIRS[@]} > 0 || ${#OPENAI_LOGIN_REPAIRS[@]} > 0 )); then
            printf '%sRefresh:%s %ss  %sKeys:%s q quit, r repair/login, any other key refresh now\n' \
                "$C_DIM" "$C_RESET" "$INTERVAL" "$C_DIM" "$C_RESET"
        else
            printf '%sRefresh:%s %ss  %sKeys:%s q quit, any other key refresh now\n' \
                "$C_DIM" "$C_RESET" "$INTERVAL" "$C_DIM" "$C_RESET"
        fi

        if read -r -s -t "$INTERVAL" -n 1 key; then
            if [[ "$key" == 'q' || "$key" == 'Q' ]]; then
                break
            elif [[ "$key" == 'r' || "$key" == 'R' ]]; then
                launch_repair_menu
            fi
        fi
    done
}

if [[ "$ONCE" == true || ! -t 1 ]]; then
    run_once
else
    run_interactive
fi
