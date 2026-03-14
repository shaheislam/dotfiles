# aimux Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Package existing tmux agent orchestration into `aimux`, a brew-installable CLI tool for managing AI coding agents in any terminal.

**Architecture:** Bash CLI dispatcher (`bin/aimux`) that sources subcommand scripts from `lib/aimux/`. Shared utilities in `lib/aimux/_common.sh`. Existing bash daemon scripts copied with minimal changes. Fish functions ported to POSIX-compatible bash.

**Tech Stack:** Bash 4+, tmux, fzf, jq, git, BATS (testing)

---

### Task 1: Scaffold aimux directory structure

**Files:**
- Create: `aimux/bin/aimux`
- Create: `aimux/lib/aimux/_common.sh`
- Create: `aimux/lib/aimux/help.sh`
- Create: `aimux/lib/aimux/version.sh`
- Create: `aimux/Makefile`
- Create: `aimux/LICENSE`

**Step 1: Create directory structure**

```bash
mkdir -p aimux/{bin,lib/aimux,config,completions,tests,docs,Formula}
```

**Step 2: Write the CLI dispatcher**

Create `aimux/bin/aimux`:

```bash
#!/usr/bin/env bash
# aimux - AI Agent Multiplexer
# Terminal-agnostic agent orchestration for tmux
set -euo pipefail

AIMUX_VERSION="0.1.0"
AIMUX_HOME="${AIMUX_HOME:-$HOME/.aimux}"
AIMUX_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")/.." && pwd)"
AIMUX_LIB="$AIMUX_DIR/lib/aimux"

# Source shared utilities
source "$AIMUX_LIB/_common.sh"

case "${1:-help}" in
  new)       shift; source "$AIMUX_LIB/new.sh" ;;
  status|st) shift; source "$AIMUX_LIB/status.sh" ;;
  run)       shift; source "$AIMUX_LIB/run.sh" ;;
  attach|a)  shift; source "$AIMUX_LIB/attach.sh" ;;
  kill|k)    shift; source "$AIMUX_LIB/kill.sh" ;;
  doctor)    shift; source "$AIMUX_LIB/doctor.sh" ;;
  queue|q)   shift; source "$AIMUX_LIB/queue.sh" ;;
  notify|n)  shift; source "$AIMUX_LIB/notify.sh" ;;
  daemon)    shift; source "$AIMUX_LIB/daemon.sh" ;;
  version|-v|--version) echo "aimux $AIMUX_VERSION" ;;
  help|-h|--help|*)     source "$AIMUX_LIB/help.sh" ;;
esac
```

**Step 3: Write _common.sh with shared utilities**

Create `aimux/lib/aimux/_common.sh`:

```bash
#!/usr/bin/env bash
# Shared utilities for aimux

# Colors (Tokyo Night palette)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Agent state colors (Tokyo Night)
COLOR_WORKING="#f7768e"   # Red
COLOR_WAITING="#e0af68"   # Orange/Yellow
COLOR_DONE="#9ece6a"      # Green
COLOR_STUCK="#bb9af7"     # Magenta
COLOR_IDLE=""             # Default

# Config
AIMUX_HOME="${AIMUX_HOME:-$HOME/.aimux}"
AIMUX_CONFIG="$AIMUX_HOME/config.yaml"
AIMUX_STATE_DIR="$AIMUX_HOME/workspaces"
AIMUX_LOG="$AIMUX_HOME/aimux.log"

# Ensure aimux home exists
ensure_home() {
  mkdir -p "$AIMUX_HOME" "$AIMUX_STATE_DIR" 2>/dev/null || true
}

# Print helpers
info()  { printf "${BLUE}info${RESET}: %s\n" "$*"; }
warn()  { printf "${YELLOW}warn${RESET}: %s\n" "$*" >&2; }
error() { printf "${RED}error${RESET}: %s\n" "$*" >&2; }
die()   { error "$@"; exit 1; }

# Check if command exists
has() { command -v "$1" &>/dev/null; }

# Require a command or die
require() {
  has "$1" || die "Required command not found: $1"
}

# Get git repo root (or empty string)
git_root() {
  git rev-parse --show-toplevel 2>/dev/null || echo ""
}

# Get git common dir (bare repo root for worktrees)
git_common_dir() {
  git rev-parse --git-common-dir 2>/dev/null || echo ""
}

# Get current branch name
git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# Check if inside tmux
in_tmux() {
  [[ -n "${TMUX:-}" ]]
}

# Get tmux session name
tmux_session() {
  tmux display-message -p '#S' 2>/dev/null || echo ""
}

# Get tmux window index
tmux_window() {
  tmux display-message -p '#I' 2>/dev/null || echo ""
}

# Sanitize string for use as tmux window/session name
sanitize_name() {
  echo "$1" | sed 's/[^a-zA-Z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Log to file
log() {
  ensure_home
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$AIMUX_LOG"
}
```

**Step 4: Write help.sh**

Create `aimux/lib/aimux/help.sh`:

```bash
#!/usr/bin/env bash
cat <<'EOF'
aimux - AI Agent Multiplexer
Terminal-agnostic agent orchestration for tmux

USAGE:
  aimux <command> [options]

COMMANDS:
  new <branch>        Create workspace (worktree + tmux window)
  status              Show all workspaces with agent state
  run <ticket> [msg]  Execute ticket autonomously
  attach <name>       Attach to workspace
  kill <name>         Kill workspace + cleanup worktree
  doctor              Health check
  queue               Ticket queue management
  notify <msg>        Send notification
  daemon              Agent state monitoring daemon
  version             Show version
  help                Show this help

EXAMPLES:
  aimux new feature-auth        Create workspace for feature-auth branch
  aimux status                  Show all workspaces
  aimux run PROJ-123 "Fix bug"  Execute ticket autonomously
  aimux kill feature-auth       Kill workspace and cleanup

DOCS: https://github.com/<org>/aimux
EOF
```

**Step 5: Write Makefile**

Create `aimux/Makefile`:

