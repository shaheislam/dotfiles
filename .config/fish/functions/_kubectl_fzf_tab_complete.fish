function _kubectl_fzf_tab_complete -d "FZF tab completion for kubectl"
    set -l cmd (commandline -opc) 2>/dev/null

    # Need at least "kubectl" to proceed
    if test (count $cmd) -lt 1
        _fifc 2>/dev/null
        return
    end

    # Call kubectl_fzf_native which handles FZF selection internally
    # It returns the selected item
    set -l result (kubectl_fzf_native)

    if test -n "$result"
        # Replace current token with selection
        commandline -t -- "$result "
    end

    commandline -f repaint
end
