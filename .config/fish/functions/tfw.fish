function tfw --description "Switch Terraform workspace with fzf"
    if not test -x /opt/homebrew/bin/terraform
        echo "Terraform not installed"
        return 1
    end

    if not test -d .terraform
        echo "Not in a Terraform directory (no .terraform folder)"
        return 1
    end

    set -l workspaces (terraform workspace list | sed 's/^[* ] //')
    if test -z "$workspaces"
        echo "No Terraform workspaces found"
        return 1
    end

    set -l selected (printf '%s\n' $workspaces | fzf \
        --prompt="Select Terraform workspace: " \
        --height=40% \
        --border)

    if test -n "$selected"
        terraform workspace select $selected
        echo "Switched to workspace: $selected"
    end
end
