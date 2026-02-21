function cc-lsp --description "Manage Claude Code LSP server integration"
    set -l cmd $argv[1]

    # LSP plugins from boostvolt/claude-code-lsps marketplace
    # Each plugin name maps to a language server binary
    set -l lsp_map \
        "pyright:pyright-langserver:Python" \
        "typescript:typescript-language-server:TypeScript" \
        "gopls:gopls:Go" \
        "rust-analyzer:rust-analyzer:Rust" \
        "bash-lsp:bash-language-server:Bash" \
        "yaml-lsp:yaml-language-server:YAML" \
        "terraform:terraform-ls:Terraform" \
        "lua-lsp:lua-language-server:Lua" \
        "nix-lsp:nil:Nix"

    switch "$cmd"
        case status ''
            echo "Claude Code LSP Status"
            echo "━━━━━━━━━━━━━━━━━━━━━━"
            printf "%-20s %-30s %s\n" Plugin Binary Status
            echo "────────────────────────────────────────────────────────────────"

            set -l ok 0
            set -l missing 0

            for entry in $lsp_map
                set -l parts (string split ":" $entry)
                set -l plugin $parts[1]
                set -l binary $parts[2]
                set -l lang $parts[3]

                if command -q $binary
                    set -l ver (command $binary --version 2>/dev/null | head -1 | string trim)
                    printf "%-20s %-30s \033[32m✓\033[0m %s\n" "$plugin ($lang)" $binary "$ver"
                    set ok (math $ok + 1)
                else
                    printf "%-20s %-30s \033[31m✗ not in PATH\033[0m\n" "$plugin ($lang)" $binary
                    set missing (math $missing + 1)
                end
            end

            echo "────────────────────────────────────────────────────────────────"
            echo "$ok available, $missing missing"

            if test $missing -gt 0
                echo ""
                echo "Missing binaries can be installed via:"
                echo "  nix develop ~/dotfiles/nix/global/  # Nix global devShell"
                echo "  brew install <binary>               # Homebrew"
            end

        case install
            echo "Installing Claude Code LSP plugins..."
            claude plugin marketplace add boostvolt/claude-code-lsps 2>/dev/null; or true

            for entry in $lsp_map
                set -l parts (string split ":" $entry)
                set -l plugin $parts[1]
                set -l lang $parts[3]
                echo -n "  $plugin ($lang)... "
                if claude plugin install $plugin@claude-code-lsps 2>/dev/null
                    echo "✓"
                else
                    echo "✗ (may already be installed)"
                end
            end

            echo ""
            echo "Restart Claude Code to activate LSP servers."

        case doctor
            echo "Claude Code LSP Doctor"
            echo "━━━━━━━━━━━━━━━━━━━━━"

            # Check claude command
            if command -q claude
                echo "✓ claude CLI found"
            else
                echo "✗ claude CLI not found"
                return 1
            end

            # Check marketplace
            set -l marketplaces (claude plugin marketplace list 2>/dev/null)
            if string match -q "*boostvolt/claude-code-lsps*" "$marketplaces"
                echo "✓ boostvolt/claude-code-lsps marketplace added"
            else
                echo "✗ boostvolt/claude-code-lsps marketplace not added"
                echo "  Fix: claude plugin marketplace add boostvolt/claude-code-lsps"
            end

            # Check each binary
            set -l all_ok true
            for entry in $lsp_map
                set -l parts (string split ":" $entry)
                set -l binary $parts[2]
                set -l lang $parts[3]
                if command -q $binary
                    echo "✓ $binary ($lang) in PATH"
                else
                    echo "✗ $binary ($lang) not in PATH"
                    set all_ok false
                end
            end

            # Check Nix availability
            if command -q nix
                echo "✓ Nix available (nix develop provides LSP binaries)"
            else
                echo "⚠ Nix not available (install LSP binaries via Homebrew)"
            end

            if test "$all_ok" = true
                echo ""
                echo "All LSP servers healthy."
            else
                echo ""
                echo "Some LSP binaries missing. Run: cc-lsp status"
            end

        case help '*'
            echo "Usage: cc-lsp <command>"
            echo ""
            echo "Commands:"
            echo "  status   Show LSP plugin and binary status (default)"
            echo "  install  Install all LSP plugins from marketplace"
            echo "  doctor   Health check for LSP integration"
            echo "  help     Show this help"
            echo ""
            echo "LSP plugins provide Claude Code with native code intelligence:"
            echo "  - Instant diagnostics (errors/warnings after edits)"
            echo "  - Go to definition, find references, hover info"
            echo "  - Document and workspace symbol search"
            echo ""
            echo "Plugins configure the LSP connection; binaries come from Nix or Homebrew."
            echo "See: docs/claude-code-lsp.md"
    end
end
