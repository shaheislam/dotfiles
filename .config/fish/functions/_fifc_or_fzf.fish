function _fifc_or_fzf -d "Wrapper to route TAB completion between git/docker/kubectl fzf and fifc"
    # Get the current command line tokens
    set -l cmd (commandline -opc)

    # Route to appropriate completion based on command
    if test (count $cmd) -ge 1
        if test "$cmd[1]" = "git"
            # Use git-specific fzf completion
            _git_fzf_tab_complete
        else if test "$cmd[1]" = "docker"
            # Use docker-specific fzf completion
            _docker_fzf_tab_complete
        else if contains -- "$cmd[1]" kubectl k kubecolor kctl
            # Use kubectl-specific fzf completion
            _kubectl_fzf_tab_complete
        else if test "$cmd[1]" = "stern"
            # Use stern-specific fzf completion (no trailing space)
            _stern_fzf_tab_complete
        else if test "$cmd[1]" = "ecs"
            # Use ECS-specific fzf completion
            _ecs_fzf_tab_complete
        else if test "$cmd[1]" = "helm"
            # Use helm-specific fzf completion
            _helm_fzf_tab_complete
        else
            # Use standard fifc completion for all other commands
            _fifc
        end
    else
        # Use standard fifc completion when no command present
        _fifc
    end
end
