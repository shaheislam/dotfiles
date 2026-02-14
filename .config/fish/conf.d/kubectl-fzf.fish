# kubectl FZF completion loader
# Sources native kubectl completions for __fish_kubectl_* functions
# Tab completion routing is handled by _fifc_or_fzf → _kubectl_fzf_tab_complete

# PERF: Deferred to fish_prompt event to avoid expensive type -q at startup
# (~25-45ms savings with large PATH). Completions are ready before user interaction.
if status is-interactive
    function __kubectl_fzf_init --on-event fish_prompt
        functions -e __kubectl_fzf_init # run once then remove
        if not type -q kubectl
            return
        end
        # Source the native kubectl.fish completions to get __fish_kubectl_* functions
        # These provide comprehensive resource/namespace/container completion logic
        # Required by kubectl_fzf_native.fish
        if test -f ~/.config/fish/completions/kubectl.fish
            source ~/.config/fish/completions/kubectl.fish
        end
    end
else
    # Non-interactive: early exit if kubectl unavailable
    if not type -q kubectl
        exit
    end
    if test -f ~/.config/fish/completions/kubectl.fish
        source ~/.config/fish/completions/kubectl.fish
    end
end

# Note: We no longer erase completions here.
# kubectl_fzf_native.fish handles FZF routing for resources while
# preserving native flag completions (--namespace, --output, etc.)
# Tab completion is routed via _fifc_or_fzf → _kubectl_fzf_tab_complete
