# Lazy-loader stub for helm_fzf_native
# The full implementation (~640 lines) is loaded only on first use
# This saves ~20ms startup time by deferring parsing until needed

function helm_fzf_native --description "FZF-powered helm completions (lazy-loaded)"
    # Load the full implementation
    source ~/.config/fish/functions/_helm_fzf_native_full.fish
    # Call the now-loaded function with original arguments
    helm_fzf_native $argv
end
