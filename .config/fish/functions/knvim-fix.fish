# Fix Neovim configuration compatibility issues in pods
# Usage: knvim-fix <namespace> <pod> [container]

function knvim-fix --description "Fix Neovim config compatibility issues in a Kubernetes pod"
    # Get the directory where dotfiles are located
    set -l dotfiles_dir (dirname (dirname (dirname (dirname (status --current-filename)))))
    set -l script_path "$dotfiles_dir/scripts/fix-nvim-in-pod.sh"

    # Check if the script exists
    if not test -f "$script_path"
        echo "Error: fix-nvim-in-pod.sh not found at $script_path" >&2
        return 1
    end

    # Check if we have the required arguments
    if test (count $argv) -lt 2
        echo "Usage: knvim-fix <namespace> <pod> [container]" >&2
        echo "Example: knvim-fix default my-pod my-container" >&2
        echo "" >&2
        echo "This fixes Neovim configuration compatibility issues" >&2
        return 1
    end

    # Execute the script with all arguments
    bash "$script_path" $argv
end

# Reuse completions from knvim
complete -c knvim-fix -w knvim