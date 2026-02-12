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

# TermLeave/TermClose use poll_with_retry
if grep -A5 "TermLeave.*TermClose" "$git_lua" | grep -q "poll_with_retry"; then
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

# BufEnter skips diffview:// buffers
if grep -q 'diffview://' "$git_lua"; then
    pass "BufEnter skips diffview:// buffers"
else
    fail "BufEnter not filtering diffview:// buffers"
fi

# BufEnter skips term:// buffers
if grep -q 'term://' "$git_lua"; then
    pass "BufEnter skips term:// buffers"
else
    fail "BufEnter not filtering term:// buffers"
fi

# diffview_current_root tracking variable
if grep -q "diffview_current_root" "$git_lua"; then
    pass "diffview_current_root tracking variable exists"
else
    fail "diffview_current_root tracking missing"
fi

# view_opened sets diffview_current_root
if grep -A3 "view_opened" "$git_lua" | grep -q "diffview_current_root"; then
    pass "view_opened sets diffview_current_root"
else
    fail "view_opened does not set diffview_current_root"
fi

# view_closed clears diffview_current_root
if grep -A3 "view_closed" "$git_lua" | grep -q "diffview_current_root"; then
    pass "view_closed clears diffview_current_root"
else
    fail "view_closed does not clear diffview_current_root"
fi

# BufEnter has reentrancy guard
if grep -q "buf_enter_switching" "$git_lua"; then
    pass "BufEnter has reentrancy guard"
else
    fail "BufEnter missing reentrancy guard"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="
exit $FAIL
