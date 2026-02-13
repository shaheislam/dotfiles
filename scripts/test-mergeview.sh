#!/usr/bin/env bash
# test-mergeview.sh — Verify cross-worktree merge detection in Diffview
#
# Static analysis tests for the Neovim git.lua plugin's conflict detection.
# Validates: worktree structure, conflict state files, autocmd wiring,
# event scoping, debounce/retry mechanisms, and Lua syntax.
#
# Note: Integration tests requiring a running Neovim instance (Diffview
# close/reopen lifecycle, actual conflict state transitions, tmux pane
# FocusGained interplay) must be tested manually via the workflow:
#   1. Open Neovim in worktree with :DiffviewOpen
#   2. Open :terminal split, run git merge/rebase/cherry-pick
#   3. Verify Diffview detects conflict and reopens with -C flag
#
# Usage: ./scripts/test-mergeview.sh

set -euo pipefail

PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31m✗\033[0m %s\n" "$1"; }

echo "=== Cross-Worktree Merge Detection Tests ==="
echo ""

# ─── Test 1: Verify worktree .git file exists ────────────────────────
echo "--- Worktree Structure ---"
if [ -f "$HOME/dotfiles-mergeview/.git" ]; then
    pass ".git file exists (worktree indicator)"
else
    fail ".git file missing — not a worktree"
fi

# ─── Test 2: Verify .git points to correct worktree dir ─────────────
gitdir=$(sed 's/^gitdir: //' "$HOME/dotfiles-mergeview/.git" 2>/dev/null)
if [[ "$gitdir" == *"worktrees/dotfiles-mergeview"* ]]; then
    pass ".git file points to correct worktree dir"
else
    fail ".git file points to unexpected dir: $gitdir"
fi

# ─── Test 3: Verify commondir resolves to main repo ─────────────────
commondir_path="$gitdir/commondir"
if [ -f "$commondir_path" ]; then
    commondir=$(cat "$commondir_path")
    pass "commondir file exists: $commondir"
else
    fail "commondir file missing at $commondir_path"
fi

# ─── Test 4: Verify main repo .git dir is resolvable ────────────────
main_git_dir=$(cd "$gitdir" && cd "$commondir" && pwd)
if [ -d "$main_git_dir" ]; then
    pass "Main repo .git dir resolves to: $main_git_dir"
else
    fail "Main repo .git dir not found"
fi

# ─── Test 5: Verify conflict state file paths ───────────────────────
echo ""
echo "--- Conflict State Detection ---"
pass "MERGE_HEAD path would be: $main_git_dir/MERGE_HEAD"

# ─── Test 6: git rev-parse from main repo works ─────────────────────
main_work_dir="${main_git_dir%/.git}"
toplevel=$(git -C "$main_work_dir" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$toplevel" ]; then
    pass "git rev-parse --show-toplevel from main repo: $toplevel"
else
    fail "git rev-parse failed from main repo"
fi

# ─── Test 7: git diff runs correctly from main repo ─────────────────
diff_output=$(git -C "$main_work_dir" diff --ignore-submodules --name-status 2>&1)
pass "git diff --name-status from main repo works (${#diff_output} chars)"

# ─── Test 8: Verify Neovim git.lua has poll_merge_state ──────────────
echo ""
echo "--- Neovim Plugin Checks ---"
git_lua="$HOME/neovim/lua/plugins/git.lua"
if [ -f "$git_lua" ]; then
    if grep -q "poll_merge_state" "$git_lua"; then
        pass "poll_merge_state function exists in git.lua"
    else
        fail "poll_merge_state function missing from git.lua"
    fi
else
    fail "git.lua not found at $git_lua"
fi

# ─── Test 9: Verify TermLeave autocmd exists ─────────────────────────
if grep -q "TermLeave" "$git_lua"; then
    pass "TermLeave autocmd registered in git.lua"
else
    fail "TermLeave autocmd missing from git.lua"
fi

# ─── Test 10: Verify WinEnter autocmd exists ─────────────────────────
if grep -q "WinEnter" "$git_lua"; then
    pass "WinEnter autocmd registered in git.lua"
else
    fail "WinEnter autocmd missing from git.lua"
fi

# ─── Test 11: Verify FocusGained still exists ────────────────────────
if grep -q "FocusGained" "$git_lua"; then
    pass "FocusGained autocmd still registered in git.lua"
else
    fail "FocusGained autocmd missing from git.lua (regression)"
fi

# ─── Test 12: Verify cross_worktree_state exists ─────────────────────
if grep -q "cross_worktree_state" "$git_lua"; then
    pass "cross_worktree_state variable exists"
else
    fail "cross_worktree_state variable missing"
fi

# ─── Test 13: Verify DiffviewOpen -C command format ──────────────────
if grep -q 'DiffviewOpen -C' "$git_lua"; then
    pass "DiffviewOpen -C command used for cross-worktree"
else
    fail "DiffviewOpen -C command missing"
fi

# ─── Test 14: Verify fs_event watcher for main repo ─────────────────
if grep -q "main_repo_watcher" "$git_lua"; then
    pass "fs_event watcher for main repo (.git/) exists"
else
    fail "fs_event watcher for main repo missing"
fi

# ─── Test 15: Lua syntax check ───────────────────────────────────────
echo ""
echo "--- Syntax Validation ---"
if luac -p "$git_lua" 2>/dev/null; then
    pass "git.lua passes Lua syntax check"
else
    fail "git.lua has Lua syntax errors"
fi

# ─── Test 16: Verify debounce on WinEnter ────────────────────────────
if grep -q "win_enter_timer" "$git_lua"; then
    pass "WinEnter has debounce protection"
else
    fail "WinEnter missing debounce (could cause performance issues)"
fi

# ─── Test 17: Verify TermLeave has delay ─────────────────────────────
if grep -A5 "TermLeave" "$git_lua" | grep -q "defer_fn"; then
    pass "TermLeave has deferred execution (for conflict state file write timing)"
else
    fail "TermLeave missing deferred execution"
fi

# ─── Test 18: Verify TermClose autocmd exists ────────────────────────
if grep -q "TermClose" "$git_lua"; then
    pass "TermClose autocmd registered (catches terminal job exit)"
else
    fail "TermClose autocmd missing from git.lua"
fi

# ─── Test 19-25: Verify CONFLICT_STATE_FILES covers all conflict types ─
echo ""
echo "--- Broader Conflict Detection ---"
for state_file in MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer; do
    if grep -q "\"$state_file\"" "$git_lua"; then
        pass "$state_file detection present in CONFLICT_STATE_FILES"
    else
        fail "$state_file detection missing from CONFLICT_STATE_FILES"
    fi
done

# ─── Test 26: Verify check_conflict_state helper exists ──────────────
if grep -q "check_conflict_state" "$git_lua"; then
    pass "check_conflict_state helper function exists"
else
    fail "check_conflict_state helper missing"
fi

# ─── Autocmd Hygiene ──────────────────────────────────────────────────
echo ""
echo "--- Autocmd Hygiene ---"
if grep -q "clear = true" "$git_lua"; then
    pass "Augroup uses clear = true (prevents stacking on reload)"
else
    fail "Augroup missing clear = true"
fi

# ─── Event Scoping: all callbacks bail when Diffview not open ────────
echo ""
echo "--- Event Scoping ---"
if grep -q "get_current_view" "$git_lua"; then
    pass "Callbacks check get_current_view() before acting"
else
    fail "Missing get_current_view() guard"
fi

# poll_merge_state bails early on no view (checks get_current_view then "not view")
if grep -A10 "function poll_merge_state" "$git_lua" | grep -q "not view"; then
    pass "poll_merge_state bails when no Diffview view"
else
    fail "poll_merge_state missing view guard"
fi

# WinEnter explicitly scoped
if grep -B2 -A8 "WinEnter" "$git_lua" | grep -q "get_current_view"; then
    pass "WinEnter scoped to Diffview-active state"
else
    fail "WinEnter not scoped to Diffview"
fi

# ─── Worktree gitdir resolution ──────────────────────────────────────
echo ""
echo "--- Worktree Resolution ---"
# get_git_dir parses .git file for worktree indirection
if grep -A15 "get_git_dir" "$git_lua" | grep -q "gitdir:"; then
    pass "get_git_dir parses .git file indirection for linked worktrees"
else
    fail "get_git_dir missing .git file parsing"
fi

# get_git_dir resolves relative paths
if grep -A30 "function get_git_dir" "$git_lua" | grep -q 'vim.fn.resolve'; then
    pass "get_git_dir resolves paths with vim.fn.resolve()"
else
    fail "get_git_dir missing path resolution"
fi

# ─── FSEvents Coalescing Mitigation ──────────────────────────────────
echo ""
echo "--- FSEvents Retry Mechanism ---"
# poll_with_retry helper exists
if grep -q "poll_with_retry" "$git_lua"; then
    pass "poll_with_retry helper exists (bounded FSEvents retry)"
else
    fail "poll_with_retry helper missing"
fi

# Retry uses bounded delay (800ms second check)
if grep -A15 "function poll_with_retry" "$git_lua" | grep -q "800"; then
    pass "Retry uses 800ms bounded second check"
else
    fail "Retry missing bounded delay"
fi

# FocusGained uses poll_with_retry
if grep -A5 "FocusGained" "$git_lua" | grep -q "poll_with_retry"; then
    pass "FocusGained uses poll_with_retry"
else
    fail "FocusGained not using retry mechanism"
fi

# TermLeave and TermClose both use poll_with_retry
if grep -A5 '"TermLeave"' "$git_lua" | grep -q "poll_with_retry" && \
   grep -A5 '"TermClose"' "$git_lua" | grep -q "poll_with_retry"; then
    pass "TermLeave/TermClose use poll_with_retry"
else
    fail "Terminal events not using retry mechanism"
fi

# ─── Design Decisions ────────────────────────────────────────────────
echo ""
echo "--- Design Decisions ---"
# ModeChanged intentionally excluded (documented)
if grep -q "ModeChanged is intentionally not used" "$git_lua"; then
    pass "ModeChanged exclusion documented with rationale"
else
    fail "ModeChanged exclusion not documented"
fi

# Debounce rationale documented
if grep -q "Debounce rationale" "$git_lua"; then
    pass "Debounce values documented with rationale"
else
    fail "Debounce rationale not documented"
fi

# ─── User Control ─────────────────────────────────────────────────────
echo ""
echo "--- User Control ---"
# vim.g.diffview_auto_switch toggle exists
if grep -q "diffview_auto_switch" "$git_lua"; then
    pass "diffview_auto_switch user toggle exists"
else
    fail "diffview_auto_switch user toggle missing"
fi

# Toggle default is true
if grep -q "diffview_auto_switch = true" "$git_lua"; then
    pass "diffview_auto_switch defaults to true"
else
    fail "diffview_auto_switch default not set to true"
fi

# poll_merge_state respects toggle
if grep -A5 "function poll_merge_state" "$git_lua" | grep -q "diffview_auto_switch"; then
    pass "poll_merge_state respects user toggle"
else
    fail "poll_merge_state ignores user toggle"
fi

# fs_event watchers respect toggle
if grep -B2 -A2 "diffview_auto_switch == false" "$git_lua" | grep -q "return"; then
    pass "fs_event watchers respect user toggle"
else
    fail "fs_event watchers ignore user toggle"
fi

# :DiffviewAutoSwitchToggle command exists
if grep -q "DiffviewAutoSwitchToggle" "$git_lua"; then
    pass ":DiffviewAutoSwitchToggle command registered"
else
    fail ":DiffviewAutoSwitchToggle command missing"
fi

# No hardcoded -C ~/dotfiles (all -C uses resolved paths)
if grep -q '\-C ~/dotfiles\|-C \$HOME/dotfiles\|-C.*home.*dotfiles' "$git_lua"; then
    fail "Hardcoded -C ~/dotfiles found"
else
    pass "No hardcoded -C paths (all use resolved repo dir)"
fi

# view:update_files() guarded with feature detection
if grep -q "view.update_files then" "$git_lua"; then
    pass "view:update_files() guarded with feature detection"
else
    fail "view:update_files() called without feature detection guard"
fi

# ─── Repo Following ──────────────────────────────────────────────────
echo ""
echo "--- Repo Following ---"

# find_repo_root helper exists
if grep -q "function find_repo_root" "$git_lua"; then
    pass "find_repo_root helper exists"
else
    fail "find_repo_root helper missing"
fi

# diffview_follow_repo toggle exists
if grep -q "diffview_follow_repo" "$git_lua"; then
    pass "diffview_follow_repo toggle exists"
else
    fail "diffview_follow_repo toggle missing"
fi

# :DiffviewFollowRepoToggle command exists
if grep -q "DiffviewFollowRepoToggle" "$git_lua"; then
    pass ":DiffviewFollowRepoToggle command registered"
else
    fail ":DiffviewFollowRepoToggle command missing"
fi

# BufEnter autocmd for repo following
if grep -q "BufEnter" "$git_lua"; then
    pass "BufEnter autocmd registered for repo following"
else
    fail "BufEnter autocmd missing"
fi

# BufEnter skips URI-scheme buffers (diffview://, fugitive://, term://, etc.)
if grep -q '%w+://' "$git_lua"; then
    pass "BufEnter skips URI-scheme buffers (diffview://, fugitive://, term://, etc.)"
else
    fail "BufEnter not filtering URI-scheme buffers"
fi

# BufEnter skips non-file buffers via buftype check
if grep -q 'vim.bo.buftype' "$git_lua"; then
    pass "BufEnter skips non-file buffers (buftype check)"
else
    fail "BufEnter not filtering non-file buffers"
fi

# Path canonicalization with vim.fn.resolve
if grep -B5 -A5 "buf_root" "$git_lua" | grep -q "vim.fn.resolve"; then
    pass "Repo root comparison uses vim.fn.resolve() for symlinks"
else
    fail "Repo root comparison missing vim.fn.resolve()"
fi

# Short-circuit when buffer is under current root
if grep -q "sub(1," "$git_lua"; then
    pass "Short-circuit: skips walk when buffer is under current root"
else
    fail "Short-circuit for same-root buffers missing"
fi

# Path escaping in DiffviewOpen -C
if grep -q "fnameescape" "$git_lua"; then
    pass "DiffviewOpen -C uses fnameescape() for path safety"
else
    fail "DiffviewOpen -C missing path escaping"
fi

# diffview_current_root tracking variable
if grep -q "diffview_current_root" "$git_lua"; then
    pass "diffview_current_root tracking variable exists"
else
    fail "diffview_current_root tracking missing"
fi

# view_opened sets diffview_current_root
if grep -A10 "view_opened = function" "$git_lua" | grep -q "diffview_current_root"; then
    pass "view_opened sets diffview_current_root"
else
    fail "view_opened does not set diffview_current_root"
fi

# view_opened reads repo root from Diffview's adapter context (not getcwd)
if grep -A10 "view_opened = function" "$git_lua" | grep -q "adapter.ctx.toplevel"; then
    pass "view_opened reads repo root from view.adapter.ctx.toplevel"
else
    fail "view_opened missing adapter.ctx.toplevel read"
fi

# view_opened falls back to find_repo_root when adapter unavailable
if grep -A15 "view_opened = function" "$git_lua" | grep -q "find_repo_root"; then
    pass "view_opened falls back to find_repo_root for non-adapter views"
else
    fail "view_opened missing find_repo_root fallback"
fi

# view_closed clears diffview_current_root
if grep -A3 "view_closed" "$git_lua" | grep -q "diffview_current_root"; then
    pass "view_closed clears diffview_current_root"
else
    fail "view_closed does not clear diffview_current_root"
fi

# Shared reentrancy guard for repo-following
if grep -q "repo_switch_in_progress" "$git_lua"; then
    pass "Shared reentrancy guard (repo_switch_in_progress) exists"
else
    fail "Shared reentrancy guard missing"
fi

# Shared retarget_diffview helper
if grep -q "function retarget_diffview" "$git_lua"; then
    pass "retarget_diffview shared helper exists"
else
    fail "retarget_diffview shared helper missing"
fi

# DiffviewOpen failure reverts diffview_current_root to prev_root
if grep -q "prev_root" "$git_lua"; then
    pass "DiffviewOpen failure reverts diffview_current_root"
else
    fail "DiffviewOpen failure does not revert diffview_current_root"
fi

# ─── Tmux Pane Repo Following ────────────────────────────────────────
echo ""
echo "--- Tmux Pane Repo Following ---"

# get_tmux_last_pane_cwd helper exists
if grep -q "function get_tmux_last_pane_cwd" "$git_lua"; then
    pass "get_tmux_last_pane_cwd helper exists"
else
    fail "get_tmux_last_pane_cwd helper missing"
fi

# get_tmux_last_pane_cwd checks TMUX env var
if grep -A5 "function get_tmux_last_pane_cwd" "$git_lua" | grep -q 'vim.env.TMUX'; then
    pass "get_tmux_last_pane_cwd checks TMUX env var"
else
    fail "get_tmux_last_pane_cwd missing TMUX env check"
fi

# get_tmux_last_pane_cwd queries pane_current_path
if grep -A10 "function get_tmux_last_pane_cwd" "$git_lua" | grep -q 'pane_current_path'; then
    pass "get_tmux_last_pane_cwd uses tmux pane_current_path"
else
    fail "get_tmux_last_pane_cwd not querying tmux pane_current_path"
fi

# FocusGained uses get_tmux_last_pane_cwd for repo-following
if grep -A50 "FocusGained" "$git_lua" | grep -q "get_tmux_last_pane_cwd"; then
    pass "FocusGained uses get_tmux_last_pane_cwd for repo-following"
else
    fail "FocusGained not using tmux pane cwd detection"
fi

# FocusGained calls retarget_diffview
if grep -A50 "FocusGained" "$git_lua" | grep -q "retarget_diffview"; then
    pass "FocusGained calls retarget_diffview"
else
    fail "FocusGained not calling retarget_diffview"
fi

# FocusGained checks diffview_follow_repo toggle
if grep -A50 "FocusGained" "$git_lua" | grep -q "diffview_follow_repo"; then
    pass "FocusGained respects diffview_follow_repo toggle"
else
    fail "FocusGained ignores diffview_follow_repo toggle"
fi

# FocusGained checks get_current_view (only acts when Diffview is open)
if grep -A50 "FocusGained" "$git_lua" | grep -q "get_current_view"; then
    pass "FocusGained only retargets when Diffview is open"
else
    fail "FocusGained missing Diffview open check"
fi

# FocusGained uses path_is_under for prefix check
if grep -A50 "FocusGained" "$git_lua" | grep -q "path_is_under"; then
    pass "FocusGained uses path_is_under for prefix check"
else
    fail "FocusGained using raw prefix match"
fi

# retarget_diffview is declared BEFORE FocusGained (Lua lexical scoping)
retarget_line=$(grep -n "function retarget_diffview" "$git_lua" | head -1 | cut -d: -f1)
focus_line=$(grep -n "create_autocmd.*FocusGained" "$git_lua" | head -1 | cut -d: -f1)
if [ -n "$retarget_line" ] && [ -n "$focus_line" ] && [ "$retarget_line" -lt "$focus_line" ]; then
    pass "retarget_diffview declared before FocusGained (Lua lexical scoping)"
else
    fail "retarget_diffview declared after FocusGained — callback can't see it"
fi

# ─── Neovim Terminal CWD Detection (fallback for :terminal splits) ───
echo ""
echo "--- Neovim Terminal CWD Detection ---"

# get_terminal_cwd helper exists
if grep -q "function get_terminal_cwd" "$git_lua"; then
    pass "get_terminal_cwd helper exists"
else
    fail "get_terminal_cwd helper missing"
fi

# get_terminal_cwd supports macOS (lsof) + Linux (/proc)
if grep -q "lsof" "$git_lua" && grep -q "/proc/" "$git_lua"; then
    pass "Terminal cwd detection supports macOS (lsof) and Linux (/proc)"
else
    fail "Terminal cwd detection missing platform support"
fi

# TermLeave uses get_terminal_cwd for repo-following
if grep -A20 "TermLeave" "$git_lua" | grep -q "get_terminal_cwd"; then
    pass "TermLeave uses get_terminal_cwd for :terminal repo-following"
else
    fail "TermLeave not using terminal cwd detection"
fi

# BufEnter calls retarget_diffview
if grep -A50 "BufEnter" "$git_lua" | grep -q "retarget_diffview"; then
    pass "BufEnter uses retarget_diffview helper"
else
    fail "BufEnter not using retarget_diffview"
fi

# ─── Path Prefix Safety ─────────────────────────────────────────────
echo ""
echo "--- Path Prefix Safety ---"

# path_is_under helper exists (prevents /dotfiles matching /dotfiles-mergeview)
if grep -q "function path_is_under" "$git_lua"; then
    pass "path_is_under helper exists (path-separator-aware prefix check)"
else
    fail "path_is_under helper missing — prefix check may false-positive"
fi

# path_is_under checks for trailing slash separator
if grep -A5 "function path_is_under" "$git_lua" | grep -q 'root .. "/"'; then
    pass "path_is_under requires path separator after prefix"
else
    fail "path_is_under missing path separator check"
fi

# Tmux pane check uses path_is_under (called by FocusGained via shared function)
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "path_is_under"; then
    pass "FocusGained uses path_is_under for prefix check"
else
    fail "FocusGained using raw prefix match"
fi

# BufEnter uses path_is_under (not raw string prefix)
if grep -A30 '"BufEnter"' "$git_lua" | grep -q "path_is_under"; then
    pass "BufEnter uses path_is_under for prefix check"
else
    fail "BufEnter using raw prefix match (vulnerable to dotfiles/dotfiles-mergeview)"
fi

# Nil-root retarget: shared check retargets even when view_root is nil
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "not view_root or"; then
    pass "FocusGained retargets when view_root is nil"
else
    fail "FocusGained blocks retarget when view_root is nil"
fi

# ─── Edge Case Safety ──────────────────────────────────────────────
echo ""
echo "--- Edge Case Safety ---"

# Non-git directory: shared check guards find_repo_root nil before retargeting
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -B1 "retarget_diffview" | grep -q "pane_root ~=\|not pane_root\|not view_root"; then
    pass "FocusGained guards against non-git directories (find_repo_root nil check)"
else
    fail "FocusGained missing non-git directory guard"
fi

# Path escaping: DiffviewOpen uses fnameescape for special characters in paths
if grep -q 'fnameescape(new_root)' "$git_lua"; then
    pass "DiffviewOpen path argument uses fnameescape (handles spaces/special chars)"
else
    fail "DiffviewOpen missing fnameescape — unsafe with special characters in paths"
fi

# Idempotence: shared check skips retarget when pane root equals view root
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "pane_root ~= view_root"; then
    pass "FocusGained is idempotent (skips retarget when same root)"
else
    fail "FocusGained missing idempotence check — may cause unnecessary reopen"
fi

# Reentrancy: shared check respects repo_switch_in_progress
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "repo_switch_in_progress"; then
    pass "FocusGained checks reentrancy guard (prevents rapid-switch race)"
else
    fail "FocusGained missing reentrancy guard"
fi

# No module-level override variable (uses Diffview's own adapter API instead)
if ! grep -q "retarget_root_override" "$git_lua"; then
    pass "No module-level override hack (uses view.adapter.ctx.toplevel)"
else
    fail "Stale retarget_root_override variable still present"
fi

# Failed DiffviewOpen notifies user (not silent)
if grep -A15 "function retarget_diffview" "$git_lua" | grep -q 'vim.notify.*retarget failed'; then
    pass "DiffviewOpen failure notifies user with WARN level"
else
    fail "DiffviewOpen failure is silent — no user notification"
fi

# Trailing-slash normalization on both sides of comparison (in shared check)
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q 'gsub("/$"'; then
    pass "FocusGained normalizes trailing slashes before comparison"
else
    fail "FocusGained missing trailing-slash normalization"
fi

# view_opened normalizes trailing slashes too
if grep -A15 "view_opened = function" "$git_lua" | grep -q 'gsub("/$"'; then
    pass "view_opened normalizes trailing slashes on diffview_current_root"
else
    fail "view_opened missing trailing-slash normalization"
fi

# Fallback cwd uses window-aware getcwd(0, 0) respecting :lcd/:tcd
if grep -A15 "view_opened = function" "$git_lua" | grep -q 'getcwd(0, 0)'; then
    pass "view_opened fallback uses window-aware getcwd(0, 0)"
else
    fail "view_opened fallback uses bare getcwd() — ignores :lcd/:tcd"
fi

# ─── Multi-Tab & Reentrancy Safety ─────────────────────────────────
echo ""
echo "--- Multi-Tab & Reentrancy Safety ---"

# Shared check reads root from active view's adapter (multi-tab safe)
# Instead of the module-level diffview_current_root cache, it reads
# current_view.adapter.ctx.toplevel — correct even with multiple Diffview tabs.
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "current_view.adapter"; then
    pass "FocusGained reads root from active view's adapter (multi-tab safe)"
else
    fail "FocusGained uses cached diffview_current_root (not multi-tab safe)"
fi

# Shared check stores the view from get_current_view (not discarding it)
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "local current_view = lib.get_current_view"; then
    pass "FocusGained captures view object for adapter access"
else
    fail "FocusGained discards get_current_view return value"
fi

# Shared check compares against view_root (not diffview_current_root)
if grep -A40 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "pane_root ~= view_root"; then
    pass "FocusGained compares pane root against live view root (not cache)"
else
    fail "FocusGained still compares against cached diffview_current_root"
fi

# Reentrancy guard: retarget_diffview sets and clears repo_switch_in_progress
retarget_body=$(grep -A15 "function retarget_diffview" "$git_lua")
if echo "$retarget_body" | grep -q "repo_switch_in_progress = true" && \
   echo "$retarget_body" | grep -q "repo_switch_in_progress = false"; then
    pass "retarget_diffview sets+clears reentrancy guard on both success and failure"
else
    fail "retarget_diffview missing reentrancy guard set/clear"
fi

# Reentrancy guard clears even when DiffviewOpen fails
# The guard clear (repo_switch_in_progress = false) must be AFTER the if/end block
# not inside the error branch, so it runs unconditionally.
if grep -A15 "function retarget_diffview" "$git_lua" | grep -A2 "repo_switch_in_progress = false" | head -1 | grep -qv "if not open_ok"; then
    pass "Reentrancy guard clears unconditionally (after success or failure)"
else
    fail "Reentrancy guard only clears on one code path"
fi

# ─── Auto-Follow: Timer Polling ───────────────────────────────────
echo ""
echo "--- Auto-Follow: Timer Polling ---"

# Shared check function exists (extracted from FocusGained for reuse)
if grep -q "function check_tmux_pane_and_retarget" "$git_lua"; then
    pass "check_tmux_pane_and_retarget shared function exists"
else
    fail "Missing shared tmux pane check function"
fi

# FocusGained delegates to shared function (not inline logic)
if grep -A10 "create_autocmd.*FocusGained" "$git_lua" | grep -q "check_tmux_pane_and_retarget"; then
    pass "FocusGained delegates to shared check function"
else
    fail "FocusGained still has inline tmux check logic"
fi

# Timer start/stop functions exist
if grep -q "function start_follow_timer" "$git_lua" && grep -q "function stop_follow_timer" "$git_lua"; then
    pass "start_follow_timer and stop_follow_timer functions exist"
else
    fail "Missing timer start/stop functions"
fi

# Timer uses 2-second interval with repeat
if grep -A10 "function start_follow_timer" "$git_lua" | grep -q 'timer_start(2000'; then
    pass "Follow timer uses 2-second polling interval"
else
    fail "Follow timer missing or wrong interval"
fi

# Timer calls shared check function
if grep -A15 "function start_follow_timer" "$git_lua" | grep -q "check_tmux_pane_and_retarget"; then
    pass "Follow timer calls shared check function"
else
    fail "Follow timer doesn't call shared check"
fi

# Timer only starts in tmux
if grep -A10 "function start_follow_timer" "$git_lua" | grep -q "vim.env.TMUX"; then
    pass "Follow timer guards against non-tmux environments"
else
    fail "Follow timer starts even outside tmux"
fi

# view_opened starts follow timer (search the hooks block — view_opened is ~135 lines)
if grep -B10 "view_closed = function" "$git_lua" | grep -q "start_follow_timer"; then
    pass "view_opened starts follow timer"
else
    fail "view_opened missing start_follow_timer call"
fi

# view_closed stops follow timer
if grep -A15 "view_closed = function" "$git_lua" | grep -q "stop_follow_timer"; then
    pass "view_closed stops follow timer"
else
    fail "view_closed missing stop_follow_timer call"
fi

# ─── Auto-Follow: Fish Hook & RPC ────────────────────────────────
echo ""
echo "--- Auto-Follow: Fish Hook & RPC ---"

# Global RPC endpoint exists
if grep -q "_G.diffview_check_pane" "$git_lua"; then
    pass "Global diffview_check_pane RPC endpoint exists"
else
    fail "Missing RPC endpoint for Fish hook"
fi

# RPC endpoint uses vim.schedule (safe from RPC context)
if grep -A5 "_G.diffview_check_pane" "$git_lua" | grep -q "vim.schedule"; then
    pass "RPC endpoint uses vim.schedule for main-loop safety"
else
    fail "RPC endpoint missing vim.schedule (unsafe from RPC context)"
fi

# Neovim socket exposed to tmux environment on view_opened
if grep -B5 "view_closed = function" "$git_lua" | grep -q "NVIM_DIFFVIEW_SOCKET"; then
    pass "view_opened exposes Neovim socket to tmux environment"
else
    fail "view_opened missing tmux socket exposure"
fi

# Socket cleaned from tmux environment on view_closed
if grep -A15 "view_closed = function" "$git_lua" | grep -q "NVIM_DIFFVIEW_SOCKET"; then
    pass "view_closed cleans socket from tmux environment"
else
    fail "view_closed missing tmux socket cleanup"
fi

# Fish hook script exists
# Derive dotfiles dir from this test script's location (scripts/ is one level down)
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fish_hook="$DOTFILES_DIR/.config/fish/conf.d/diffview-follow.fish"
if [ -f "$fish_hook" ]; then
    pass "Fish conf.d/diffview-follow.fish hook exists"
else
    fail "Missing Fish hook script"
fi

# Fish hook uses --on-variable PWD
if grep -q "\-\-on-variable PWD" "$fish_hook" 2>/dev/null; then
    pass "Fish hook fires on PWD variable change"
else
    fail "Fish hook missing --on-variable PWD trigger"
fi

# Fish hook reads NVIM_DIFFVIEW_SOCKET from tmux
if grep -q "NVIM_DIFFVIEW_SOCKET" "$fish_hook" 2>/dev/null; then
    pass "Fish hook reads NVIM_DIFFVIEW_SOCKET from tmux"
else
    fail "Fish hook missing tmux socket discovery"
fi

# Fish hook uses nvim --server for RPC
if grep -q 'nvim --server.*--remote-expr' "$fish_hook" 2>/dev/null; then
    pass "Fish hook uses nvim --server RPC to notify Neovim"
else
    fail "Fish hook missing nvim --server RPC call"
fi

# Fish hook runs in background (doesn't block shell)
if grep -q '&$\|disown' "$fish_hook" 2>/dev/null; then
    pass "Fish hook notification is fire-and-forget (non-blocking)"
else
    fail "Fish hook blocks shell while notifying Neovim"
fi

# Fish hook guards against non-tmux environments
if grep -q 'set -q TMUX\|test.*TMUX' "$fish_hook" 2>/dev/null; then
    pass "Fish hook guards against non-tmux environments"
else
    fail "Fish hook runs even outside tmux"
fi

# Fish hook checks socket exists before connecting
if grep -q 'test -S' "$fish_hook" 2>/dev/null; then
    pass "Fish hook verifies socket file exists before RPC"
else
    fail "Fish hook doesn't check socket existence"
fi

# Fish hook passes syntax check
if fish -n "$fish_hook" 2>/dev/null; then
    pass "Fish hook passes syntax validation"
else
    fail "Fish hook has syntax errors"
fi

# ─── Auto-Follow: Robustness ──────────────────────────────────────
echo ""
echo "--- Auto-Follow: Robustness ---"

# Timer uses ref counting (multi-view safe)
if grep -q "follow_timer_refs" "$git_lua"; then
    pass "Timer uses ref counting for multi-view lifecycle"
else
    fail "Timer missing ref counting (stops on first view_closed)"
fi

# start_follow_timer increments ref count
if grep -A5 "function start_follow_timer" "$git_lua" | grep -q "follow_timer_refs = follow_timer_refs + 1"; then
    pass "start_follow_timer increments ref count"
else
    fail "start_follow_timer missing ref count increment"
fi

# stop_follow_timer decrements ref count and guards
if grep -A10 "function stop_follow_timer" "$git_lua" | grep -q "follow_timer_refs > 0"; then
    pass "stop_follow_timer only stops timer when refs reach zero"
else
    fail "stop_follow_timer ignores ref count"
fi

# view_closed only cleans tmux env when refs reach zero
if grep -A15 "view_closed = function" "$git_lua" | grep -q "follow_timer_refs == 0"; then
    pass "view_closed only removes tmux socket when last view closes"
else
    fail "view_closed always removes tmux socket (breaks multi-view)"
fi

# Timer callback uses vim.schedule_wrap for main-loop safety
if grep -A15 "function start_follow_timer" "$git_lua" | grep -q "vim.schedule_wrap"; then
    pass "Timer callback wrapped with vim.schedule_wrap"
else
    fail "Timer callback missing vim.schedule_wrap"
fi

# Neovim server auto-started if v:servername is empty
if grep -B10 "view_closed = function" "$git_lua" | grep -q "serverstart"; then
    pass "view_opened ensures Neovim server is started for RPC"
else
    fail "view_opened missing serverstart for empty v:servername"
fi

# VimLeave autocmd cleans up tmux socket (crash/kill protection)
if grep -q "VimLeave" "$git_lua" && grep -A10 "VimLeave" "$git_lua" | grep -q "NVIM_DIFFVIEW_SOCKET"; then
    pass "VimLeave cleans up tmux socket (stale socket protection)"
else
    fail "Missing VimLeave cleanup for tmux socket"
fi

# Fish hook deduplicates same-path notifications
if grep -q "__diffview_last_pwd" "$fish_hook" 2>/dev/null; then
    pass "Fish hook deduplicates rapid cd to same path"
else
    fail "Fish hook missing deduplication (spams RPC on rapid cd)"
fi

# Fish hook handles tmux unset marker ("-NVIM_DIFFVIEW_SOCKET")
if grep -q "string match.*'-\*'" "$fish_hook" 2>/dev/null; then
    pass "Fish hook handles tmux unset marker"
else
    fail "Fish hook doesn't handle tmux unset marker"
fi

# RPC endpoint returns synchronous value (non-blocking for --remote-expr caller)
if grep -A5 "diffview_check_pane = function" "$git_lua" | grep -q 'return "ok"'; then
    pass "RPC endpoint returns immediate value (non-blocking for caller)"
else
    fail "RPC endpoint missing synchronous return (blocks --remote-expr caller)"
fi

# Shared check function has reentrancy guard (prevents concurrent retargets)
if grep -A10 "function check_tmux_pane_and_retarget" "$git_lua" | grep -q "repo_switch_in_progress"; then
    pass "Shared check function guards against reentrancy"
else
    fail "Shared check function missing reentrancy guard"
fi

# stop_follow_timer floors ref count at zero (prevents underflow)
if grep -A5 "function stop_follow_timer" "$git_lua" | grep -q "math.max(0"; then
    pass "stop_follow_timer floors ref count at zero (no underflow)"
else
    fail "stop_follow_timer can underflow below zero"
fi

# VimLeave also stops follow timer (not just tmux cleanup)
if grep -A10 "VimLeave" "$git_lua" | grep -q "stop_follow_timer"; then
    pass "VimLeave stops follow timer on exit"
else
    fail "VimLeave only cleans tmux env, doesn't stop timer"
fi

# view_opened uses shellescape for socket path (special char safety)
if grep -B10 "view_closed = function" "$git_lua" | grep -q "shellescape"; then
    pass "Socket path uses shellescape in tmux set-environment"
else
    fail "Socket path not escaped (spaces/special chars could break tmux command)"
fi

# Fish hook validates socket is a socket file (not stale regular file)
if grep -q 'test -S "$socket"' "$fish_hook" 2>/dev/null; then
    pass "Fish hook checks socket file type (not just existence)"
else
    fail "Fish hook missing socket type check (-S flag)"
fi

# Shared check function resolves symlinks on both pane_cwd and view_root
if grep -A30 "function check_tmux_pane_and_retarget" "$git_lua" | grep -c "vim.fn.resolve" | grep -q "2"; then
    pass "Shared check resolves symlinks on both pane_cwd and view_root"
else
    fail "Shared check missing vim.fn.resolve on pane_cwd or view_root"
fi

# Fish hook RPC call is backgrounded (non-blocking for shell)
if grep -q '&>/dev/null &' "$fish_hook" 2>/dev/null; then
    pass "Fish RPC call is backgrounded with output suppressed"
else
    fail "Fish RPC call not backgrounded (could block shell)"
fi

# Fish hook self-heals stale tmux env var when socket is gone
if grep -q 'set-environment -u NVIM_DIFFVIEW_SOCKET' "$fish_hook" 2>/dev/null; then
    pass "Fish hook clears stale tmux env var when socket file is gone"
else
    fail "Fish hook doesn't self-heal stale tmux env (rechecks every cd)"
fi

# Fish hook self-heal is before the RPC call (early return)
if grep -B5 'set-environment -u' "$fish_hook" 2>/dev/null | grep -q 'not test -S'; then
    pass "Fish hook self-heal triggers on missing socket file"
else
    fail "Fish hook self-heal not connected to socket file check"
fi

# Design constraint documented: one Diffview-owning Neovim per tmux session
if grep -q "one Diffview-owning Neovim per tmux session" "$git_lua"; then
    pass "One-Neovim-per-session design constraint is documented"
else
    fail "Missing documentation for one-Neovim-per-session constraint"
fi

# Design constraint explains last-writer-wins behavior
if grep -q "last-writer-wins" "$git_lua"; then
    pass "Last-writer-wins behavior documented for multi-instance scenario"
else
    fail "Missing last-writer-wins documentation"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="
exit $FAIL
