# PERF: Lazy-load kubectl completions on first tab-complete.
# The full completion file (2022 lines) takes ~16ms to source at startup.
# This stub defers that cost until kubectl is actually tab-completed.

function __fish_kubectl_lazy_init
    # Remove the lazy stub completions
    complete -c kubectl -e
    functions -e __fish_kubectl_lazy_init
    # Source the full completion file
    source (status dirname)/kubectl.fish.full
end

# Register a single completion that triggers lazy loading
complete -c kubectl -f -a '(__fish_kubectl_lazy_init)'
