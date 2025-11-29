function _terraform_fzf_tab_complete -d "FZF tab completion for terraform"
    set -l cmd (commandline -opc) 2>/dev/null
    set -l cmdline (commandline)

    if test (count $cmd) -lt 1
        _fifc 2>/dev/null
        return
    end

    # Check if -chdir is already specified
    set -l chdir_path ""
    if string match -q '*-chdir=*' "$cmdline"
        set chdir_path (string match -r -- '-chdir=([^ ]+)' "$cmdline" | tail -1)
    end

    # Detect subcommand (plan, apply, destroy, init, validate)
    set -l subcommand ""
    for i in (seq 2 (count $cmd))
        set -l arg $cmd[$i]
        if string match -q -- '-chdir=*' $arg
            continue
        end
        if not string match -q -- '-*' $arg
            set subcommand $arg
            break
        end
    end

    # If -chdir already set and subcommand exists, show environment selection
    if test -n "$chdir_path"; and test -n "$subcommand"
        switch $subcommand
            case plan apply destroy
                _terraform_env_select "$chdir_path"
                return
            case init validate
                # These don't need var-file
                _fifc 2>/dev/null
                return
        end
    end

    # Otherwise, trigger full FZF flow for folder + env selection
    switch $subcommand
        case plan apply destroy init validate
            _terraform_fzf_command $subcommand
        case '*'
            _fifc 2>/dev/null
    end
end

function _terraform_env_select -d "Select environment for existing -chdir path"
    set -l tf_path $argv[1]

    # Find config directory
    set -l config_dir ""
    if test -d "$tf_path/config"
        set config_dir "$tf_path/config"
    else if test -d "$tf_path/environments"
        set config_dir "$tf_path/environments"
    else if test -d "$tf_path/vars"
        set config_dir "$tf_path/vars"
    end

    if test -z "$config_dir"
        _fifc 2>/dev/null
        return
    end

    set -l configs (find "$config_dir" -name "*.tfvars*" -type f 2>/dev/null | \
        xargs -I {} basename {} | sed 's/\.tfvars.*$//' | sort -u)

    if test -z "$configs"
        _fifc 2>/dev/null
        return
    end

    set -l selected_env (printf '%s\n' $configs | fzf \
        --prompt="Select environment: " \
        --header="Environments for $tf_path" \
        --height=40% --border)

    if test -n "$selected_env"
        set -l config_rel_path (string replace "$tf_path/" "" "$config_dir")
        if test -f "$config_dir/$selected_env.tfvars.json"
            commandline -i -- "-var-file=$config_rel_path/$selected_env.tfvars.json "
        else
            commandline -i -- "-var-file=$config_rel_path/$selected_env.tfvars "
        end
    end
    commandline -f repaint
end
