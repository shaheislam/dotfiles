function _terraform_fzf_command --description "Build terraform command with FZF selection"
    set -l action $argv[1] # plan, apply, destroy, init, validate

    if not command -q git; or not command -q find; or not command -q fzf
        return 1
    end

    # 1. Find git root (works from any subdirectory)
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$git_root"
        return 1
    end

    # 2. Find terraform ROOT directories (exclude vendor/modules which are reusable modules)
    #    Only show directories that are actual terraform roots
    set -l tf_dirs (find "$git_root" -name "*.tf" -type f \
        -not -path "*/.terraform/*" \
        -not -path "*/vendor/*" \
        -not -path "*/modules/*" \
        2>/dev/null | \
        xargs -I {} dirname {} | sort -u | \
        sed "s|$git_root/||")

    if test -z "$tf_dirs"
        return 1
    end

    # 3. FZF to select terraform directory (shows relative path)
    set -l header "Terraform: Alt-t p=plan | a=apply | d=destroy | i=init | v=validate"
    set -l selected_dir (printf '%s\n' $tf_dirs | fzf \
        --prompt="Select terraform directory: " \
        --header "$header" \
        --height=40% --border \
        --preview "ls -la $git_root/{}")

    if test -z "$selected_dir"
        return 1
    end

    set -l full_tf_path "$git_root/$selected_dir"

    # 4. Find config files (tfvars.json or tfvars) - check multiple common locations
    #    Skip for init/validate as they don't need var files
    set -l config_dir ""
    if test "$action" != init; and test "$action" != validate
        if test -d "$full_tf_path/config"
            set config_dir "$full_tf_path/config"
        else if test -d "$full_tf_path/environments"
            set config_dir "$full_tf_path/environments"
        else if test -d "$full_tf_path/vars"
            set config_dir "$full_tf_path/vars"
        end

        if test -n "$config_dir"
            set -l configs (find "$config_dir" -name "*.tfvars*" -type f 2>/dev/null | \
                xargs -I {} basename {} | sed 's/\.tfvars.*$//' | sort -u)

            if test -n "$configs"
                set -l selected_env (printf '%s\n' $configs | fzf \
                    --prompt="Select environment: " \
                    --header="Config dir: $config_dir" \
                    --height=40% --border)

                if test -n "$selected_env"
                    # Determine file extension and build relative path from tf dir
                    set -l config_rel_path (string replace "$full_tf_path/" "" "$config_dir")
                    if test -f "$config_dir/$selected_env.tfvars.json"
                        set var_file "$config_rel_path/$selected_env.tfvars.json"
                    else
                        set var_file "$config_rel_path/$selected_env.tfvars"
                    end
                end
            end
        end
    end

    # 5. Build command
    set -l cmd "terraform -chdir=$full_tf_path $action"
    if set -q var_file
        set cmd "$cmd -var-file=$var_file"
    end

    # 6. Insert into command line
    commandline --replace "$cmd"
    commandline -f repaint
end
