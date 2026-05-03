# PERF: Lazy-load kubectl completions on first tab-complete.
# The full completion file (2022 lines) takes ~16ms to source at startup.
# This stub defers that cost until kubectl is actually tab-completed.

set -g __fish_kubectl_completion_full_path (status dirname)/kubectl.fish.full

function __fish_kubectl_source_full_completion
    set -l completion_path $__fish_kubectl_completion_full_path
    if test -z "$completion_path"; or not test -f "$completion_path"
        set completion_path "$HOME/.config/fish/completions/kubectl.fish.full"
    end

    if test -f "$completion_path"
        source "$completion_path"
    end
end

function __fish_kubectl_lazy_init
    # Remove the lazy stub completions
    complete -c kubectl -e
    functions -e __fish_kubectl_lazy_init
    # Source the full completion file
    __fish_kubectl_source_full_completion
end

# Register a single completion that triggers lazy loading
complete -c kubectl -f -a '(__fish_kubectl_lazy_init)'
