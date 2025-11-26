# kubectl FZF completion loader
# Sources native kubectl completions for __fish_kubectl_* functions
# Tab completion routing is handled by _fifc_or_fzf → _kubectl_fzf_tab_complete

# Only proceed if kubectl is available
if not command -v kubectl >/dev/null
    exit
end

# Source the native kubectl.fish completions to get __fish_kubectl_* functions
# These provide comprehensive resource/namespace/container completion logic
# Required by kubectl_fzf_native.fish
if test -f ~/.config/fish/completions/kubectl.fish
    source ~/.config/fish/completions/kubectl.fish
end

# Erase default completions to prevent conflicts with FZF completions
# Tab completion is routed via _fifc_or_fzf → _kubectl_fzf_tab_complete
for cmd in kubectl k kubecolor kctl
    complete -e -c $cmd
end
