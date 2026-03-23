function gwtt-prompt-file --description 'Resolve the gwtt-prompt.local.md path for a directory'
    # Resolves the per-directory gwtt-prompt.local.md file path.
    # Each git repo gets its own prompt file at <repo>/.claude/gwtt-prompt.local.md
    # Falls back to $HOME/dotfiles/.claude/gwtt-prompt.local.md if no per-repo file exists.
    #
    # Usage:
    #   gwtt-prompt-file           # resolve for CWD
    #   gwtt-prompt-file /path     # resolve for specific directory
    #   gwtt-prompt-file --create  # resolve for CWD, create if missing
    #   gwtt-prompt-file --create /path
    #
    # Flags:
    #   --create   Create the prompt file (with template) if it doesn't exist
    #   --global   Return the global fallback path (no per-repo resolution)
    #
    # Output: absolute path to the resolved prompt file

    set -l create_mode false
    set -l global_mode false
    set -l target_dir ""

    for arg in $argv
        switch $arg
            case --create
                set create_mode true
            case --global
                set global_mode true
            case '*'
                set target_dir $arg
        end
    end

    set -l global_prompt "$HOME/dotfiles/.claude/gwtt-prompt.local.md"

    if $global_mode
        echo $global_prompt
        return 0
    end

    # Default to CWD
    if test -z "$target_dir"
        set target_dir (pwd)
    end

    # Find git root for the target directory
    set -l git_root (git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null)

    if test -n "$git_root"
        set -l repo_prompt "$git_root/.claude/gwtt-prompt.local.md"

        if test -f "$repo_prompt"
            echo $repo_prompt
            return 0
        end

        if $create_mode
            mkdir -p "$git_root/.claude"
            set -l repo_name (basename $git_root)
            printf '# %s — Task Prompt\n\nDescribe your task here.\n' "$repo_name" >"$repo_prompt"
            echo $repo_prompt
            return 0
        end
    end

    # Fallback to global
    if test -f "$global_prompt"
        echo $global_prompt
        return 0
    end

    if $create_mode
        mkdir -p (dirname $global_prompt)
        printf '# Task Prompt\n\nDescribe your task here.\n' >"$global_prompt"
        echo $global_prompt
        return 0
    end

    # Nothing found
    echo $global_prompt
    return 1
end
