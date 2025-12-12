# Lazy-loader stub for kubectl_fzf_native
# The full implementation (~628 lines) is loaded only on first use
# This saves ~20ms startup time by deferring parsing until needed

# Global variables needed before loading full implementation
set -g kubectl_use_fzf true
set -g KUBECTL_FZF_CACHE "/tmp/kubectl_fzf_cache"
set -g KUBECTL_FZF_CACHE_MAX_AGE 60

function kubectl_fzf_native --description "FZF-powered kubectl completions (lazy-loaded)"
    # Load the full implementation
    source ~/.config/fish/functions/_kubectl_fzf_native_full.fish
    # Call the now-loaded function with original arguments
    kubectl_fzf_native $argv
end
