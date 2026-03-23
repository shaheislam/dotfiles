function gwtt-prompt-file --description 'Resolve the gwtt-prompt.local.md path for a directory'
    # Resolves the per-directory gwtt-prompt.local.md file path.
    # Each git repo gets its own prompt file at <repo>/.claude/gwtt-prompt.local.md
    # Auto-creates the file if it doesn't exist. No global fallback.
    #
    # Usage:
    #   gwtt-prompt-file           # resolve for CWD (auto-creates if missing)
    #   gwtt-prompt-file /path     # resolve for specific directory
    #
    # Output: absolute path to the resolved prompt file
    # Exit 1: not inside a git repository

    set -l target_dir ""

    for arg in $argv
        switch $arg
            case --create
                # Accepted for backwards compat, but auto-create is now the default
                true
            case '*'
                set target_dir $arg
        end
    end

    # Default to CWD
    if test -z "$target_dir"
        set target_dir (pwd)
    end

    # Find git root for the target directory
    set -l git_root (git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null)

    if test -z "$git_root"
        echo "Error: not inside a git repository: $target_dir" >&2
        return 1
    end

    set -l repo_prompt "$git_root/.claude/gwtt-prompt.local.md"

    if not test -f "$repo_prompt"
        mkdir -p "$git_root/.claude"
        set -l repo_name (basename $git_root)
        printf '# %s — Task Prompt\n\nDescribe your task here.\n' "$repo_name" >"$repo_prompt"
    end

    echo $repo_prompt
end