```makefile
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/aimux
SHAREDIR = $(PREFIX)/share/aimux
FISH_COMP = $(PREFIX)/share/fish/vendor_completions.d
BASH_COMP = $(PREFIX)/etc/bash_completion.d
ZSH_COMP = $(PREFIX)/share/zsh/site-functions

.PHONY: install uninstall test lint

install:
	@echo "Installing aimux to $(PREFIX)..."
	install -d $(BINDIR) $(LIBDIR) $(SHAREDIR)
	install -m 755 bin/aimux $(BINDIR)/aimux
	install -m 644 lib/aimux/*.sh $(LIBDIR)/
	if [ -d completions ]; then \
		install -d $(FISH_COMP) $(BASH_COMP) $(ZSH_COMP); \
		[ -f completions/aimux.fish ] && install -m 644 completions/aimux.fish $(FISH_COMP)/; \
		[ -f completions/aimux.bash ] && install -m 644 completions/aimux.bash $(BASH_COMP)/; \
		[ -f completions/_aimux ] && install -m 644 completions/_aimux $(ZSH_COMP)/; \
	fi
	@echo "Done. Run 'aimux doctor' to verify installation."

uninstall:
	rm -f $(BINDIR)/aimux
	rm -rf $(LIBDIR)
	rm -rf $(SHAREDIR)
	rm -f $(FISH_COMP)/aimux.fish $(BASH_COMP)/aimux.bash $(ZSH_COMP)/_aimux

test:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "BATS not found. Install with: brew install bats-core"; \
	fi

lint:
	@shellcheck bin/aimux lib/aimux/*.sh
```

**Step 6: Write MIT LICENSE**

Create `aimux/LICENSE` with standard MIT license text.

**Step 7: Verify structure and commit**

```bash
ls -la aimux/bin/ aimux/lib/aimux/
chmod +x aimux/bin/aimux
aimux/bin/aimux help
aimux/bin/aimux version
git add aimux/
git commit -m "feat: scaffold aimux CLI structure with dispatcher and shared utilities"
```

---

### Task 2: Implement aimux doctor (health check)

**Files:**
- Create: `aimux/lib/aimux/doctor.sh`
- Create: `aimux/tests/test_doctor.bats`
- Reference: `.config/fish/functions/gwt-doctor.fish`

**Step 1: Write the failing test**

Create `aimux/tests/test_doctor.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

@test "aimux doctor runs without error" {
  run aimux doctor
  [ "$status" -eq 0 ]
}

@test "aimux doctor checks tmux" {
  run aimux doctor
  [[ "$output" == *"tmux"* ]]
}

@test "aimux doctor checks git" {
  run aimux doctor
  [[ "$output" == *"git"* ]]
}

@test "aimux doctor checks fzf" {
  run aimux doctor
  [[ "$output" == *"fzf"* ]]
}
```

**Step 2: Run test to verify it fails**

```bash
cd aimux && bats tests/test_doctor.bats
```

Expected: FAIL (doctor.sh doesn't exist yet)

**Step 3: Write doctor.sh**

Create `aimux/lib/aimux/doctor.sh` — port from `gwt-doctor.fish`:

```bash
#!/usr/bin/env bash
# aimux doctor - health check for agent orchestration stack

PASS="${GREEN}PASS${RESET}"
WARN="${YELLOW}WARN${RESET}"
FAIL="${RED}FAIL${RESET}"
checks=0
warnings=0
failures=0

check() {
  local label="$1"
  local status="$2"
  local detail="${3:-}"
  ((checks++))
  case "$status" in
    pass) printf "  [${PASS}] %s\n" "$label" ;;
    warn) printf "  [${WARN}] %s" "$label"
          [[ -n "$detail" ]] && printf " — %s" "$detail"
          printf "\n"
          ((warnings++)) ;;
    fail) printf "  [${FAIL}] %s" "$label"
          [[ -n "$detail" ]] && printf " — %s" "$detail"
          printf "\n"
          ((failures++)) ;;
  esac
}

printf "${BOLD}aimux doctor${RESET}\n\n"

# 1. Required commands
printf "${BOLD}Dependencies${RESET}\n"
for cmd in tmux git fzf jq bash; do
  if has "$cmd"; then
    ver="$($cmd --version 2>/dev/null | head -1 || echo "installed")"
    check "$cmd" pass
  else
    if [[ "$cmd" == "fzf" || "$cmd" == "jq" ]]; then
      check "$cmd" warn "not installed (optional)"
    else
      check "$cmd" fail "not installed (required)"
    fi
  fi
done
echo

# 2. tmux running
printf "${BOLD}tmux Status${RESET}\n"
if tmux info &>/dev/null; then
  session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
  check "tmux server running ($session_count sessions)" pass
else
  check "tmux server" warn "not running"
fi
echo

# 3. Agent watcher
printf "${BOLD}Agent Watcher${RESET}\n"
watcher_pid="/tmp/tmux-claude-watcher.pid"
if [[ -f "$watcher_pid" ]] && kill -0 "$(cat "$watcher_pid")" 2>/dev/null; then
  check "tmux-claude-watcher daemon" pass
else
  check "tmux-claude-watcher daemon" warn "not running (start with: aimux daemon start)"
fi
echo

# 4. Git worktrees
printf "${BOLD}Git Worktrees${RESET}\n"
root="$(git_root)"
if [[ -n "$root" ]]; then
  wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  prunable=$(git worktree list --porcelain 2>/dev/null | grep -c "^prunable" || true)
  check "git repo detected ($wt_count worktrees)" pass
  if [[ "$prunable" -gt 0 ]]; then
    check "prunable worktrees" warn "$prunable (run: git worktree prune)"
  fi
else
  check "git repo" warn "not in a git repository"
fi
echo

# 5. aimux home
printf "${BOLD}Configuration${RESET}\n"
if [[ -d "$AIMUX_HOME" ]]; then
  check "~/.aimux directory" pass
else
  check "~/.aimux directory" warn "not created (will be created on first use)"
fi
echo

# Summary
printf "${BOLD}Summary${RESET}: %d checks, %d warnings, %d failures\n" "$checks" "$warnings" "$failures"
[[ "$failures" -gt 0 ]] && exit 1
exit 0
```

**Step 4: Run tests to verify they pass**

```bash
bats tests/test_doctor.bats
```

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add aimux/lib/aimux/doctor.sh aimux/tests/test_doctor.bats
git commit -m "feat: add aimux doctor health check"
```

---

### Task 3: Implement aimux notify (notification system)

**Files:**
- Create: `aimux/lib/aimux/notify.sh`
- Create: `aimux/tests/test_notify.bats`

**Step 1: Write the failing test**

Create `aimux/tests/test_notify.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

@test "aimux notify requires message" {
  run aimux notify
  [ "$status" -ne 0 ]
}

@test "aimux notify --bell sends terminal bell" {
  run aimux notify --bell "test message"
  [ "$status" -eq 0 ]
}

@test "aimux notify --osc sends OSC 9 sequence" {
  # Capture the escape sequence output
  run aimux notify --osc "test message"
  [ "$status" -eq 0 ]
}
```

**Step 2: Run test to verify it fails**

```bash
bats tests/test_notify.bats
```

**Step 3: Write notify.sh**

Create `aimux/lib/aimux/notify.sh`:

```bash
#!/usr/bin/env bash
# aimux notify - multi-channel notification dispatch

msg=""
title="aimux"
channels=()

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title|-t)  title="$2"; shift 2 ;;
    --bell)      channels+=(bell); shift ;;
    --osc)       channels+=(osc); shift ;;
    --native)    channels+=(native); shift ;;
    --webhook)   channels+=(webhook); shift ;;
    --all)       channels=(bell osc native); shift ;;
    -h|--help)
      echo "Usage: aimux notify [--bell] [--osc] [--native] [--all] [--title TITLE] <message>"
      exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)  msg="$1"; shift ;;
  esac
