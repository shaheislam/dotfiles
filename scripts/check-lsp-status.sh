#!/usr/bin/env bash
# Check status of Nix LSP hybrid setup

set -e

echo "=== Nix LSP Status Check ==="
echo ""

# Function to check if a command exists
check_cmd() {
	local cmd=$1
	local name=$2
	if command -v "$cmd" &>/dev/null; then
		local path
		local version
		path=$(command -v "$cmd")
		version=$($cmd --version 2>/dev/null | head -n 1 || echo "version unknown")

		# Check if it's from Nix
		if [[ "$path" == *"nix"* ]]; then
			echo "✅ $name: $path (Nix)"
			echo "   Version: $version"
		else
			echo "⚠️  $name: $path (Not from Nix)"
			echo "   Version: $version"
		fi
	else
		echo "❌ $name: Not installed"
	fi
}

# Check direnv status
echo "📦 Environment Management:"
if command -v direnv &>/dev/null; then
	echo "✅ direnv installed: $(which direnv)"

	# Check if direnv is hooked
	if [[ "$DIRENV_DIFF" ]]; then
		echo "   ✅ direnv is active in current shell"
	else
		echo "   ℹ️  direnv installed but not active in current directory"
	fi
else
	echo "❌ direnv not installed (needed for project overrides)"
fi

echo ""
echo "🔧 Language Servers:"
echo ""

# Go
echo "Go:"
check_cmd "gopls" "gopls"
check_cmd "golangci-lint" "golangci-lint"
check_cmd "delve" "delve"
check_cmd "gofumpt" "gofumpt (formatter)"

echo ""

# Python
echo "Python:"
check_cmd "basedpyright-langserver" "basedpyright"
check_cmd "pyright-langserver" "pyright"
check_cmd "ruff-lsp" "ruff-lsp"
check_cmd "debugpy" "debugpy"
check_cmd "black" "black (formatter)"
check_cmd "isort" "isort (formatter)"

echo ""

# Rust
echo "Rust:"
check_cmd "rust-analyzer" "rust-analyzer"
check_cmd "rustfmt" "rustfmt (formatter)"

echo ""

# TypeScript/JavaScript
echo "TypeScript/JavaScript:"
check_cmd "typescript-language-server" "typescript-language-server"
check_cmd "vtsls" "vtsls"
check_cmd "eslint-language-server" "eslint LSP"
check_cmd "prettier" "prettier (formatter)"

echo ""

# Terraform
echo "Terraform:"
check_cmd "terraform-ls" "terraform-ls"
check_cmd "tflint" "tflint"

echo ""

# Shell
echo "Shell:"
check_cmd "bash-language-server" "bash-language-server"
check_cmd "shellcheck" "shellcheck"
check_cmd "shfmt" "shfmt (formatter)"

echo ""

# Docker
echo "Docker:"
check_cmd "docker-langserver" "dockerfile LSP"
check_cmd "hadolint" "hadolint"

echo ""

# Other
echo "Other:"
check_cmd "yaml-language-server" "YAML LSP"
check_cmd "marksman" "Markdown LSP"
check_cmd "nil" "Nix LSP"
check_cmd "lua-language-server" "Lua LSP"
check_cmd "taplo" "TOML LSP"
check_cmd "sqls" "SQL LSP"
check_cmd "jdtls" "Java LSP"
check_cmd "clangd" "C/C++ LSP"
check_cmd "ansible-language-server" "Ansible LSP"
check_cmd "helm-ls" "Helm LSP"

echo ""
echo "=== Path Information ==="
echo ""

# Show Nix paths
echo "Nix Profile Paths:"
if [ -d "$HOME/.nix-profile/bin" ]; then
	echo "✅ ~/.nix-profile/bin exists"
	echo "   LSPs in profile: $(find "$HOME/.nix-profile/bin" -maxdepth 1 -name '*ls*' 2>/dev/null | wc -l | tr -d ' ')"
else
	echo "❌ ~/.nix-profile/bin does not exist"
fi

echo ""

# Check if in Nix shell
if [ -n "$IN_NIX_SHELL" ]; then
	echo "🐚 Currently in Nix shell"
elif [ -n "$DIRENV_DIR" ]; then
	echo "📁 direnv active in: $DIRENV_DIR"
else
	echo "ℹ️  Not in Nix shell or direnv environment"
fi

echo ""

# Check PATH precedence
echo "PATH precedence (first 5 entries):"
echo "$PATH" | tr ':' '\n' | head -5 | while read -r p; do
	if [[ "$p" == *"nix"* ]]; then
		echo "  • $p (Nix)"
	elif [[ "$p" == *"direnv"* ]]; then
		echo "  • $p (direnv)"
	else
		echo "  • $p"
	fi
done

echo ""
echo "=== Neovim Integration ==="
echo ""

# Check Neovim
if command -v nvim &>/dev/null; then
	echo "✅ Neovim installed: $(which nvim)"
	echo "   Version: $(nvim --version | head -n 1)"

	# Check for LazyVim
	if [ -d "$HOME/.config/nvim/lua/plugins" ]; then
		echo "✅ LazyVim configuration detected"

		# Check for our Nix LSP config
		if [ -f "$HOME/.config/nvim/lua/plugins/nix-lsp.lua" ]; then
			echo "✅ Nix LSP configuration found"
		else
			echo "⚠️  Nix LSP configuration not found"
		fi

		# Check if Mason is disabled
		if [ -f "$HOME/.config/nvim/lua/plugins/mason-disabled.lua" ]; then
			echo "✅ Mason.nvim is disabled"
		else
			echo "⚠️  Mason.nvim might still be active"
		fi
	fi
else
	echo "❌ Neovim not installed"
fi

echo ""
echo "=== Summary ==="
echo ""

# Count installed LSPs
total_lsps=0
nix_lsps=0
for cmd in gopls basedpyright-langserver pyright-langserver ruff-lsp rust-analyzer typescript-language-server terraform-ls bash-language-server yaml-language-server marksman nil lua-language-server taplo; do
	if command -v "$cmd" &>/dev/null; then
		((total_lsps++)) || true
		if [[ "$(which "$cmd")" == *"nix"* ]]; then
			((nix_lsps++)) || true
		fi
	fi
done

echo "📊 LSP Status:"
echo "   Total LSPs found: $total_lsps"
echo "   From Nix: $nix_lsps"
echo "   From other sources: $((total_lsps - nix_lsps))"

echo ""
echo "💡 Recommendations:"

if [ "$nix_lsps" -eq 0 ]; then
	echo "   • Run: ./scripts/install-lsps-global.sh"
	echo "     to install global baseline LSPs"
fi

if ! command -v direnv &>/dev/null; then
	echo "   • Install direnv for project overrides:"
	echo "     brew install direnv"
fi

if [ "$total_lsps" -lt 5 ]; then
	echo "   • Few LSPs detected. Run:"
	echo "     ./scripts/activate-nix-lsps.sh hybrid"
fi

if [ "$nix_lsps" -eq "$total_lsps" ] && [ "$nix_lsps" -gt 0 ]; then
	echo "   ✅ All LSPs are from Nix - setup looks good!"
fi

echo ""
echo "📚 For more information:"
echo "   • Check Neovim LSP status: <leader>nl"
echo "   • Check formatter status: <leader>nf"
echo "   • View documentation: cat ~/dotfiles/NIX_LSP_SETUP.md"
