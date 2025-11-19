function _autopair_tab
    commandline --paging-mode && down-or-search && return

    string match --quiet --regex -- '\$[^\s]*"$' (commandline --current-token) &&
        commandline --function end-of-line --function backward-delete-char

    # Delegate to fifc/git/docker wrapper if available, otherwise use standard complete
    if functions -q _fifc_or_fzf
        _fifc_or_fzf
    else
        commandline --function complete
    end
end