done

[[ -z "$msg" ]] && die "Usage: aimux notify <message>"

# Default: all available channels
[[ ${#channels[@]} -eq 0 ]] && channels=(bell osc native)

for channel in "${channels[@]}"; do
  case "$channel" in
    bell)
      # Terminal bell
      printf '\a'
      ;;
    osc)
      # OSC 9 (iTerm2, WezTerm), OSC 99 (kitty), OSC 777 (rxvt-unicode)
      printf '\033]9;%s\007' "$msg"          # OSC 9
      printf '\033]99;i=aimux:d=0;%s\033\\' "$msg"  # OSC 99 (kitty)
      ;;
    native)
      if [[ "$(uname)" == "Darwin" ]]; then
        if has terminal-notifier; then
          terminal-notifier -title "$title" -message "$msg" -group aimux
        else
          osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
        fi
      elif [[ "$(uname)" == "Linux" ]]; then
        if has notify-send; then
          notify-send "$title" "$msg"
        fi
      fi
      ;;
    webhook)
      local url="${AIMUX_WEBHOOK_URL:-}"
      if [[ -n "$url" ]]; then
        curl -s -X POST "$url" \
          -H "Content-Type: application/json" \
          -d "{\"text\":\"[$title] $msg\"}" &>/dev/null &
      else
        warn "No webhook URL configured (set AIMUX_WEBHOOK_URL)"
      fi
      ;;
  esac
done

log "notify: [$title] $msg (channels: ${channels[*]})"
```

**Step 4: Run tests**

```bash
bats tests/test_notify.bats
```

**Step 5: Commit**

```bash
git add aimux/lib/aimux/notify.sh aimux/tests/test_notify.bats
git commit -m "feat: add aimux notify with multi-channel notifications"
```

---

### Task 4: Implement aimux status (workspace display)

**Files:**
- Create: `aimux/lib/aimux/status.sh`
- Create: `aimux/tests/test_status.bats`
- Reference: `.config/fish/functions/gwt-status.fish`

**Step 1: Write the failing test**

Create `aimux/tests/test_status.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

@test "aimux status runs in git repo" {
  cd /tmp && git init aimux-test-repo 2>/dev/null
  cd /tmp/aimux-test-repo
  run aimux status
  [ "$status" -eq 0 ]
  rm -rf /tmp/aimux-test-repo
}

@test "aimux status shows header" {
  cd /tmp && git init aimux-test-repo2 2>/dev/null
  cd /tmp/aimux-test-repo2
  run aimux status
  [[ "$output" == *"WORKTREE"* ]] || [[ "$output" == *"BRANCH"* ]]
  rm -rf /tmp/aimux-test-repo2
}
```

**Step 2: Run test to verify it fails**

```bash
bats tests/test_status.bats
```

**Step 3: Write status.sh**

Create `aimux/lib/aimux/status.sh` — port from `gwt-status.fish`:

```bash
#!/usr/bin/env bash
# aimux status - show all workspaces with agent state

show_all=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all|-a) show_all=true; shift ;;
    -h|--help) echo "Usage: aimux status [--all]"; exit 0 ;;
    *) shift ;;
  esac
done

root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"

common_dir="$(git_common_dir)"
current_wt="$root"

# Header
printf "${BOLD}%-40s %-25s %-12s %-10s${RESET}\n" "WORKTREE" "BRANCH" "CONTAINER" "AGENT"
printf "%-40s %-25s %-12s %-10s\n" \
  "$(printf '%0.s─' {1..40})" \
  "$(printf '%0.s─' {1..25})" \
  "$(printf '%0.s─' {1..12})" \
  "$(printf '%0.s─' {1..10})"

