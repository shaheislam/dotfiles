# kubectl FZF completion loader
# Sources native kubectl completions for __fish_kubectl_* functions
# Tab completion routing is handled by _fifc_or_fzf → _kubectl_fzf_tab_complete

# Only proceed if kubectl is available
if not type -q kubectl
    exit
end

# Source the native kubectl.fish completions to get __fish_kubectl_* functions
# These provide comprehensive resource/namespace/container completion logic
# Required by kubectl_fzf_native.fish
if test -f ~/.config/fish/completions/kubectl.fish
    source ~/.config/fish/completions/kubectl.fish
end

# Note: We no longer erase completions here.
# kubectl_fzf_native.fish handles FZF routing for resources while
# preserving native flag completions (--namespace, --output, etc.)
# Tab completion is routed via _fifc_or_fzf → _kubectl_fzf_tab_complete
