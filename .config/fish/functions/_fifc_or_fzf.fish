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
            # --sub picker, then --agent picker, then bridge/model pickers, then skill picker
            if test (count $cmd) -ge 2; and test "$cmd[-1]" = --sub
                _claude_sub_fzf_tab_complete
            else if test (count $cmd) -ge 2; and test "$cmd[-1]" = --agent
                _claude_agent_fzf_tab_complete
            else if test (count $cmd) -ge 2; and test "$cmd[-1]" = --bridge
                _bridge_provider_fzf_tab_complete
            else if test (count $cmd) -ge 2; and test "$cmd[-1]" = --model
                # Cross-provider model picker
                set -l token (commandline --current-token)
                set -l entries
                # Claude
                set -a entries (printf '%-18s  %-10s  %s' sonnet "(claude)" "Sonnet 4.6 — fast, balanced")
                set -a entries (printf '%-18s  %-10s  %s' opus "(claude)" "Opus 4.6 — most capable")
                set -a entries (printf '%-18s  %-10s  %s' haiku "(claude)" "Haiku 4.5 — fastest, lightweight")
                # Codex / OpenAI
                set -a entries (printf '%-18s  %-10s  %s' o3 "(codex)" "OpenAI o3 — reasoning")
                set -a entries (printf '%-18s  %-10s  %s' o4-mini "(codex)" "OpenAI o4-mini — fast reasoning")
                set -a entries (printf '%-18s  %-10s  %s' gpt-4.1 "(codex)" "GPT-4.1 — flagship")
                # Gemini
                set -a entries (printf '%-18s  %-10s  %s' gemini-2.5-pro "(gemini)" "Gemini 2.5 Pro — thinking")
                set -a entries (printf '%-18s  %-10s  %s' gemini-2.5-flash "(gemini)" "Gemini 2.5 Flash — fast")
                # DeepSeek
                set -a entries (printf '%-18s  %-10s  %s' deepseek-r1 "(deepseek)" "R1 — reasoning")
                set -a entries (printf '%-18s  %-10s  %s' deepseek-v3 "(deepseek)" "V3 — general")
                # Ollama (dynamic from local install)
                if command -q ollama
                    for m in (ollama list 2>/dev/null | tail -n +2 | string replace -r '\s+.*' '')
                        set -a entries (printf '%-18s  %-10s  %s' "$m" "(ollama)" "local")
                    end
                end
                set -l result (printf '%s\n' $entries \
                    | fzf --exit-0 --no-multi \
                        --prompt='model ❯ ' \
                        --header='model              provider    description' --query="$token")
                if test -n "$result"
                    set -l model (string match -r '^\S+' -- "$result")
                    commandline --replace --current-token -- "$model"
                    commandline --insert ' '
                end
                commandline --function repaint
            else
                _gwt_ticket_fzf_tab_complete
            end
        else if contains -- "$cmd[1]" gwt-claude gwtc
            # --sub picker, else fifc
            if test (count $cmd) -ge 2; and test "$cmd[-1]" = --sub
                _claude_sub_fzf_tab_complete
            else
                _fifc
            end
        else if contains -- "$cmd[1]" gwt-queue gwtq
            # --sub picker, else fifc
            if test (count $cmd) -ge 2; and test "$cmd[-1]" = --sub
                _claude_sub_fzf_tab_complete
            else
                _fifc
            end
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