# Parse worktree list
while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      wt_path="${line#worktree }"
      branch=""
      ;;
    "branch "*)
      branch="${line#branch refs/heads/}"
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

      # Agent state (from watcher)
      agent_state="-"
      if in_tmux; then
        # Check tmux window @wname_style for this worktree
        wname_style=$(tmux show-window-option -v @wname_style 2>/dev/null || echo "")
        case "$wname_style" in
          *"$COLOR_WORKING"*) agent_state="${RED}working${RESET}" ;;
          *"$COLOR_WAITING"*) agent_state="${YELLOW}waiting${RESET}" ;;
          *"$COLOR_DONE"*)    agent_state="${GREEN}done${RESET}" ;;
          *"$COLOR_STUCK"*)   agent_state="${MAGENTA}stuck${RESET}" ;;
        esac
      fi

      printf "${marker}%-39s %-25s %-12b %-10b\n" \
        "$display_path" "${branch:-detached}" "$container_status" "$agent_state"

      wt_path=""
      branch=""
      ;;
  esac
done < <(git worktree list --porcelain 2>/dev/null)
```

**Step 4: Run tests**

```bash
bats tests/test_status.bats
```

**Step 5: Commit**

```bash
git add aimux/lib/aimux/status.sh aimux/tests/test_status.bats
git commit -m "feat: add aimux status with agent state display"
```

---

### Task 5: Implement aimux new (workspace creation)

**Files:**
- Create: `aimux/lib/aimux/new.sh`
- Create: `aimux/tests/test_new.bats`
- Reference: `.config/fish/functions/gwt-dev.fish`

**Step 1: Write the failing test**

Create `aimux/tests/test_new.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

@test "aimux new requires branch name" {
  run aimux new
  [ "$status" -ne 0 ]
  [[ "$output" == *"branch"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "aimux new --help shows usage" {
  run aimux new --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
```

**Step 2: Run test to verify it fails**

```bash
bats tests/test_new.bats
```

**Step 3: Write new.sh**

Create `aimux/lib/aimux/new.sh` — port core logic from `gwt-dev.fish`:

```bash
#!/usr/bin/env bash
# aimux new - create workspace (worktree + tmux window)

branch=""
create_new=false
no_devcon=false
no_cd=false
exec_shell=false
rebuild=false
fast=false
mounts=()
features=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --new|-n)      create_new=true; shift ;;
    --no-devcon)   no_devcon=true; shift ;;
    --no-cd)       no_cd=true; shift ;;
    --exec|-e)     exec_shell=true; shift ;;
    --rebuild|-r)  rebuild=true; shift ;;
    --fast|-f)     fast=true; shift ;;
    --mount|-m)    mounts+=("$2"); shift 2 ;;
    --features|-F) features="$2"; shift 2 ;;
    -h|--help)
      cat <<'HELP'
Usage: aimux new [options] <branch>

Create a workspace: git worktree + tmux window + optional devcontainer

Options:
  -n, --new           Create new branch
  -e, --exec          Enter container shell after start
  -m, --mount DIR     Additional mount (repeatable)
  -F, --features LIST Comma-separated features
  --no-devcon         Skip devcontainer
  --rebuild           Remove + rebuild devcontainer
  --fast              Skip devcontainer lifecycle hooks
  -h, --help          Show this help
HELP
      exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)  branch="$1"; shift ;;
  esac
done

[[ -z "$branch" ]] && die "Usage: aimux new <branch>"
require git
require tmux

# Resolve repo root
root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"

repo_name="$(basename "$root")"
common_dir="$(cd "$root" && git rev-parse --git-common-dir)"
[[ "$common_dir" == ".git" ]] && common_dir="$root/.git"

# Worktree path: ../repo-branch
wt_dir="$(dirname "$root")/${repo_name}-${branch}"
instance_name="${repo_name}-${branch//\//-}"

# Check if worktree already exists
if [[ -d "$wt_dir" ]]; then
  info "Worktree already exists: $wt_dir"
else
  # Create worktree
  if $create_new; then
    info "Creating new branch: $branch"
    git worktree add -b "$branch" "$wt_dir" || die "Failed to create worktree"
  else
    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || \
       git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
      info "Checking out existing branch: $branch"
      git worktree add "$wt_dir" "$branch" || die "Failed to create worktree"
    else
      info "Creating new branch: $branch"
      git worktree add -b "$branch" "$wt_dir" || die "Failed to create worktree"
    fi
  fi
fi

# Trust mise if present
if has mise && [[ -f "$wt_dir/.mise.toml" || -f "$wt_dir/.tool-versions" ]]; then
  (cd "$wt_dir" && mise trust 2>/dev/null || true)
fi

# Create tmux window if in tmux
if in_tmux; then
  session="$(tmux_session)"
  # Check if window already exists for this worktree
  existing=$(tmux list-windows -t "$session" -F '#{window_name} #{pane_current_path}' 2>/dev/null | grep "$wt_dir" | head -1 || true)

  if [[ -z "$existing" ]]; then
    tmux new-window -t "$session" -n "$branch" -c "$wt_dir"
    info "Created tmux window: $branch"
  else
    info "tmux window already exists for $branch"
  fi
fi

# Devcontainer (if available and not skipped)
if ! $no_devcon && has devcon; then
  devcon_args=("--name" "$instance_name")

  if $rebuild; then
    devcon_args+=("--rebuild")
  fi
  if $fast; then
    devcon_args+=("--skip-hooks")
  fi
  if [[ -n "$features" ]]; then
    devcon_args+=("--features" "$features")
  fi
  for mount in "${mounts[@]}"; do
    rp="$(realpath "$mount" 2>/dev/null || echo "$mount")"
    [[ -d "$rp" ]] && devcon_args+=("--mount" "$rp")
  done

  info "Starting devcontainer: $instance_name"
  (cd "$wt_dir" && devcon up "${devcon_args[@]}" 2>&1) || warn "devcontainer failed (continuing without)"
elif ! $no_devcon && ! has devcon; then
  info "devcon not found, skipping devcontainer"
fi

# Print summary
printf "\n${BOLD}Workspace created${RESET}\n"
printf "  Branch:    %s\n" "$branch"
printf "  Worktree:  %s\n" "$wt_dir"
printf "  Instance:  %s\n" "$instance_name"
[[ -n "${session:-}" ]] && printf "  tmux:      %s:%s\n" "$session" "$branch"

