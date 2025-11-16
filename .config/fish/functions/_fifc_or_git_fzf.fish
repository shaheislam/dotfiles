function _fifc_or_git_fzf -d "Wrapper to route TAB completion between git fzf and fifc"
    # Get the current command line tokens
    set -l cmd (commandline -opc)

    # Check if the first command is 'git'
    if test (count $cmd) -ge 1; and test "$cmd[1]" = "git"
        # Use git-specific fzf completion
        _git_fzf_tab_complete
    else
        # Use standard fifc completion for all other commands
        _fifc
    end
end
