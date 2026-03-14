#!/usr/bin/env bash
# aimux status - show all workspaces with agent state

_status_json=false
_status_all=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --json | -j)
        _status_json=true
        shift
        ;;
    --all | -a)
        _status_all=true
        shift
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux status [options]

Show all workspaces with agent state

Options:
  -j, --json     Machine-readable JSON output
  -a, --all      Include state-file workspaces even outside current repo
  -h, --help     Show this help
HELP
        exit 0
        ;;
    *) shift ;;
    esac
done

ensure_home

# Collect workspace data from state files + live git queries
declare -a _ws_names=()
declare -A _ws_data=()

# 1. Read state files first (preferred source)
if [[ -d "$AIMUX_STATE_DIR" ]]; then
    for sf in "$AIMUX_STATE_DIR"/*.json; do
        [[ -f "$sf" ]] || continue
        local_name="$(basename "$sf" .json)"
        _ws_names+=("$local_name")
        _ws_data["${local_name}_source"]="state"
        _ws_data["${local_name}_status"]="$(state_read "$local_name" "status" "unknown")"
        _ws_data["${local_name}_branch"]="$(state_read "$local_name" "branch" "")"
        _ws_data["${local_name}_worktree"]="$(state_read "$local_name" "worktree" "")"
        _ws_data["${local_name}_provider"]="$(state_read "$local_name" "provider" "")"
        _ws_data["${local_name}_ticket"]="$(state_read "$local_name" "ticket" "")"
        _ws_data["${local_name}_created"]="$(state_read "$local_name" "created" "")"
    done
fi

# 2. Supplement with live git worktree data if in a repo
root="$(git_root)"
if [[ -n "$root" ]]; then
    current_wt="$root"
    repo_name="$(basename "$root")"

    wt_path=""
    branch=""

    while IFS= read -r line; do
        case "$line" in
        "worktree "*)
            wt_path="${line#worktree }"
            branch=""
            ;;
        "branch "*)
            branch="${line#branch refs/heads/}"
            ;;
        "detached")
            branch="(detached)"
            ;;
        "")
            [[ -z "$wt_path" ]] && continue

            local_name="$(basename "$wt_path" | sed 's/\//-/g')"

            # Skip if already tracked via state file
            if [[ -z "${_ws_data[${local_name}_source]:-}" ]]; then
                _ws_names+=("$local_name")
                _ws_data["${local_name}_source"]="live"
                _ws_data["${local_name}_branch"]="$branch"
                _ws_data["${local_name}_worktree"]="$wt_path"
                _ws_data["${local_name}_status"]=""
                _ws_data["${local_name}_provider"]=""
                _ws_data["${local_name}_ticket"]=""
            fi

            # Live container status
            container_status="-"
            if [[ -d "$HOME/.devcontainer/instances/$local_name" ]]; then
                if has docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$local_name"; then
                    container_status="running"
                else
                    container_status="stopped"
                fi
            fi
            _ws_data["${local_name}_container"]="$container_status"

            # Live agent state from tmux
            agent_state=""
            if in_tmux; then
                session="$(tmux_session)"
                win_idx=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
                    grep ":${branch}$" | head -1 | cut -d: -f1 || true)
                if [[ -n "$win_idx" ]]; then
                    wstyle=$(tmux show-window-option -t "$session:$win_idx" -v @wname_style 2>/dev/null || echo "")
                    case "$wstyle" in
                    *"$COLOR_WORKING"*) agent_state="working" ;;
                    *"$COLOR_WAITING"*) agent_state="waiting" ;;
                    *"$COLOR_DONE"*) agent_state="done" ;;
                    *"$COLOR_STUCK"*) agent_state="stuck" ;;
                    esac
                fi
            fi

            # Prefer state-file status, fall back to live
            if [[ -z "${_ws_data[${local_name}_status]:-}" || "${_ws_data[${local_name}_status]}" == "unknown" ]]; then
                _ws_data["${local_name}_status"]="${agent_state:-"-"}"
            fi

            # Mark current worktree
            if [[ "$wt_path" == "${current_wt:-}" ]]; then
                _ws_data["${local_name}_current"]="true"
            fi

            wt_path=""
            branch=""
            ;;
        esac
    done < <(git worktree list --porcelain 2>/dev/null)
fi

# --- Output ---

if $_status_json; then
    # JSON output
    printf "["
    local_first=true
    for name in "${_ws_names[@]}"; do
        $local_first || printf ","
        local_first=false
        printf '{"name":"%s"' "$name"
        printf ',"branch":"%s"' "${_ws_data[${name}_branch]:-}"
        printf ',"worktree":"%s"' "${_ws_data[${name}_worktree]:-}"
        printf ',"status":"%s"' "${_ws_data[${name}_status]:-}"
        printf ',"provider":"%s"' "${_ws_data[${name}_provider]:-}"
        printf ',"ticket":"%s"' "${_ws_data[${name}_ticket]:-}"
        printf ',"container":"%s"' "${_ws_data[${name}_container]:-"-"}"
        printf ',"source":"%s"' "${_ws_data[${name}_source]:-}"
        printf '}'
    done
    printf "]\n"
    exit 0
fi

# Table output
printf "${BOLD}%-40s %-25s %-12s %-10s %-10s${RESET}\n" "WORKTREE" "BRANCH" "CONTAINER" "AGENT" "PROVIDER"
printf "%-40s %-25s %-12s %-10s %-10s\n" \
    "$(printf '%0.s─' {1..40})" \
    "$(printf '%0.s─' {1..25})" \
    "$(printf '%0.s─' {1..12})" \
    "$(printf '%0.s─' {1..10})" \
    "$(printf '%0.s─' {1..10})"

for name in "${_ws_names[@]}"; do
    local_branch="${_ws_data[${name}_branch]:-detached}"
    local_wt="${_ws_data[${name}_worktree]:-}"
    local_status="${_ws_data[${name}_status]:-"-"}"
    local_container="${_ws_data[${name}_container]:-"-"}"
    local_provider="${_ws_data[${name}_provider]:-"-"}"
    local_current="${_ws_data[${name}_current]:-}"

    # Truncate path for display
    display_path="$local_wt"
    if [[ ${#display_path} -gt 38 ]]; then
        display_path="…${display_path: -37}"
    fi

    # Current worktree marker
    marker=" "
    [[ "$local_current" == "true" ]] && marker="*"

    # Colorize container
    case "$local_container" in
    running) container_display="${GREEN}running${RESET}" ;;
    stopped) container_display="${DIM}stopped${RESET}" ;;
    *) container_display="-" ;;
    esac

    # Colorize agent state
    case "$local_status" in
    working | active | running) status_display="${RED}working${RESET}" ;;
    waiting | idle) status_display="${YELLOW}waiting${RESET}" ;;
    done | completed) status_display="${GREEN}done${RESET}" ;;
    stuck) status_display="${MAGENTA}stuck${RESET}" ;;
    failed) status_display="${RED}failed${RESET}" ;;
    *) status_display="-" ;;
    esac

    printf "%s%-39b %-25s %-12b %-10b %-10s\n" \
        "$marker" "$display_path" "$local_branch" "$container_display" "$status_display" "$local_provider"
done
