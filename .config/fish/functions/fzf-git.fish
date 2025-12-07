function __fzf_git_sh
    # Get the absolute path to the parent directory of this script (i.e. the
    # parent directory of fzf-git.sh) to use in the key bindings to avoid
    # having to modify `$PATH`.
    set --function fzf_git_sh_path (realpath (status dirname))

    # Get the current token to use as query and to replace
    set --function current_token (commandline --current-token)

    # Don't use -- as query (it breaks grep in fzf-git.sh)
    set --function query "$current_token"
    if test "$current_token" = "--"
        set query ""
    end

    # Run the FZF git script and capture the result, passing the current token as query
    set --function result (FZF_GIT_QUERY="$query" SHELL=bash bash "$fzf_git_sh_path/fzf-git.sh" --run $argv | string join ' ')

    # Only insert the result if something was selected (not cancelled with ESC)
    if test -n "$result"
        if test -n "$current_token"
            # Replace the current token with the result
            commandline --current-token --replace "$result "
        else
            # Insert if no current token
            commandline --insert "$result "
        end
    end
end

set --local commands branches each_ref files hashes lreflogs remotes stashes tags worktrees

for command in $commands
    set --function key (string sub --length=1 $command)

    eval "bind -M default \cg$key   '__fzf_git_sh $command'"
    eval "bind -M insert  \cg$key   '__fzf_git_sh $command'"
    eval "bind -M default \cg\c$key '__fzf_git_sh $command'"
    eval "bind -M insert  \cg\c$key '__fzf_git_sh $command'"
end
