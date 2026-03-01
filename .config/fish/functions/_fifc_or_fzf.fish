function _fifc_or_fzf -d "Wrapper to route TAB completion between git/docker/kubectl fzf and fifc"
    # Get the current command line tokens
    set -l cmd (commandline -opc)

    # Route to appropriate completion based on command
    if test (count $cmd) -ge 1
        if test "$cmd[1]" = git
            # Use git-specific fzf completion
            _git_fzf_tab_complete
        else if test "$cmd[1]" = docker
            # Use docker-specific fzf completion
            _docker_fzf_tab_complete
        else if contains -- "$cmd[1]" kubectl k kubecolor kctl
            # Use kubectl-specific fzf completion
            _kubectl_fzf_tab_complete
        else if test "$cmd[1]" = stern
            # Use stern-specific fzf completion (no trailing space)
            _stern_fzf_tab_complete
        else if test "$cmd[1]" = ecs
            # Use ECS-specific fzf completion
            _ecs_fzf_tab_complete
        else if test "$cmd[1]" = helm
            # Use helm-specific fzf completion
            _helm_fzf_tab_complete
        else if test "$cmd[1]" = terraform; or test "$cmd[1]" = tf
            # Use terraform-specific fzf completion
            _terraform_fzf_tab_complete
        else if contains -- "$cmd[1]" cd z pushd
            # Zoxide fzf picker with scope switching (alt-l/g/s/p)
            _cd_fzf_tab_complete
        else if test "$cmd[1]" = ssh
            # Use ssh host fzf picker
            _ssh_fzf_tab_complete
        else if test "$cmd[1]" = claude
            # Use claude session picker (only activates after --resume / -r)
            _claude_resume_fzf_tab_complete
        else if test "$cmd[1]" = gwt-ticket; or test "$cmd[1]" = gwtt
            # Use gwt-ticket skill multiselect picker (only activates after --skill)
            _gwt_ticket_fzf_tab_complete
        else if test "$cmd[1]" = make; or test "$cmd[1]" = gmake
            # Use Makefile target fzf picker
            _make_fzf_tab_complete
        else if test "$cmd[1]" = fdiff; or test "$cmd[1]" = rm
            # Use fzf-git files picker for fdiff and rm (when in a git repo)
            __fzf_git_sh files 2>/dev/null || _fifc
        else
            # Use standard fifc completion for all other commands
            _fifc
        end
    else
        # Use standard fifc completion when no command present
        _fifc
    end
end