log "new: created workspace $branch at $wt_dir"
```

**Step 4: Run tests**

```bash
bats tests/test_new.bats
```

**Step 5: Commit**

```bash
git add aimux/lib/aimux/new.sh aimux/tests/test_new.bats
git commit -m "feat: add aimux new for workspace creation"
```

---

### Task 6: Implement aimux kill (workspace cleanup)

**Files:**
- Create: `aimux/lib/aimux/kill.sh`
- Create: `aimux/tests/test_kill.bats`
- Reference: `scripts/tmux/tmux-worktree-cleanup.sh`

**Step 1: Write the failing test**

Create `aimux/tests/test_kill.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

@test "aimux kill requires workspace name" {
  run aimux kill
  [ "$status" -ne 0 ]
}

@test "aimux kill --help shows usage" {
  run aimux kill --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "aimux kill rejects protected branches" {
  run aimux kill main
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}
```

**Step 2: Run test to verify it fails**

```bash
bats tests/test_kill.bats
```

**Step 3: Write kill.sh**

Create `aimux/lib/aimux/kill.sh`:

```bash
#!/usr/bin/env bash
# aimux kill - kill workspace + cleanup worktree

target=""
force=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f) force=true; shift ;;
    -h|--help)
      echo "Usage: aimux kill [--force] <branch-or-path>"
      exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)  target="$1"; shift ;;
  esac
done

[[ -z "$target" ]] && die "Usage: aimux kill <branch-or-path>"
require git

# Protected branches
case "$target" in
  main|master|develop|staging|production)
    die "Cannot kill protected branch: $target" ;;
esac

root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"
repo_name="$(basename "$root")"

# Resolve worktree path
if [[ -d "$target" ]]; then
  wt_path="$target"
  branch="$(cd "$wt_path" && git_branch)"
else
  wt_path="$(dirname "$root")/${repo_name}-${target}"
  branch="$target"
fi

instance_name="${repo_name}-${branch//\//-}"

# Check for uncommitted changes
if [[ -d "$wt_path" ]]; then
  uncommitted=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$uncommitted" -gt 0 ]] && ! $force; then
    die "Worktree has uncommitted changes ($uncommitted files). Use --force to override."
  fi
fi

# Stop devcontainer
if has docker; then
  container=$(docker ps -q --filter "name=$instance_name" 2>/dev/null || true)
  if [[ -n "$container" ]]; then
    info "Stopping container: $instance_name"
    docker stop "$container" &>/dev/null || true
  fi
fi

# Remove devcontainer instance/workspace dirs
for dir in "$HOME/.devcontainer/instances/$instance_name" \
           "$HOME/.devcontainer/workspaces/$instance_name"; do
  if [[ -d "$dir" ]]; then
    info "Removing: $dir"
    rm -rf "$dir"
  fi
done

# Kill tmux window
if in_tmux; then
  session="$(tmux_session)"
  tmux_target=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null \
    | grep ":${branch}$" | head -1 | cut -d: -f1 || true)
  if [[ -n "$tmux_target" ]]; then
    info "Killing tmux window: $session:$tmux_target"
    tmux kill-window -t "$session:$tmux_target" 2>/dev/null || true
  fi
fi

# Remove worktree
if [[ -d "$wt_path" ]]; then
  info "Removing worktree: $wt_path"
  git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
fi

# Delete branch
if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
  info "Deleting branch: $branch"
  git branch -D "$branch" 2>/dev/null || true
fi

# Prune
git worktree prune 2>/dev/null || true

printf "${GREEN}Workspace killed${RESET}: %s\n" "$target"
log "kill: removed workspace $target"
```

**Step 4: Run tests**

```bash
bats tests/test_kill.bats
```

**Step 5: Commit**

```bash
git add aimux/lib/aimux/kill.sh aimux/tests/test_kill.bats
git commit -m "feat: add aimux kill with worktree cleanup"
```

---

### Task 7: Implement aimux attach (session attachment)

**Files:**
- Create: `aimux/lib/aimux/attach.sh`

**Step 1: Write attach.sh**

Create `aimux/lib/aimux/attach.sh`:

```bash
#!/usr/bin/env bash
# aimux attach - attach to workspace

target="${1:-}"

if [[ -z "$target" ]]; then
  # FZF picker if no target specified
  if has fzf; then
    target=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null \
      | fzf --prompt="Attach to: " --height=40% --reverse \
      | cut -d' ' -f1 || true)
    [[ -z "$target" ]] && exit 0
    tmux switch-client -t "$target" 2>/dev/null || tmux attach-session -t "$target"
  else
    die "Usage: aimux attach <name>"
  fi
else
  # Find window by name
  session="$(tmux_session 2>/dev/null || echo "")"
  if [[ -n "$session" ]]; then
    window=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null \
      | grep ":${target}" | head -1 | cut -d: -f1 || true)
    if [[ -n "$window" ]]; then
      tmux select-window -t "$session:$window"
    else
      # Search all sessions
      match=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null \
        | grep "$target" | head -1 | cut -d' ' -f1 || true)
      if [[ -n "$match" ]]; then
        tmux switch-client -t "$match"
      else
        die "No workspace found matching: $target"
      fi
    fi
  else
    # Not in tmux, attach to session
    tmux attach-session -t "$target" 2>/dev/null || die "No session found: $target"
  fi
fi
```

**Step 2: Commit**

```bash
git add aimux/lib/aimux/attach.sh
git commit -m "feat: add aimux attach with fzf picker"
```

---

### Task 8: Implement aimux daemon (agent watcher)

**Files:**
- Create: `aimux/lib/aimux/daemon.sh`
- Reference: `scripts/tmux/tmux-claude-watcher.sh`

**Step 1: Write daemon.sh**

Create `aimux/lib/aimux/daemon.sh` — adapt from existing watcher:

```bash
#!/usr/bin/env bash
# aimux daemon - agent state monitoring daemon

DAEMON_PID_FILE="/tmp/aimux-daemon.pid"
POLL_INTERVAL="${AIMUX_POLL_INTERVAL:-10}"

