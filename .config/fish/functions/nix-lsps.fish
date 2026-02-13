function nix-lsps --description "List available LSPs in current Nix environment"
    echo "Checking for LSPs in current environment..."
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

        if command -v $cmd >/dev/null 2>&1
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
        echo "  Tip: Enter a Nix shell with 'nix develop' in a project with flake.nix"
        echo "  Or use direnv to automatically load the environment"
    end

    echo ""
end
