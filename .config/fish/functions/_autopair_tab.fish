function _autopair_tab
    # Check if we're in paging mode and handle it properly
    if commandline --paging-mode
        commandline --function down-line
        return
    end

    string match --quiet --regex -- '\$[^\s]*"$' (commandline --current-token) &&
        commandline --function end-of-line --function backward-delete-char
    commandline --function complete
end