daemon_start() {
  if [[ -f "$DAEMON_PID_FILE" ]] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
    info "Daemon already running (PID: $(cat "$DAEMON_PID_FILE"))"
    return 0
  fi

  info "Starting aimux daemon (poll every ${POLL_INTERVAL}s)"

  # Fork to background
  (
    echo $$ > "$DAEMON_PID_FILE"
    trap 'rm -f "$DAEMON_PID_FILE"; exit 0' EXIT INT TERM

    while true; do
      daemon_poll
      sleep "$POLL_INTERVAL"
    done
  ) &

  disown
  info "Daemon started (PID: $!)"
  echo "$!" > "$DAEMON_PID_FILE"
  log "daemon: started PID $!"
}

daemon_stop() {
  if [[ -f "$DAEMON_PID_FILE" ]]; then
    local pid
    pid=$(cat "$DAEMON_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      rm -f "$DAEMON_PID_FILE"
      info "Daemon stopped (PID: $pid)"
      log "daemon: stopped PID $pid"
    else
      rm -f "$DAEMON_PID_FILE"
      info "Stale PID file removed"
    fi
  else
    info "Daemon not running"
  fi
}

daemon_status() {
  if [[ -f "$DAEMON_PID_FILE" ]] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
    printf "${GREEN}running${RESET} (PID: %s)\n" "$(cat "$DAEMON_PID_FILE")"
  else
    printf "${DIM}stopped${RESET}\n"
    [[ -f "$DAEMON_PID_FILE" ]] && rm -f "$DAEMON_PID_FILE"
  fi
}

daemon_poll() {
  # Poll each tmux pane for agent state
  tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_tty} #{window_name}' 2>/dev/null | \
  while IFS=' ' read -r target tty wname; do
    # Check for agent process on this TTY
    local has_agent=false
    local agent_type=""
    if ps -t "$tty" -o comm= 2>/dev/null | grep -qE '(claude|codex|opencode)'; then
      has_agent=true
      agent_type=$(ps -t "$tty" -o comm= 2>/dev/null | grep -oE '(claude|codex|opencode)' | head -1)
    fi

    if $has_agent; then
      # Capture last 20 lines of pane
      local content
      content=$(tmux capture-pane -t "$target" -p -S -20 2>/dev/null || echo "")

      local state="idle"
      if echo "$content" | grep -qE '… \(|⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏'; then
        state="working"
      elif echo "$content" | grep -qE 'COMPLETE|_DONE|TICKET_TASK_COMPLETE'; then
        state="done"
      fi

      # Set tmux window option for status bar coloring
      local color=""
      case "$state" in
        working) color="$COLOR_WORKING" ;;
        idle)    color="$COLOR_WAITING" ;;
        done)    color="$COLOR_DONE" ;;
      esac

      if [[ -n "$color" ]]; then
        local win="${target%.*}"
        tmux set-window-option -t "$win" @wname_style "fg=$color" 2>/dev/null || true
      fi

      # Notify on state change to "done"
      if [[ "$state" == "done" ]]; then
        # Check if we already notified (prevent spam)
        local notify_file="/tmp/aimux-notified-${target//[:.\/]/-}"
        if [[ ! -f "$notify_file" ]]; then
          touch "$notify_file"
          source "$AIMUX_LIB/notify.sh" <<< "Agent complete: $wname ($agent_type)"
        fi
      fi
    else
      # No agent — clear any color
      local win="${target%.*}"
      tmux set-window-option -t "$win" -u @wname_style 2>/dev/null || true
      # Clean up notify file
      rm -f "/tmp/aimux-notified-${target//[:.\/]/-}" 2>/dev/null || true
    fi
  done
}

# Dispatch subcommand
case "${1:-status}" in
  start)  daemon_start ;;
  stop)   daemon_stop ;;
  status) daemon_status ;;
  poll)   daemon_poll ;;  # Single poll (for testing)
  -h|--help)
    echo "Usage: aimux daemon [start|stop|status|poll]"
    exit 0 ;;
  *) die "Unknown daemon command: $1" ;;
esac
```

**Step 2: Commit**

```bash
git add aimux/lib/aimux/daemon.sh
git commit -m "feat: add aimux daemon for agent state monitoring"
```

---

### Task 9: Implement aimux run (autonomous ticket execution)

**Files:**
- Create: `aimux/lib/aimux/run.sh`
- Reference: `.config/fish/functions/gwt-ticket.fish`

This is the most complex subcommand. We'll implement a focused subset: create workspace + launch agent with basic retry.

**Step 1: Write run.sh**

Create `aimux/lib/aimux/run.sh`:

```bash
#!/usr/bin/env bash
# aimux run - autonomous ticket execution

ticket=""
prompt=""
max_iterations=20
provider="claude"
command="/ralph-wiggum:ralph-loop"
no_devcon=false
mounts=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max)        max_iterations="$2"; shift 2 ;;
    --provider)   provider="$2"; shift 2 ;;
    --command)    command="$2"; shift 2 ;;
    --no-devcon)  no_devcon=true; shift ;;
    --mount|-m)   mounts+=("$2"); shift 2 ;;
    -h|--help)
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
  aimux run TASK-456 --max 10 --provider codex "Refactor utils"
HELP
      exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)
      if [[ -z "$ticket" ]]; then
        ticket="$1"
      else
        prompt="${prompt:+$prompt }$1"
      fi
      shift ;;
  esac
done

[[ -z "$ticket" ]] && die "Usage: aimux run <ticket-key> [prompt]"
require git
require tmux

# Generate branch name from ticket
branch_name="$(echo "$ticket" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"

# Create workspace via aimux new
info "Creating workspace for $ticket"
new_args=("$branch_name")
$no_devcon && new_args+=("--no-devcon")
for mount in "${mounts[@]}"; do
  new_args+=("--mount" "$mount")
done
source "$AIMUX_LIB/new.sh" "${new_args[@]}" 2>&1 || true

root="$(git_root)"
repo_name="$(basename "$root")"
wt_path="$(dirname "$root")/${repo_name}-${branch_name}"

