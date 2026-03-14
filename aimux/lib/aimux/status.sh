#!/usr/bin/env bash
# aimux status - show all workspaces with agent state

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        echo "Usage: aimux status [--all]"
        exit 0
        ;;
    *) shift ;;
    esac
done

root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"

current_wt="$root"

# Header
printf "${BOLD}%-40s %-25s %-12s %-10s${RESET}\n" "WORKTREE" "BRANCH" "CONTAINER" "AGENT"
printf "%-40s %-25s %-12s %-10s\n" \
    "$(printf '%0.s─' {1..40})" \
    "$(printf '%0.s─' {1..25})" \
    "$(printf '%0.s─' {1..12})" \
    "$(printf '%0.s─' {1..10})"

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

        # Truncate path for display
        display_path="$wt_path"
        if [[ ${#display_path} -gt 38 ]]; then
            display_path="…${display_path: -37}"
        fi

        # Current worktree marker
        marker=" "
        [[ "$wt_path" == "$current_wt" ]] && marker="*"

        # Container status
        container_status="-"
        instance_name="$(basename "$wt_path" | sed 's/\//-/g')"
        if [[ -d "$HOME/.devcontainer/instances/$instance_name" ]]; then
            if has docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$instance_name"; then
                container_status="${GREEN}running${RESET}"
            else
                container_status="${DIM}stopped${RESET}"
            fi
        fi

        # Agent state — check tmux windows matching this branch
        agent_state="-"
        if in_tmux; then
            session="$(tmux_session)"
            # Find window for this branch and check its @wname_style
            win_idx=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
                grep ":${branch}$" | head -1 | cut -d: -f1 || true)
            if [[ -n "$win_idx" ]]; then
                wstyle=$(tmux show-window-option -t "$session:$win_idx" -v @wname_style 2>/dev/null || echo "")
                case "$wstyle" in
                *"$COLOR_WORKING"*) agent_state="${RED}working${RESET}" ;;
                *"$COLOR_WAITING"*) agent_state="${YELLOW}waiting${RESET}" ;;
                *"$COLOR_DONE"*) agent_state="${GREEN}done${RESET}" ;;
                *"$COLOR_STUCK"*) agent_state="${MAGENTA}stuck${RESET}" ;;
                esac
            fi
        fi

        printf "%s%-39b %-25s %-12b %-10b\n" \
            "$marker" "$display_path" "${branch:-detached}" "$container_status" "$agent_state"

        wt_path=""
        branch=""
        ;;
    esac
done < <(git worktree list --porcelain 2>/dev/null)
