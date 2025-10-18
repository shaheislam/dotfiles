# Nix Package Manager Integration for Fish Shell

# Check if Nix is installed
if test -e /nix

    # Source Nix daemon for multi-user installation (macOS)
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
        source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    # Alternative location for some installations
    else if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
        source '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
    # Single-user installation fallback
    else if test -e "$HOME/.nix-profile/etc/profile.d/nix.fish"
        source "$HOME/.nix-profile/etc/profile.d/nix.fish"
    end

    # Add Nix profile bin to PATH if not already there
    if test -d "$HOME/.nix-profile/bin"
        if not contains "$HOME/.nix-profile/bin" $PATH
            set -gx PATH "$HOME/.nix-profile/bin" $PATH
        end
    end

    # Add Home Manager profile bin to PATH if it exists
    if test -d "$HOME/.local/state/nix/profiles/home-manager/home-path/bin"
        if not contains "$HOME/.local/state/nix/profiles/home-manager/home-path/bin" $PATH
            set -gx PATH "$HOME/.local/state/nix/profiles/home-manager/home-path/bin" $PATH
        end
    end

    # Set NIX_PATH if not already set
    if not set -q NIX_PATH
        set -gx NIX_PATH nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs:/nix/var/nix/profiles/per-user/root/channels
    end

    # Helper Functions for Nix Operations

    # Quick nix shell with packages
    function nix-shell-with --description "Start nix shell with specified packages"
        if test (count $argv) -eq 0
            echo "Usage: nix-shell-with package1 [package2 ...]"
            echo "Example: nix-shell-with nodejs python3 go"
            return 1
        end

        set -l packages
        for pkg in $argv
            set packages $packages "nixpkgs#$pkg"
        end

        echo "Starting Nix shell with: $argv"
        nix shell $packages
    end

    # Search for packages
    function nix-search --description "Search for Nix packages"
        if test (count $argv) -eq 0
            echo "Usage: nix-search <package-name>"
            return 1
        end

        nix search nixpkgs $argv[1]
    end

    # Update flake in current directory
    function nix-update --description "Update flake.lock in current directory"
        if not test -f flake.nix
            echo "Error: No flake.nix found in current directory"
            return 1
        end

        echo "Updating flake.lock..."
        nix flake update
    end

    # Clean up Nix store
    function nix-clean --description "Clean up Nix store (garbage collection)"
        echo "Running Nix garbage collection..."
        nix-collect-garbage -d
        echo "Optimizing Nix store..."
        nix-store --optimise
    end

    # Show what LSPs are available in current Nix environment
    function nix-lsps --description "List available LSPs in current Nix environment"
        echo "🔍 Checking for LSPs in current environment..."
        echo ""

        # Define LSP commands to check
        set -l lsp_commands \
            "gopls:Go" \
            "rust-analyzer:Rust" \
            "typescript-language-server:TypeScript/JavaScript" \
            "basedpyright:Python (Basedpyright)" \
            "pyright:Python (Pyright)" \
            "ruff-lsp:Python (Ruff)" \
            "terraform-ls:Terraform" \
            "ansible-language-server:Ansible" \
            "helm_ls:Helm" \
            "docker-langserver:Docker" \
            "yaml-language-server:YAML" \
            "vscode-json-language-server:JSON" \
            "lua-language-server:Lua" \
            "marksman:Markdown" \
            "nil:Nix" \
            "bash-language-server:Bash" \
            "taplo:TOML" \
            "buf-language-server:Protocol Buffers" \
            "sqls:SQL"

        set -l found_any 0

        for lsp in $lsp_commands
            set -l parts (string split ":" $lsp)
            set -l cmd $parts[1]
            set -l name $parts[2]

            if command -v $cmd > /dev/null 2>&1
                set found_any 1
                set -l lsp_version ""

                # Try to get version info
                switch $cmd
                    case gopls
                        set lsp_version (gopls version 2>/dev/null | head -1 | string replace -r '.*: ' '' || echo "")
                    case rust-analyzer
                        set lsp_version (rust-analyzer --version 2>/dev/null | cut -d' ' -f2 || echo "")
                    case typescript-language-server
                        set lsp_version (typescript-language-server --version 2>/dev/null || echo "")
                    case terraform-ls
                        set lsp_version (terraform-ls version 2>/dev/null | head -1 || echo "")
                    case '*'
                        # Try generic --version flag
                        set lsp_version (eval $cmd --version 2>/dev/null | head -1 || echo "")
                end

                if test -n "$lsp_version"
                    echo "  ✓ $name ($cmd) - $lsp_version"
                else
                    echo "  ✓ $name ($cmd)"
                end
            end
        end

        if test $found_any -eq 0
            echo "  No LSPs found in current environment"
            echo ""
            echo "  💡 Tip: Enter a Nix shell with 'nix develop' in a project with flake.nix"
            echo "  Or use direnv to automatically load the environment"
        end

        echo ""
    end

    # Create a flake.nix from template
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
            echo "use flake" > .envrc
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

    # Check Nix flake status
    function nix-status --description "Show Nix environment status"
        echo "🚀 Nix Environment Status"
        echo "========================"
        echo ""

        # Check Nix version
        if command -v nix > /dev/null 2>&1
            set -l nix_version (nix --version | string split ' ')[3]
            echo "Nix Version: $nix_version"
        else
            echo "Nix: Not installed ❌"
            return 1
        end

        # Check if in Nix shell
        if set -q IN_NIX_SHELL
            echo "Nix Shell: Active ✓"
            if set -q name
                echo "Shell Name: $name"
            end
        else
            echo "Nix Shell: Inactive"
        end

        # Check for flake.nix
        if test -f flake.nix
            echo "Flake: Found ✓"
            if test -f flake.lock
                echo "Flake Lock: Found ✓"
                set -l lock_date (date -r flake.lock "+%Y-%m-%d %H:%M" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M" flake.lock 2>/dev/null || echo "unknown")
                echo "Last Updated: $lock_date"
            else
                echo "Flake Lock: Not found (run 'nix flake update')"
            end
        else
            echo "Flake: Not found in current directory"
        end

        # Check direnv status
        if command -v direnv > /dev/null 2>&1
            if test -f .envrc
                echo "Direnv: Configured ✓"
                if direnv status | grep -q "Found RC allowed"
                    echo "Direnv Status: Allowed ✓"
                else
                    echo "Direnv Status: Not allowed (run 'direnv allow')"
                end
            else
                echo "Direnv: No .envrc file"
            end
        else
            echo "Direnv: Not installed"
        end

        echo ""
        echo "Available LSPs:"
        nix-lsps
    end

    # Abbreviations for common Nix commands
    abbr --add nd "nix develop"
    abbr --add ndu "nix flake update"
    abbr --add nsh "nix shell"
    abbr --add nsn "nix shell nixpkgs#"
    abbr --add nsr "nix search nixpkgs"
    abbr --add nfu "nix flake update"
    abbr --add ngc "nix-collect-garbage -d"

    # Set environment indicator for prompt (if using custom prompt)
    if set -q IN_NIX_SHELL
        set -gx NIX_SHELL_INDICATOR "❄️"
    end

    # Home Manager functions
    function hm-switch --description "Switch to Home Manager configuration"
        if test -f "$HOME/.config/home-manager/flake.nix"
            echo "Switching to Home Manager configuration..."
            cd "$HOME/.config/home-manager" && \
            nix build .#homeConfigurations.shaheislam.activationPackage && \
            ./result/activate && \
            cd -
        else
            echo "Error: Home Manager flake not found at ~/.config/home-manager/flake.nix"
            return 1
        end
    end

    function hm-update --description "Update and switch Home Manager"
        if test -f "$HOME/.config/home-manager/flake.nix"
            echo "Updating Home Manager configuration..."
            cd "$HOME/.config/home-manager" && \
            nix flake update && \
            nix build .#homeConfigurations.shaheislam.activationPackage && \
            ./result/activate && \
            cd -
        else
            echo "Error: Home Manager flake not found"
            return 1
        end
    end

    function hm-packages --description "List packages installed by Home Manager"
        if test -e "$HOME/.local/state/nix/profiles/home-manager"
            # List packages in the Home Manager profile
            nix-store -q --requisites ~/.local/state/nix/profiles/home-manager | grep -E '/(bin|lib|share)' | xargs -I {} basename {} | sort -u | head -50
        else if test -d "$HOME/.nix-profile"
            # Fallback to listing nix profile packages
            ls ~/.nix-profile/bin/ 2>/dev/null | sort
        else
            echo "Home Manager not activated. Run 'hm-switch' first"
            return 1
        end
    end

    function hm-generations --description "List Home Manager generations"
        if command -v home-manager > /dev/null 2>&1
            home-manager generations
        else
            echo "Home Manager not activated"
            return 1
        end
    end

    function hm-rollback --description "Rollback to previous Home Manager generation"
        if command -v home-manager > /dev/null 2>&1
            set -l previous (home-manager generations | head -2 | tail -1 | cut -d' ' -f1)
            if test -n "$previous"
                echo "Rolling back to generation $previous..."
                "$previous/activate"
            else
                echo "No previous generation found"
                return 1
            end
        else
            echo "Home Manager not activated"
            return 1
        end
    end

    # Check inheritance status
    function nix-inheritance --description "Show Nix environment inheritance chain"
        echo "🔍 Nix Environment Inheritance"
        echo "=============================="

        # Check Home Manager
        if test -e "$HOME/.local/state/nix/profiles/home-manager"
            echo "✓ Home Manager: Active"
            echo "   Profile: $HOME/.local/state/nix/profiles/home-manager"
        else if test -d "$HOME/.nix-profile"
            echo "✓ Nix Profile: Active (Home Manager may be integrated)"
            echo "   Profile: $HOME/.nix-profile"
        else
            echo "✗ Home Manager: Not active"
        end

        # Check global environment
        if test -f "$HOME/dotfiles/nix/global/flake.nix"
            echo "✓ Global Dev Profile: Available"
        end

        # Check for work base
        if test -n "$WORK_NIX_BASE"
            echo "✓ Work Base: $WORK_ROOT"
        end

        # Check current directory
        if test -f flake.nix
            echo "✓ Local flake: $PWD/flake.nix"
            if test -f flake.lock
                echo "   Locked: Yes"
            else
                echo "   Locked: No (run 'nix flake update')"
            end
        end

        # Check if in Nix shell
        if set -q IN_NIX_SHELL
            echo ""
            echo "🚀 Active Nix Shell: $name"
        end

        # Show active LSPs
        echo ""
        echo "Available LSPs:"
        nix-lsps
    end

    # Abbreviations for Home Manager
    abbr --add hms "hm-switch"
    abbr --add hmu "hm-update"
    abbr --add hmp "hm-packages"
    abbr --add hmg "hm-generations"

else
    # Nix not installed - provide installation instructions
    function nix-install --description "Install Nix package manager"
        echo "Nix is not installed. Would you like to install it?"
        echo ""
        echo "Installation will use the Determinate Systems installer for better macOS support."
        echo "This requires sudo access for the multi-user installation."
        echo ""
        read -P "Install Nix now? (y/n) " -n 1 response
        echo ""

        if test "$response" = "y"
            echo "Installing Nix..."
            curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
            echo ""
            echo "✓ Nix installed! Please restart your shell or run:"
            echo "  exec fish"
        else
            echo "Skipping Nix installation."
            echo "You can install it later with: nix-install"
        end
    end
end