# Build agent launch command
case "$provider" in
  claude)
    agent_cmd="claude --effort max"
    if [[ -n "$prompt" ]]; then
      agent_cmd="$agent_cmd -p \"$command \\\"$prompt\\\"\""
    fi
    ;;
  codex)
    agent_cmd="codex"
    if [[ -n "$prompt" ]]; then
      agent_cmd="$agent_cmd --full-auto \"$prompt\""
    fi
    ;;
  *) die "Unknown provider: $provider" ;;
esac

# Launch agent in tmux pane
if in_tmux; then
  session="$(tmux_session)"
  # Find the window we just created
  window=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null \
    | grep ":${branch_name}" | head -1 | cut -d: -f1 || true)

  if [[ -n "$window" ]]; then
    # Send the agent command to the window
    tmux send-keys -t "$session:$window" "cd $wt_path && $agent_cmd" Enter
    info "Agent launched in $session:$window"
  else
    warn "Could not find tmux window for $branch_name"
  fi
fi

printf "\n${BOLD}Ticket execution started${RESET}\n"
printf "  Ticket:     %s\n" "$ticket"
printf "  Branch:     %s\n" "$branch_name"
printf "  Provider:   %s\n" "$provider"
printf "  Max iters:  %d\n" "$max_iterations"
[[ -n "$prompt" ]] && printf "  Prompt:     %s\n" "$prompt"

log "run: started $ticket via $provider (max: $max_iterations)"
```

**Step 2: Commit**

```bash
git add aimux/lib/aimux/run.sh
git commit -m "feat: add aimux run for autonomous ticket execution"
```

---

### Task 10: Add shell completions

**Files:**
- Create: `aimux/completions/aimux.fish`
- Create: `aimux/completions/aimux.bash`
- Create: `aimux/completions/_aimux`

**Step 1: Write Fish completion**

Create `aimux/completions/aimux.fish`:

```fish
# Fish completions for aimux
complete -c aimux -f

# Subcommands
complete -c aimux -n "__fish_use_subcommand" -a "new" -d "Create workspace"
complete -c aimux -n "__fish_use_subcommand" -a "status" -d "Show workspaces"
complete -c aimux -n "__fish_use_subcommand" -a "run" -d "Execute ticket"
complete -c aimux -n "__fish_use_subcommand" -a "attach" -d "Attach to workspace"
complete -c aimux -n "__fish_use_subcommand" -a "kill" -d "Kill workspace"
complete -c aimux -n "__fish_use_subcommand" -a "doctor" -d "Health check"
complete -c aimux -n "__fish_use_subcommand" -a "queue" -d "Queue management"
complete -c aimux -n "__fish_use_subcommand" -a "notify" -d "Send notification"
complete -c aimux -n "__fish_use_subcommand" -a "daemon" -d "Agent daemon"
complete -c aimux -n "__fish_use_subcommand" -a "version" -d "Show version"
complete -c aimux -n "__fish_use_subcommand" -a "help" -d "Show help"

# new subcommand
complete -c aimux -n "__fish_seen_subcommand_from new" -s n -l new -d "Create new branch"
complete -c aimux -n "__fish_seen_subcommand_from new" -s e -l exec -d "Enter container shell"
complete -c aimux -n "__fish_seen_subcommand_from new" -l no-devcon -d "Skip devcontainer"
complete -c aimux -n "__fish_seen_subcommand_from new" -s m -l mount -d "Additional mount" -r
complete -c aimux -n "__fish_seen_subcommand_from new" -s r -l rebuild -d "Rebuild devcontainer"

# kill subcommand
complete -c aimux -n "__fish_seen_subcommand_from kill" -s f -l force -d "Force kill"

# daemon subcommand
complete -c aimux -n "__fish_seen_subcommand_from daemon" -a "start stop status poll"
```

**Step 2: Write Bash completion**

Create `aimux/completions/aimux.bash`:

```bash
# Bash completions for aimux
_aimux() {
  local cur prev commands
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  commands="new status run attach kill doctor queue notify daemon version help"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return 0
  fi

  case "${COMP_WORDS[1]}" in
    daemon) COMPREPLY=($(compgen -W "start stop status poll" -- "$cur")) ;;
    new)    COMPREPLY=($(compgen -W "--new --exec --no-devcon --mount --rebuild --fast --help" -- "$cur")) ;;
    kill)   COMPREPLY=($(compgen -W "--force --help" -- "$cur")) ;;
    run)    COMPREPLY=($(compgen -W "--max --provider --command --no-devcon --mount --help" -- "$cur")) ;;
  esac
}
complete -F _aimux aimux
```

**Step 3: Write Zsh completion**

Create `aimux/completions/_aimux`:

```zsh
#compdef aimux

_aimux() {
  local -a commands
  commands=(
    'new:Create workspace'
    'status:Show workspaces'
    'run:Execute ticket'
    'attach:Attach to workspace'
    'kill:Kill workspace'
    'doctor:Health check'
    'queue:Queue management'
    'notify:Send notification'
    'daemon:Agent daemon'
    'version:Show version'
    'help:Show help'
  )

  _arguments -C \
    '1:command:->cmd' \
    '*::arg:->args'

  case "$state" in
    cmd) _describe 'command' commands ;;
    args)
      case "$words[1]" in
        daemon) _values 'subcommand' start stop status poll ;;
        new)    _arguments '--new' '--exec' '--no-devcon' '--mount:dir:_dirs' '--rebuild' '--fast' ;;
        kill)   _arguments '--force' ;;
        run)    _arguments '--max:iterations' '--provider:provider:(claude codex)' '--command:cmd' '--no-devcon' '--mount:dir:_dirs' ;;
      esac ;;
  esac
}

