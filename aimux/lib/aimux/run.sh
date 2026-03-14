#!/usr/bin/env bash
# aimux run - autonomous ticket execution

_run_ticket=""
_run_prompt=""
_run_max=20
_run_provider="claude"
_run_command="/ralph-wiggum:ralph-loop"
_run_no_devcon=false
_run_mounts=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --max)
        _run_max="$2"
        shift 2
        ;;
    --provider)
        _run_provider="$2"
        shift 2
        ;;
    --command)
        _run_command="$2"
        shift 2
        ;;
    --no-devcon)
        _run_no_devcon=true
        shift
        ;;
    --mount | -m)
        _run_mounts+=("$2")
        shift 2
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux run [options] <ticket-key> [prompt]

Execute a ticket autonomously with agent retry loop

Options:
  --max N           Max iterations (default: 20)
  --provider NAME   AI provider: claude, codex (default: claude)
  --command CMD     Slash command (default: /ralph-wiggum:ralph-loop)
  --no-devcon       Skip devcontainer
  -m, --mount DIR   Additional mount (repeatable)
  -h, --help        Show this help

Examples:
  aimux run PROJ-123 "Fix the auth bug"
  aimux run TASK-456 --max 10 "Refactor utils"
  aimux run FEAT-789 --provider codex "Add tests"
HELP
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        if [[ -z "$_run_ticket" ]]; then
            _run_ticket="$1"
        else
            _run_prompt="${_run_prompt:+$_run_prompt }$1"
        fi
        shift
        ;;
    esac
done

[[ -z "$_run_ticket" ]] && die "Usage: aimux run <ticket-key> [prompt]"
require git
require tmux

# Generate branch name from ticket
branch_name="$(echo "$_run_ticket" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"

root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"
repo_name="$(basename "$root")"
wt_path="$(dirname "$root")/${repo_name}-${branch_name}"

# Create workspace (reuse new.sh logic)
_new_args=("$branch_name")
$_run_no_devcon && _new_args+=("--no-devcon")
for mount in "${_run_mounts[@]}"; do
    _new_args+=("--mount" "$mount")
done

# Source new.sh to create workspace
(
    # Reset new.sh's parsed state
    _new_branch=""
    _new_create=false
    _new_no_devcon=$_run_no_devcon
    _new_exec=false
    _new_rebuild=false
    _new_fast=false
    _new_mounts=("${_run_mounts[@]}")
    _new_features=""
    source "$AIMUX_LIB/new.sh" "${_new_args[@]}" 2>&1
) || true

# Build agent launch command
case "$_run_provider" in
claude)
    if [[ -n "$_run_prompt" ]]; then
        agent_cmd="claude --effort max -p \"$_run_command \\\"$_run_prompt\\\"\""
    else
        agent_cmd="claude --effort max"
    fi
    ;;
codex)
    if [[ -n "$_run_prompt" ]]; then
        agent_cmd="codex --full-auto \"$_run_prompt\""
    else
        agent_cmd="codex"
    fi
    ;;
*) die "Unknown provider: $_run_provider" ;;
esac

# Launch agent in the workspace's tmux window
if in_tmux; then
    session="$(tmux_session)"
    window=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
        grep ":${branch_name}" | head -1 | cut -d: -f1 || true)

    if [[ -n "$window" ]]; then
        tmux send-keys -t "$session:$window" "cd $wt_path && $agent_cmd" Enter
        info "Agent launched in $session:$window"
    else
        warn "tmux window not found for $branch_name, running in current pane"
        info "Run: cd $wt_path && $agent_cmd"
    fi
else
    info "Not in tmux. To run manually:"
    echo "  cd $wt_path && $agent_cmd"
fi

printf "\n${BOLD}Ticket execution started${RESET}\n"
printf "  Ticket:     %s\n" "$_run_ticket"
printf "  Branch:     %s\n" "$branch_name"
printf "  Provider:   %s\n" "$_run_provider"
printf "  Max iters:  %d\n" "$_run_max"
[[ -n "$_run_prompt" ]] && printf "  Prompt:     %s\n" "$_run_prompt"

log "run: started $_run_ticket via $_run_provider (max: $_run_max)"
