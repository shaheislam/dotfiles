function nix-init-flake --description "Initialize a flake.nix from template"
    if test (count $argv) -eq 0
        echo "Usage: nix-init-flake <template>"
        echo "Available templates:"
        echo "  default  - Basic development environment"
        echo "  devops   - DevOps tools (Terraform, Ansible, K8s)"
        echo "  backend  - Backend development (Go, Rust, Python)"
        echo "  frontend - Frontend development (React, Vue, TypeScript)"
        echo ""
        echo "Example: nix-init-flake devops"
        return 1
    end

    if test -f flake.nix
        echo "Error: flake.nix already exists in current directory"
        return 1
    end

    set -l template $argv[1]
    set -l template_file "$HOME/dotfiles/nix/flake-templates/$template.nix"

    if not test -f $template_file
        # Try with .nix extension if not provided
        set template_file "$HOME/dotfiles/nix/flake-templates/$template"
        if not test -f $template_file
            echo "Error: Template '$template' not found"
            echo "Available templates: default, devops, backend, frontend"
            return 1
        end
    end

    echo "Creating flake.nix from template: $template"
    cp $template_file flake.nix

    # Also create .envrc for direnv if it doesn't exist
    if not test -f .envrc
        echo "use flake" >.envrc
        echo "Created .envrc for direnv integration"
        echo "Run 'direnv allow' to activate the environment automatically"
    end

    echo "✓ flake.nix created successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review and customize flake.nix for your project"
    echo "  2. Run 'nix develop' to enter the development shell"
    echo "  3. Or run 'direnv allow' for automatic activation"
end