_aimux "$@"
```

**Step 4: Commit**

```bash
git add aimux/completions/
git commit -m "feat: add shell completions for Fish, Bash, and Zsh"
```

---

### Task 11: Create tmux config snippet

**Files:**
- Create: `aimux/config/aimux.tmux.conf`

**Step 1: Write aimux-specific tmux config**

Create `aimux/config/aimux.tmux.conf` — extracted agent-relevant parts of `.tmux.conf`:

```tmux
# aimux tmux configuration snippet
# Source this from your .tmux.conf: source-file ~/.aimux/aimux.tmux.conf

# Agent state colors in window names (set by aimux daemon)
# Uses @wname_style window option
set-window-option -g window-status-format "#[#{@wname_style}]#I:#W#F"
set-window-option -g window-status-current-format "#[#{@wname_style},bold]#I:#W#F"

# Smart split (adaptive: horizontal or vertical based on dimensions)
bind Space if-shell '[ $(($(tmux display -p "#{pane_width}") * 10 / $(tmux display -p "#{pane_height}"))) -gt 25 ]' \
  'split-window -h -c "#{pane_current_path}"' \
  'split-window -v -c "#{pane_current_path}"'

# Quick workspace kill with cleanup
bind X confirm-before -p "kill workspace #W? (y/n)" \
  "run-shell 'aimux kill #{window_name}'"

# Session manager (if aimux session-manager available)
bind S display-popup -E -w 80% -h 80% "aimux attach"
```

**Step 2: Commit**

```bash
git add aimux/config/aimux.tmux.conf
git commit -m "feat: add aimux tmux config snippet"
```

---

### Task 12: Create Homebrew formula

**Files:**
- Create: `aimux/Formula/aimux.rb`

**Step 1: Write the formula**

Create `aimux/Formula/aimux.rb`:

```ruby
class Aimux < Formula
  desc "AI Agent Multiplexer - terminal-agnostic agent orchestration for tmux"
  homepage "https://github.com/shaheislam/aimux"
  url "https://github.com/shaheislam/aimux/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"
  head "https://github.com/shaheislam/aimux.git", branch: "main"

  depends_on "tmux"
  depends_on "fzf" => :recommended
  depends_on "jq" => :recommended

  def install
    bin.install "bin/aimux"
    lib.install Dir["lib/aimux"]
    (share/"aimux").install "config/aimux.tmux.conf"
    fish_completion.install "completions/aimux.fish"
    bash_completion.install "completions/aimux.bash"
    zsh_completion.install "completions/_aimux"
  end

  def post_install
    ohai "Run 'aimux doctor' to verify your setup"
    ohai "Add to .tmux.conf: source-file #{share}/aimux/aimux.tmux.conf"
  end

  test do
    assert_match "aimux", shell_output("#{bin}/aimux version")
  end
end
```

**Step 2: Commit**

```bash
git add aimux/Formula/aimux.rb
git commit -m "feat: add Homebrew formula for aimux"
```

---

### Task 13: Write README and documentation

**Files:**
- Create: `aimux/README.md`

**Step 1: Write README**

Create `aimux/README.md`:

```markdown
# aimux

**The AI Agent Multiplexer** — terminal-agnostic agent orchestration for tmux.

Manage multiple AI coding agents (Claude Code, Codex, etc.) across isolated workspaces with real-time state monitoring, notifications, and autonomous ticket execution.

## Why aimux?

| Feature | cmux | aimux |
|---------|------|-------|
| Terminal support | Ghostty only | Any terminal |
| Platform | macOS only | macOS + Linux |
| Agent monitoring | Notification rings | 4-state lifecycle |
| Orchestration | None | Worktree + container |
| Session persistence | None | tmux detach/attach |
| Autonomous execution | None | Retry loops + checkpoints |

## Quick Start

### Install

```bash
brew tap shaheislam/aimux
brew install aimux
aimux doctor  # verify setup
```

### Create a workspace

```bash
aimux new feature-auth   # creates worktree + tmux window
```

### Monitor agents

```bash
aimux status             # table of all workspaces with agent state
aimux daemon start       # background monitoring + notifications
```

### Execute a ticket

```bash
aimux run PROJ-123 "Fix the authentication bug in login flow"
```

### Cleanup

```bash
aimux kill feature-auth  # removes worktree, container, branch
```

## Commands

| Command | Description |
|---------|-------------|
| `aimux new <branch>` | Create workspace (worktree + tmux window) |
| `aimux status` | Show all workspaces with agent state |
| `aimux run <ticket> [msg]` | Execute ticket autonomously |
| `aimux attach [name]` | Attach to workspace (fzf picker if no name) |
| `aimux kill <name>` | Kill workspace + cleanup |
| `aimux doctor` | Health check |
| `aimux daemon start` | Start agent state monitoring |
| `aimux notify <msg>` | Send multi-channel notification |

## Agent States

aimux tracks four agent states, color-coded in your tmux status bar:

- **Working** (red) — agent is actively generating
- **Waiting** (yellow) — agent is idle, awaiting input
- **Done** (green) — agent completed its task
- **Stuck** (magenta) — no output for >5 minutes

## Configuration

```bash
mkdir -p ~/.aimux
```

Settings in `~/.aimux/config.yaml`:

```yaml
notifications:
  native: true    # OS notifications on agent completion
  sound: true     # terminal bell
  webhook: ""     # Slack/Discord webhook URL

agent:
  poll_interval: 10    # seconds between state checks
  stuck_timeout: 300   # seconds before marking stuck
```

## Requirements

- **tmux** (required)
- **git** (required)
- **fzf** (recommended — interactive selection)
- **jq** (recommended — JSON parsing)
- **docker** (optional — devcontainer support)

## License

MIT
```

**Step 2: Commit**

```bash
git add aimux/README.md
git commit -m "docs: add aimux README with quickstart and reference"
```

---

### Task 14: Integration test — full workflow

**Step 1: Run all tests**

```bash
cd aimux && bats tests/
```

**Step 2: Verify CLI end-to-end**

```bash
aimux/bin/aimux version
aimux/bin/aimux help
aimux/bin/aimux doctor
```

**Step 3: Final commit with any fixes**

```bash
git add -A
git status
git commit -m "test: verify aimux CLI integration"
```
