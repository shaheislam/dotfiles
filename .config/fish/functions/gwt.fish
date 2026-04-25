function gwt --description "Unified gwt-* palette + pass-through (analogue of Pane's command palette)"
    # Pass-through:  gwt <action> [args...]   →  gwt-<action> [args...]
    # Picker:        gwt                      →  fzf over (action × worktree) rows
    #                gwt <typo>               →  fzf with <typo> as initial query
    #
    # Static map drives the picker. Any gwt-*.fish not in either list shows up
    # as an [unmapped] row so drift is visible, not silent.

    # Per-worktree actions take a worktree name as $argv[1]
    set -l per_worktree_actions claude nudge setup

    # Global actions don't take a worktree (or take their own non-worktree args)
    set -l global_actions status doctor dashboard mayor cleanup convoy queue town parallel dev ticket molecule mail ports

    # ── Pass-through mode ────────────────────────────────────────────
    if test (count $argv) -gt 0
        set -l action $argv[1]
        if functions -q "gwt-$action"
            gwt-$action $argv[2..-1]
            return $status
        end
    end

    set -l initial_query ""
    if test (count $argv) -gt 0
        set initial_query $argv[1]
    end

    # ── Build picker rows ────────────────────────────────────────────
    # Format: <prefix>\t<label>\t<action>\t<arg-or-empty>
    # fzf shows columns 1-2; columns 3-4 drive execution.
    set -l rows

    set -l worktrees
    if git rev-parse --git-dir >/dev/null 2>&1
        for line in (git worktree list --porcelain 2>/dev/null)
            if string match -q "worktree *" -- $line
                set -a worktrees (string replace "worktree " "" -- $line)
            end
        end
    end

    for action in $global_actions
        if functions -q "gwt-$action"
            set -a rows (printf '[global]\tgwt %s\t%s\t' $action $action)
        end
    end

    for action in $per_worktree_actions
        if not functions -q "gwt-$action"
            continue
        end
        for wt in $worktrees
            set -l wt_name (basename -- $wt)
            set -a rows (printf '[%s]\tgwt %s %s\t%s\t%s' $wt_name $action $wt_name $action $wt_name)
        end
    end

    # ── Drift detection: any gwt-*.fish missing from the map ─────────
    # Fish autoloads from $HOME/.config/fish/functions/ (which is a stow symlink
    # to ~/dotfiles/.config/fish/functions/). Iterating just one path avoids
    # double-counting via the symlink.
    set -l known $global_actions $per_worktree_actions
    set -l seen_actions
    for fn_file in $HOME/.config/fish/functions/gwt-*.fish
        if not test -e "$fn_file"
            continue
        end
        set -l fn_name (basename -- $fn_file .fish)
        # Skip the gwt umbrella itself
        if test "$fn_name" = gwt
            continue
        end
        # Strip "gwt-" prefix (positions 1-4, action starts at 5)
        set -l action (string sub -s 5 -- $fn_name)
        if contains -- $action $seen_actions
            continue
        end
        set -a seen_actions $action
        if not contains -- $action $known
            set -a rows (printf '[unmapped]\t%s (add to gwt.fish map)\t__unmapped__\t%s' $fn_name $fn_name)
        end
    end

    if test (count $rows) -eq 0
        echo "No gwt-* functions found" >&2
        return 1
    end

    set -l selected (printf '%s\n' $rows | fzf \
        --prompt='gwt ❯ ' \
        --header='kind         command' \
        --query="$initial_query" \
        --delimiter='\t' \
        --with-nth=1,2 \
        --tabstop=4 \
        --exit-0 \
        --select-1 \
        --bind='ctrl-/:toggle-preview')

    if test -z "$selected"
        return 0
    end

    set -l fields (string split \t -- $selected)
    set -l action $fields[3]
    set -l arg ""
    if test (count $fields) -ge 4
        set arg $fields[4]
    end

    if test "$action" = __unmapped__
        echo "Unmapped: $arg" >&2
        echo "Edit ~/dotfiles/.config/fish/functions/gwt.fish and add it to" >&2
        echo "either per_worktree_actions or global_actions." >&2
        return 1
    end

    if test -n "$arg"
        gwt-$action $arg
    else
        gwt-$action
    end
end
