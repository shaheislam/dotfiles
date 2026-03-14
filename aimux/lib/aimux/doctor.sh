#!/usr/bin/env bash
# aimux doctor - health check for agent orchestration stack

_PASS="${GREEN}PASS${RESET}"
_WARN="${YELLOW}WARN${RESET}"
_FAIL="${RED}FAIL${RESET}"
_checks=0
_warnings=0
_failures=0

_check() {
    local label="$1" status="$2" detail="${3:-}"
    _checks=$((_checks + 1))
    case "$status" in
    pass) printf "  [${_PASS}] %s\n" "$label" ;;
    warn)
        printf "  [${_WARN}] %s" "$label"
        [[ -n "$detail" ]] && printf " — %s" "$detail"
        printf "\n"
        _warnings=$((_warnings + 1))
        ;;
    fail)
        printf "  [${_FAIL}] %s" "$label"
        [[ -n "$detail" ]] && printf " — %s" "$detail"
        printf "\n"
        _failures=$((_failures + 1))
        ;;
    esac
}

printf "${BOLD}aimux doctor${RESET}\n\n"

# 1. Required commands
printf "${BOLD}Dependencies${RESET}\n"
for cmd in tmux git bash; do
    if has "$cmd"; then
        _check "$cmd" pass
    else
        _check "$cmd" fail "not installed (required)"
    fi
done
for cmd in fzf jq docker; do
    if has "$cmd"; then
        _check "$cmd" pass
    else
        _check "$cmd" warn "not installed (optional)"
    fi
done
echo

# 2. tmux status
printf "${BOLD}tmux Status${RESET}\n"
if tmux info &>/dev/null; then
    session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
    _check "tmux server running ($session_count sessions)" pass
else
    _check "tmux server" warn "not running"
fi
echo

# 3. Agent watcher daemon
printf "${BOLD}Agent Watcher${RESET}\n"
watcher_pid="/tmp/aimux-daemon.pid"
if [[ -f "$watcher_pid" ]] && kill -0 "$(cat "$watcher_pid")" 2>/dev/null; then
    _check "aimux daemon" pass
else
    # Check legacy watcher too
    legacy_pid="/tmp/tmux-claude-watcher.pid"
    if [[ -f "$legacy_pid" ]] && kill -0 "$(cat "$legacy_pid")" 2>/dev/null; then
        _check "tmux-claude-watcher (legacy)" pass
    else
        _check "agent watcher daemon" warn "not running (start with: aimux daemon start)"
    fi
fi
echo

# 4. Git worktrees
printf "${BOLD}Git Worktrees${RESET}\n"
root="$(git_root)"
if [[ -n "$root" ]]; then
    wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
    prunable=$(git worktree list --porcelain 2>/dev/null | grep -c "^prunable" || true)
    _check "git repo detected ($wt_count worktrees)" pass
    if [[ "$prunable" -gt 0 ]]; then
        _check "prunable worktrees" warn "$prunable found (run: git worktree prune)"
    fi
else
    _check "git repo" warn "not in a git repository"
fi
echo

# 5. aimux home
printf "${BOLD}Configuration${RESET}\n"
if [[ -d "$AIMUX_HOME" ]]; then
    _check "~/.aimux directory" pass
else
    _check "~/.aimux directory" warn "not created yet (will be created on first use)"
fi

# Config file
if [[ -f "$AIMUX_HOME/config.toml" ]]; then
    _check "config.toml" pass
else
    _check "config.toml" warn "not found (using defaults, copy from: aimux config/default.toml)"
fi

# Go daemon binary
if has aimuxd; then
    _check "aimuxd (Go daemon)" pass
elif [[ -f "${AIMUX_DIR:-}/lib/aimux/aimuxd" ]]; then
    _check "aimuxd (Go daemon)" pass "found in lib"
else
    _check "aimuxd (Go daemon)" warn "not found (optional, bash daemon used as fallback)"
fi
echo

# 6. State directory health
printf "${BOLD}State Health${RESET}\n"
if [[ -d "$AIMUX_STATE_DIR" ]]; then
    state_count=0
    for _sf in "$AIMUX_STATE_DIR"/*.json; do
        [[ -f "$_sf" ]] && state_count=$((state_count + 1))
    done
    _check "state files ($state_count tracked)" pass

    # Check for orphaned state files
    orphans=0
    for sf in "$AIMUX_STATE_DIR"/*.json; do
        [[ -f "$sf" ]] || continue
        ws_name="$(basename "$sf" .json)"
        wt_path="$(state_read "$ws_name" "worktree" "")"
        if [[ -n "$wt_path" && ! -d "$wt_path" ]]; then
            orphans=$((orphans + 1))
        fi
    done
    if [[ "$orphans" -gt 0 ]]; then
        _check "orphaned state files" warn "$orphans state files reference missing worktrees"
    fi
else
    _check "state directory" warn "not created yet"
fi
echo

# 7. Providers
printf "${BOLD}AI Providers${RESET}\n"
for prov in $(provider_list 2>/dev/null); do
    _prov_cmd="$(cfg_get "providers.${prov}.command" "$prov")"
    if has "$_prov_cmd"; then
        _check "provider: $prov ($_prov_cmd)" pass
    else
        _check "provider: $prov ($_prov_cmd)" warn "command not found"
    fi
done

# Fallback if provider_list unavailable
if ! provider_list &>/dev/null; then
    if has claude; then
        _check "claude CLI" pass
    else
        _check "claude CLI" warn "not installed"
    fi
    if has codex; then
        _check "codex CLI" pass
    else
        _check "codex CLI" warn "not installed (optional)"
    fi
fi
echo

# Summary
printf "${BOLD}Summary${RESET}: %d checks, " "$_checks"
[[ "$_warnings" -gt 0 ]] && printf "${YELLOW}%d warnings${RESET}, " "$_warnings" || printf "0 warnings, "
[[ "$_failures" -gt 0 ]] && printf "${RED}%d failures${RESET}\n" "$_failures" || printf "0 failures\n"

[[ "$_failures" -gt 0 ]] && exit 1
exit 0
