function gwt-doctor --description "Agent orchestration health check"
    # Usage: gwt-doctor [--fix] [--help]
    #
    # Runs health checks on the agent orchestration stack.
    # Reports PASS/WARN/FAIL for each check with colored output.
    #
    # Options:
    #   --fix, -f    Attempt to repair detected issues
    #   --help, -h   Show usage

    set -l do_fix false

    for arg in $argv
        switch $arg
            case --fix -f
                set do_fix true
            case --help -h
                echo "Usage: gwt-doctor [--fix] [--help]"
                echo ""
                echo "Agent orchestration health check."
                echo ""
                echo "Options:"
                echo "  --fix, -f    Attempt to repair detected issues"
                echo "  --help, -h   Show this help"
                return 0
        end
    end

    set -l pass_count 0
    set -l warn_count 0
    set -l fail_count 0

    echo ""
    echo "gwt-doctor - Agent orchestration health check"
    echo ""

    # Find scripts using dual-path pattern
    set -l scripts_dir ""
    for p in ~/dotfiles/scripts ~/dotfiles-gastownbeads/scripts
        if test -d "$p"
            set scripts_dir $p
            break
        end
    end

    # Detect if we're in a git repo
    set -l in_git_repo false
    if git rev-parse --git-dir >/dev/null 2>&1
        set in_git_repo true
    end

    # Helper: get worktree paths (only if in git repo)
    set -l wt_paths
    if $in_git_repo
        for line in (git worktree list --porcelain 2>/dev/null)
            if string match -q "worktree *" $line
                set -a wt_paths (string replace "worktree " "" $line)
            end
        end
    end

    # ── Check 1: Git worktrees ──
    if $in_git_repo
        set -l prunable (git worktree list --porcelain 2>/dev/null | grep -c "^prunable" 2>/dev/null; or echo 0)
        set -l wt_count (count $wt_paths)
        if test "$prunable" -gt 0
            printf "  %s[FAIL]%s Git worktrees: %d prunable\n" (set_color red) (set_color normal) $prunable
            set fail_count (math $fail_count + 1)
            if $do_fix
                git worktree prune
                printf "         → Pruned stale worktrees\n"
            end
        else
            # Check all worktree paths exist
            set -l missing 0
            for wt in $wt_paths
                if not test -d "$wt"
                    set missing (math $missing + 1)
                end
            end
            if test $missing -gt 0
                printf "  %s[FAIL]%s Git worktrees: %d paths missing\n" (set_color red) (set_color normal) $missing
                set fail_count (math $fail_count + 1)
                if $do_fix
                    git worktree prune
                    printf "         → Pruned stale worktrees\n"
                end
            else
                printf "  %s[PASS]%s Git worktrees clean (%d active)\n" (set_color green) (set_color normal) $wt_count
                set pass_count (math $pass_count + 1)
            end
        end
    else
        printf "  %s[WARN]%s Git worktrees: not in a git repository\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    end

    # ── Check 2: tmux agent window colors ──
    if not command -q tmux; or not tmux list-sessions >/dev/null 2>&1
        printf "  %s[WARN]%s tmux agent colors: tmux not running (skipped)\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    else
        set -l inactive_format (tmux show-option -gqv window-status-format 2>/dev/null)
        set -l current_format (tmux show-option -gqv window-status-current-format 2>/dev/null)
        if string match -q '*@wname_style*' -- $inactive_format; and string match -q '*@wname_style*' -- $current_format
            printf "  %s[PASS]%s tmux agent colors wired through @wname_style\n" (set_color green) (set_color normal)
            set pass_count (math $pass_count + 1)
        else
            printf "  %s[FAIL]%s tmux agent colors: status formats missing @wname_style\n" (set_color red) (set_color normal)
            set fail_count (math $fail_count + 1)
            if $do_fix
                tmux source-file ~/.tmux.conf
                printf "         → Reloaded ~/.tmux.conf\n"
            end
        end
    end

    # ── Check 3: Merge queue daemon ──
    set -l mq_pid_file /tmp/merge-queue-daemon.pid
    if test -f "$mq_pid_file"
        if kill -0 (cat $mq_pid_file) 2>/dev/null
            printf "  %s[PASS]%s Merge queue daemon running (PID %s)\n" (set_color green) (set_color normal) (cat $mq_pid_file)
            set pass_count (math $pass_count + 1)
        else
            printf "  %s[FAIL]%s Merge queue daemon: stale PID file\n" (set_color red) (set_color normal)
            set fail_count (math $fail_count + 1)
            if $do_fix
                rm -f $mq_pid_file /tmp/merge-queue-daemon.lock
                printf "         → Removed stale PID + lock files\n"
            end
        end
    else
        printf "  %s[WARN]%s Merge queue daemon not running\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    end

    # ── Check 4: Ticket queue daemon ──
    set -l tq_pid_file ~/.claude/ticket-queue.pid
    if test -f "$tq_pid_file"
        if kill -0 (cat $tq_pid_file) 2>/dev/null
            printf "  %s[PASS]%s Ticket queue daemon running (PID %s)\n" (set_color green) (set_color normal) (cat $tq_pid_file)
            set pass_count (math $pass_count + 1)
        else
            printf "  %s[FAIL]%s Ticket queue daemon: stale PID file\n" (set_color red) (set_color normal)
            set fail_count (math $fail_count + 1)
            if $do_fix
                rm -f $tq_pid_file
                printf "         → Removed stale PID file. Run 'gwt-queue start' to restart.\n"
            end
        end
    else
        printf "  %s[WARN]%s Ticket queue daemon not running\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    end

    # ── Check 5: Worktree witnesses ──
    if $in_git_repo
        set -l active_wts
        set -l missing_witnesses
        for wt in $wt_paths
            set -l state_file "$wt/.claude/ticket-execute.local.md"
            if test -f "$state_file"
                set -l active_val (grep "^active:" $state_file | head -1 | string replace -r '^active: *' '' | string trim | tr -d '"')
                if test "$active_val" = true
                    set -a active_wts $wt
                    set -l witness_pid_file "$wt/.claude/witness.pid"
                    if test -f "$witness_pid_file"
                        if not kill -0 (cat $witness_pid_file) 2>/dev/null
                            set -a missing_witnesses $wt
                        end
                    else
                        set -a missing_witnesses $wt
                    end
                end
            end
        end
        if test (count $active_wts) -eq 0
            printf "  %s[WARN]%s Worktree witnesses: no active worktrees\n" (set_color yellow) (set_color normal)
            set warn_count (math $warn_count + 1)
        else if test (count $missing_witnesses) -gt 0
            printf "  %s[FAIL]%s Worktree witnesses: %d of %d missing\n" (set_color red) (set_color normal) (count $missing_witnesses) (count $active_wts)
            set fail_count (math $fail_count + 1)
            if $do_fix
                set -l witness_script ""
                for p in ~/dotfiles/scripts/worktree-witness.sh ~/dotfiles-gastownbeads/scripts/worktree-witness.sh
                    if test -x "$p"
                        set witness_script $p
                        break
                    end
                end
                if test -n "$witness_script"
                    for wt in $missing_witnesses
                        $witness_script start $wt &
                        disown
                        printf "         → Spawned witness for %s\n" (basename $wt)
                    end
                else
                    printf "         → worktree-witness.sh not found\n"
                end
            end
        else
            printf "  %s[PASS]%s All witnesses running (%d active)\n" (set_color green) (set_color normal) (count $active_wts)
            set pass_count (math $pass_count + 1)
        end
    else
        printf "  %s[WARN]%s Worktree witnesses: not in a git repository\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    end

    # ── Check 6: Stale phase gates ──
    if $in_git_repo
        set -l stale_gates
        # Check all worktree paths for gates.json where worktree no longer exists
        for wt in $wt_paths
            if not test -d "$wt"; and test -f "$wt/.claude/gates.json"
                set -a stale_gates "$wt/.claude/gates.json"
            end
        end
        # Also scan for gates in worktrees that are gone (check parent dirs)
        set -l git_common (git rev-parse --git-common-dir 2>/dev/null)
        if test -n "$git_common" -a -d "$git_common/worktrees"
            for wt_ref in $git_common/worktrees/*/
                set -l wt_name (basename $wt_ref)
                set -l gitdir_file "$wt_ref/gitdir"
                if test -f "$gitdir_file"
                    set -l wt_dir (string replace '/.git' '' (cat $gitdir_file))
                    if not test -d "$wt_dir"; and test -f "$wt_dir/.claude/gates.json"
                        set -a stale_gates "$wt_dir/.claude/gates.json"
                    end
                end
            end
        end
        if test (count $stale_gates) -gt 0
            printf "  %s[FAIL]%s Stale phase gates: %d found\n" (set_color red) (set_color normal) (count $stale_gates)
            set fail_count (math $fail_count + 1)
            if $do_fix
                for gate in $stale_gates
                    rm -f $gate
                    printf "         → Removed %s\n" $gate
                end
            end
        else
            printf "  %s[PASS]%s No stale phase gates\n" (set_color green) (set_color normal)
            set pass_count (math $pass_count + 1)
        end
    else
        printf "  %s[PASS]%s No stale phase gates (not in git repo)\n" (set_color green) (set_color normal)
        set pass_count (math $pass_count + 1)
    end

    # ── Check 7: Stale state files ──
    if $in_git_repo
        set -l stale_states
        for wt in $wt_paths
            set -l state_file "$wt/.claude/ticket-execute.local.md"
            if test -f "$state_file"
                set -l active_val (grep "^active:" $state_file | head -1 | string replace -r '^active: *' '' | string trim | tr -d '"')
                if test "$active_val" = true
                    # Check if agent process is actually running in tmux for this worktree
                    set -l wt_name (basename $wt)
                    set -l has_claude false
                    if command -q tmux; and tmux list-sessions >/dev/null 2>&1
                        # Check if there's a tmux window with this worktree name that has a running agent process
                        set -l pane_pids (tmux list-panes -a -F "#{pane_pid} #{window_name}" 2>/dev/null | grep -i "$wt_name" | awk '{print $1}')
                        for pid in $pane_pids
                            # Check if agent (claude or codex) is among child processes
                            if pgrep -P $pid -f "claude|codex" >/dev/null 2>&1
                                set has_claude true
                                break
                            end
                        end
                    end
                    if not $has_claude
                        set -a stale_states $state_file
                    end
                end
            end
        end
        if test (count $stale_states) -gt 0
            printf "  %s[FAIL]%s Stale state files: %d dead active tickets\n" (set_color red) (set_color normal) (count $stale_states)
            set fail_count (math $fail_count + 1)
            if $do_fix
                for sf in $stale_states
                    sed -i '' 's/active: true/active: false/' $sf
                    printf "         → Set inactive: %s\n" (basename (dirname (dirname $sf)))
                end
            end
        else
            printf "  %s[PASS]%s No stale state files\n" (set_color green) (set_color normal)
            set pass_count (math $pass_count + 1)
        end
    else
        printf "  %s[PASS]%s No stale state files (not in git repo)\n" (set_color green) (set_color normal)
        set pass_count (math $pass_count + 1)
    end

    # ── Check 8: Zombie tmux sessions ──
    if command -q tmux; and tmux list-sessions >/dev/null 2>&1
        set -l zombie_windows
        if $in_git_repo
            set -l tmux_windows (tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name}" 2>/dev/null)
            for wline in $tmux_windows
                set -l wname (echo $wline | awk '{print $2}')
                # Check if window name matches a worktree pattern but worktree no longer exists
                for wt in $wt_paths
                    set -l wt_name (basename $wt)
                    if test "$wname" = "$wt_name"; and not test -d "$wt"
                        set -a zombie_windows $wline
                    end
                end
            end
        end
        if test (count $zombie_windows) -gt 0
            printf "  %s[WARN]%s Zombie tmux windows: %d found\n" (set_color yellow) (set_color normal) (count $zombie_windows)
            set warn_count (math $warn_count + 1)
            if $do_fix
                for zw in $zombie_windows
                    set -l target (echo $zw | awk '{print $1}')
                    tmux kill-window -t "$target" 2>/dev/null
                    printf "         → Killed window %s\n" $target
                end
            end
        else
            printf "  %s[PASS]%s No zombie tmux windows\n" (set_color green) (set_color normal)
            set pass_count (math $pass_count + 1)
        end
    else
        printf "  %s[WARN]%s Zombie tmux windows: tmux not running (skipped)\n" (set_color yellow) (set_color normal)
        set warn_count (math $warn_count + 1)
    end

    # ── Check 9: Beads ──
    if command -q bd
        if test -d ".beads"
            # Deep check: verify hooks are installed
            set -l hooks_ok true
            for hook in post-checkout post-merge
                if not test -f ".beads/hooks/$hook"
                    set hooks_ok false
                    break
                end
            end
            if $hooks_ok
                printf "  %s[PASS]%s Beads installed, active, hooks present\n" (set_color green) (set_color normal)
                set pass_count (math $pass_count + 1)

                # Quality sub-checks (informational, don't affect pass/fail)
                set -l stale_count (bd stale --days 14 2>/dev/null | wc -l | string trim)
                if test "$stale_count" -gt 0
                    printf "         %s[INFO]%s %s stale beads (>14 days, run: bd stale --days 14)\n" (set_color yellow) (set_color normal) $stale_count
                end

                set -l in_prog_count (bd count --status=in_progress 2>/dev/null | string trim)
                if test -n "$in_prog_count"; and test "$in_prog_count" -gt 5
                    printf "         %s[INFO]%s %s in-progress beads (too many? run: bd list --status=in_progress)\n" (set_color yellow) (set_color normal) $in_prog_count
                end
            else
                printf "  %s[WARN]%s Beads active but hooks incomplete\n" (set_color yellow) (set_color normal)
                set warn_count (math $warn_count + 1)
                if $do_fix
                    printf "         → Reinstalling hooks (bd hooks install)...\n"
                    if bd hooks install 2>/dev/null
                        printf "         → %sFixed%s\n" (set_color green) (set_color normal)
                    else
                        printf "         → %sFailed%s (run manually: bd hooks install)\n" (set_color red) (set_color normal)
                    end
                end
            end
        else
            printf "  %s[WARN]%s Beads installed but no .beads/ in current dir\n" (set_color yellow) (set_color normal)
            set warn_count (math $warn_count + 1)
            if $do_fix; and $in_git_repo
                printf "         → Initializing beads (bd init --quiet)...\n"
                if bd init --quiet 2>/dev/null
                    printf "         → %sFixed%s\n" (set_color green) (set_color normal)
                else
                    printf "         → %sFailed%s (run manually: bd init)\n" (set_color red) (set_color normal)
                end
            end
        end
    else
        printf "  %s[FAIL]%s Beads not installed\n" (set_color red) (set_color normal)
        set fail_count (math $fail_count + 1)
        if $do_fix
            printf "         → Install with: brew install beads\n"
        end
    end

    # ── Summary ──
    echo ""
    printf "  %s%d passed%s, %s%d warning%s, %s%d failure%s\n" \
        (set_color green) $pass_count (set_color normal) \
        (set_color yellow) $warn_count (set_color normal) \
        (set_color red) $fail_count (set_color normal)
    echo ""

    if test $fail_count -gt 0; and not $do_fix
        echo "  Run 'gwt-doctor --fix' to attempt repairs"
        echo ""
    end

    # Return non-zero if any failures
    if test $fail_count -gt 0
        return 1
    end
    return 0
end
