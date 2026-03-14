#!/usr/bin/env bash
# aimux run - autonomous ticket execution with provider + witness

_run_ticket=""
_run_prompt=""
_run_max_retries=3
_run_provider=""
_run_template=""
_run_no_witness=false
_run_no_devcon=false
_run_repo=""
_run_mounts=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --max-retries | --max)
        _run_max_retries="$2"
        shift 2
        ;;
    --provider | -P)
        _run_provider="$2"
        shift 2
        ;;
    --template | -T)
        _run_template="$2"
        shift 2
        ;;
    --no-witness)
        _run_no_witness=true
        shift
        ;;
    --no-devcon)
        _run_no_devcon=true
        shift
        ;;
    --repo)
        _run_repo="$2"
        shift 2
        ;;
    --mount | -m)
        _run_mounts+=("$2")
        shift 2
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux run [options] <ticket> [prompt...]

Execute a ticket autonomously: create workspace, launch AI agent, monitor lifecycle

Options:
  -P, --provider NAME   AI provider: claude, codex, ollama (default: from config)
  --max-retries N        Max restart attempts on stuck (default: 3)
  -T, --template FILE    Custom launch template (overrides provider default)
  --no-witness           Skip witness lifecycle monitor
  --no-devcon            Skip devcontainer
  --repo DIR             Git repo directory (instead of detecting from cwd)
  -m, --mount DIR        Additional mount (repeatable)
  -h, --help             Show this help

Examples:
  aimux run PROJ-123 "Fix the auth bug"
  aimux run TASK-456 --provider codex "Add unit tests"
  aimux run FEAT-789 --max-retries 5 --no-witness "Refactor utils"
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

[[ -z "$_run_ticket" ]] && die "Usage: aimux run <ticket> [prompt]"
require git
require tmux

# Default provider from config
[[ -z "$_run_provider" ]] && _run_provider="$(cfg_get "general.default_provider" "claude")"

# Load provider
provider_load "$_run_provider" || die "Failed to load provider: $_run_provider"

# Generate branch name from ticket
branch_name="$(echo "$_run_ticket" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"

# Resolve repo root
if [[ -n "$_run_repo" ]]; then
    root="$(cd "$_run_repo" && git_root)"
    [[ -z "$root" ]] && die "Not a git repository: $_run_repo"
else
    root="$(git_root)"
    [[ -z "$root" ]] && die "Not in a git repository"
fi

repo_name="$(basename "$root")"
wt_path="$(dirname "$root")/${repo_name}-${branch_name}"
instance_name="${repo_name}-${branch_name//\//-}"

# --- Step 1: Create workspace via new.sh ---
info "Creating workspace: $branch_name"
(
    _new_branch="$branch_name"
    _new_create=false
    _new_no_devcon=$_run_no_devcon
    _new_exec=false
    _new_rebuild=false
    _new_fast=false
    _new_mounts=("${_run_mounts[@]}")
    _new_features=""
    _new_repo="$_run_repo"
    source "$AIMUX_LIB/new.sh" "$branch_name" ${_run_no_devcon:+--no-devcon} ${_run_repo:+--repo "$_run_repo"} 2>&1
) || true

# --- Step 2: Build launch script from template ---
_tmpl_file=""
if [[ -n "$_run_template" && -f "$_run_template" ]]; then
    _tmpl_file="$_run_template"
elif [[ -f "$AIMUX_HOME/templates/launch/${_run_provider}.sh.tmpl" ]]; then
    _tmpl_file="$AIMUX_HOME/templates/launch/${_run_provider}.sh.tmpl"
elif [[ -f "$AIMUX_DIR/templates/launch/${_run_provider}.sh.tmpl" ]]; then
    _tmpl_file="$AIMUX_DIR/templates/launch/${_run_provider}.sh.tmpl"
fi

# Get launch command from provider
_launch_cmd="$(provider_launch_cmd "$_run_provider" "$wt_path" "$_run_prompt")"

# Parse command and args from launch cmd for template substitution
_cmd_bin="$(cfg_get "providers.${_run_provider}.command" "$_run_provider")"
_cmd_args_raw="$(cfg_get "providers.${_run_provider}.args" "")"
_cmd_args="$(echo "$_cmd_args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

if [[ -n "$_tmpl_file" && -n "$_run_prompt" ]]; then
    # Write launch script from template
    mkdir -p "$wt_path/.aimux"
    _launch_script="$wt_path/.aimux/launch.sh"

    sed \
        -e "s|{{WORKTREE}}|${wt_path}|g" \
        -e "s|{{COMMAND}}|${_cmd_bin}|g" \
        -e "s|{{ARGS}}|${_cmd_args}|g" \
        -e "s|{{PROMPT}}|${_run_prompt}|g" \
        -e "s|{{ENV_SETUP}}||g" \
        "$_tmpl_file" >"$_launch_script"

    chmod +x "$_launch_script"
    info "Launch script written: $_launch_script"
else
    # No template or no prompt — use direct command
    _launch_script=""
fi

# --- Step 3: Set up tmux and launch ---
_tmux_target=""

if in_tmux; then
    session="$(tmux_session)"
    window=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
        grep ":${branch_name}" | head -1 | cut -d: -f1 || true)

    if [[ -n "$window" ]]; then
        _tmux_target="$session:$window"
        # Get pane target
        _pane_target="${_tmux_target}.0"

        if [[ -n "$_launch_script" ]]; then
            tmux send-keys -t "$_pane_target" "bash $_launch_script" Enter
        else
            tmux send-keys -t "$_pane_target" "cd $wt_path && $_launch_cmd" Enter
        fi
        info "Agent launched in $session:$window"
    else
        warn "tmux window not found for $branch_name"
        if [[ -n "$_launch_script" ]]; then
            info "Run manually: bash $_launch_script"
        else
            info "Run manually: cd $wt_path && $_launch_cmd"
        fi
    fi
else
    info "Not in tmux. To run manually:"
    if [[ -n "$_launch_script" ]]; then
        echo "  bash $_launch_script"
    else
        echo "  cd $wt_path && $_launch_cmd"
    fi
fi

# --- Step 4: Write state file ---
ensure_home
state_write "$instance_name" \
    status=running \
    branch="$branch_name" \
    worktree="$wt_path" \
    repo="$root" \
    provider="$_run_provider" \
    ticket="$_run_ticket" \
    prompt="$_run_prompt" \
    tmux_target="${_pane_target:-}" \
    started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    max_retries="$_run_max_retries"

# --- Step 5: Start witness ---
if ! $_run_no_witness && [[ -n "$_tmux_target" ]]; then
    witness_start "$instance_name" "$(state_file "$instance_name")" "$_run_max_retries"
fi

# --- Summary ---
printf "\n${BOLD}Ticket execution started${RESET}\n"
printf "  Ticket:       %s\n" "$_run_ticket"
printf "  Branch:       %s\n" "$branch_name"
printf "  Provider:     %s\n" "$_run_provider"
printf "  Max retries:  %d\n" "$_run_max_retries"
[[ -n "$_run_prompt" ]] && printf "  Prompt:       %s\n" "$_run_prompt"
$_run_no_witness && printf "  Witness:      disabled\n" || printf "  Witness:      active\n"

log "run: started $_run_ticket via $_run_provider (max_retries: $_run_max_retries)"
