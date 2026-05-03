# Lazy-loader stub for helm_fzf_native
# The full implementation (~640 lines) is loaded only on first use
# This saves ~20ms startup time by deferring parsing until needed

function helm_fzf_native --description "FZF-powered helm completions (lazy-loaded)"
    # Load the full implementation
    set -l full_impl (status dirname)/_helm_fzf_native_full.fish
    if not test -f "$full_impl"
        set full_impl "$HOME/.config/fish/functions/_helm_fzf_native_full.fish"
    end

    if not test -f "$full_impl"
        return 1
    end

    source "$full_impl"
    # Call the now-loaded function with original arguments
    helm_fzf_native $argv
end
