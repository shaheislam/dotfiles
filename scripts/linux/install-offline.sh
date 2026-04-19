#!/usr/bin/env bash

# install-offline.sh - Offline installer for air-gapped AWS workspaces
# Installs dotfiles and binaries without internet access

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$SCRIPT_DIR/binaries"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
INSTALL_DIR="$HOME/.local/bin"

# Flags
DRY_RUN=false
SKIP_BINARIES=false
SKIP_DOTFILES=false
VERBOSE=false

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
	echo -e "\n${CYAN}========================================${NC}"
	echo -e "${CYAN}$1${NC}"
	echo -e "${CYAN}========================================${NC}\n"
}

print_step() {
	echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
	echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
	echo -e "${RED}✗ $1${NC}"
}

log_verbose() {
	if [[ $VERBOSE == true ]]; then
		echo -e "${CYAN}[VERBOSE] $1${NC}"
	fi
}

# ============================================================================
# Help Function
# ============================================================================

show_help() {
	cat <<EOF
Offline Dotfiles Installer

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Preview actions without executing
    --skip-binaries     Skip installing pre-downloaded binaries
    --skip-dotfiles     Skip dotfiles installation
    --verbose           Show detailed output
    -h, --help          Show this help message

EXAMPLES:
    $0                      # Full installation
    $0 --dry-run            # Preview what will be installed
    $0 --skip-binaries      # Only install dotfiles

DESCRIPTION:
    Installs dotfiles and pre-downloaded binaries on an air-gapped
    system without requiring internet access.

    This script will:
    - Install binaries to ~/.local/bin
    - Symlink dotfiles using stow (or manual fallback)
    - Configure Fish, Zsh, tmux, and Neovim
    - Set up PATH in shell configs

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--skip-binaries)
			SKIP_BINARIES=true
			shift
			;;
		--skip-dotfiles)
			SKIP_DOTFILES=true
			shift
			;;
		--verbose)
			VERBOSE=true
			shift
			;;
		-h | --help)
			show_help
			exit 0
			;;
		*)
			echo -e "${RED}Unknown option: $1${NC}"
			show_help
			exit 1
			;;
		esac
	done
}

# ============================================================================
# Check Prerequisites
# ============================================================================

check_prerequisites() {
	print_header "Checking Prerequisites"

	local missing=()

	# Check for required commands
	if ! command -v bash &>/dev/null; then
		missing+=("bash")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		print_error "Missing required tools: ${missing[*]}"
		return 1
	fi

	# Check for optional but recommended tools
	local recommended=()

	if ! command -v stow &>/dev/null; then
		print_warning "stow not found (recommended for dotfile management)"
		recommended+=("stow")
	fi

	if ! command -v fish &>/dev/null; then
		print_warning "fish shell not found"
		recommended+=("fish")
	fi

	if ! command -v zsh &>/dev/null; then
		print_warning "zsh shell not found"
		recommended+=("zsh")
	fi

	if ! command -v tmux &>/dev/null; then
		print_warning "tmux not found"
		recommended+=("tmux")
	fi

	if ! command -v nvim &>/dev/null; then
		print_warning "neovim not found"
		recommended+=("neovim")
	fi

	if [[ ${#recommended[@]} -gt 0 ]]; then
		echo ""
		print_warning "Some recommended tools are missing: ${recommended[*]}"
		print_warning "Install them from system repos if available"
		echo ""
	fi

	print_success "Prerequisites checked"
}

# ============================================================================
# Install Binaries
# ============================================================================

install_binaries() {
	if [[ $SKIP_BINARIES == true ]]; then
		print_warning "Skipping binary installation"
		return
	fi

	print_header "Installing Binaries"

	if [[ ! -d "$BINARIES_DIR" ]]; then
		print_warning "Binaries directory not found: $BINARIES_DIR"
		return
	fi

	# Create install directory
	if [[ $DRY_RUN == false ]]; then
		mkdir -p "$INSTALL_DIR"
	fi

	# Count and list binaries
	local binary_count
	binary_count=$(find "$BINARIES_DIR" -type f -executable 2>/dev/null | wc -l)

	if [[ $binary_count -eq 0 ]]; then
		print_warning "No binaries found in $BINARIES_DIR"
		return
	fi

	print_step "Found $binary_count binaries to install"

	# Install each binary
	for binary in "$BINARIES_DIR"/*; do
		if [[ -f "$binary" && -x "$binary" ]]; then
			local binary_name
			binary_name=$(basename "$binary")

			if [[ $DRY_RUN == true ]]; then
				echo "  Would install: $binary_name → $INSTALL_DIR/$binary_name"
			else
				cp "$binary" "$INSTALL_DIR/"
				chmod +x "$INSTALL_DIR/$binary_name"
				log_verbose "Installed: $binary_name"
				print_success "Installed: $binary_name"
			fi
		fi
	done

	print_success "Binaries installed to $INSTALL_DIR"
}

# ============================================================================
# Install Dotfiles
# ============================================================================

install_dotfiles() {
	if [[ $SKIP_DOTFILES == true ]]; then
		print_warning "Skipping dotfiles installation"
		return
	fi

	print_header "Installing Dotfiles"

	if [[ ! -d "$DOTFILES_DIR" ]]; then
		print_error "Dotfiles directory not found: $DOTFILES_DIR"
		return 1
	fi

	cd "$DOTFILES_DIR"

	# Try stow first (preferred method)
	if command -v stow &>/dev/null; then
		print_step "Using stow for dotfile symlinking..."

		if [[ $DRY_RUN == true ]]; then
			print_warning "DRY RUN: Would run 'stow . --adopt --verbose'"
		else
			if stow . --adopt --verbose 2>&1 | tee /tmp/stow-output.log; then
				print_success "Dotfiles symlinked with stow"
			else
				print_warning "Stow encountered issues, check /tmp/stow-output.log"
			fi
		fi
	else
		# Manual symlinking fallback
		print_warning "stow not available, using manual symlinking"
		install_dotfiles_manual
	fi
}

install_dotfiles_manual() {
	print_step "Manually symlinking dotfiles..."

	local linked=0
	# Link root-level dotfiles
	for file in "$DOTFILES_DIR"/.??*; do
		[[ ! -f "$file" && ! -d "$file" ]] && continue

		local filename
		filename=$(basename "$file")

		# Skip .git and other excluded files
		[[ "$filename" == ".git" ]] && continue
		[[ "$filename" == ".gitignore" ]] && continue
		[[ "$filename" == ".gitmodules" ]] && continue

		local target="$HOME/$filename"

		if [[ $DRY_RUN == true ]]; then
			echo "  Would link: $filename"
		else
			# Backup existing file
			if [[ -e "$target" && ! -L "$target" ]]; then
				mv "$target" "${target}.backup.$(date +%s)"
				log_verbose "Backed up existing: $filename"
			fi

			# Create symlink
			ln -sf "$file" "$target"
			log_verbose "Linked: $filename"
			((linked++)) || true
		fi
	done

	# Link .config directory
	if [[ -d "$DOTFILES_DIR/.config" ]]; then
		mkdir -p "$HOME/.config"

		for dir in "$DOTFILES_DIR/.config"/*; do
			[[ ! -d "$dir" ]] && continue

			local dirname
			dirname=$(basename "$dir")
			local target="$HOME/.config/$dirname"

			if [[ $DRY_RUN == true ]]; then
				echo "  Would link: .config/$dirname"
			else
				# Backup existing directory
				if [[ -e "$target" && ! -L "$target" ]]; then
					mv "$target" "${target}.backup.$(date +%s)"
					log_verbose "Backed up existing: .config/$dirname"
				fi

				# Create symlink
				ln -sf "$dir" "$target"
				log_verbose "Linked: .config/$dirname"
				((linked++)) || true
			fi
		done
	fi

	if [[ $DRY_RUN == false ]]; then
		print_success "Manually symlinked $linked dotfiles"
	fi
}

# ============================================================================
# Configure Shell
# ============================================================================

configure_shell() {
	print_header "Configuring Shell"

	# Add ~/.local/bin to PATH in bashrc
	local bashrc="$HOME/.bashrc"

	if [[ $DRY_RUN == true ]]; then
		print_warning "DRY RUN: Would add ~/.local/bin to PATH"
	else
		if [[ -f "$bashrc" ]] && ! grep -q '.local/bin' "$bashrc"; then
			print_step "Adding ~/.local/bin to PATH in $bashrc"

			cat >>"$bashrc" <<'EOF'

# Added by dotfiles offline installer
export PATH="$HOME/.local/bin:$PATH"
EOF
			print_success "PATH updated in $bashrc"
		else
			log_verbose "$HOME/.local/bin already in PATH or .bashrc not found"
		fi
	fi

	# Source the updated bashrc for current session
	if [[ $DRY_RUN == false && -f "$bashrc" ]]; then
		# Note: can't actually source in a subshell, just inform user
		print_warning "Run 'source ~/.bashrc' to update PATH in current session"
	fi
}

# ============================================================================
# Post-Install Instructions
# ============================================================================

show_post_install() {
	print_header "Installation Complete!"

	echo "Dotfiles and binaries have been installed."
	echo ""
	echo "Next steps:"
	echo ""
	echo "  1. Reload your shell configuration:"
	echo "     source ~/.bashrc"
	echo ""
	echo "  2. Verify binaries are available:"
	echo "     which starship eza zoxide"
	echo ""
	echo "  3. If using tmux, start it and install plugins:"
	echo "     tmux"
	echo "     Press Ctrl-s + I (capital i)"
	echo ""
	echo "  4. If using Neovim, start it to complete setup:"
	echo "     nvim"
	echo ""
	echo "  5. To use Fish shell (if installed):"
	echo "     fish"
	echo ""

	if command -v fish &>/dev/null; then
		echo "Fish shell detected. To set as default:"
		echo "  chsh -s \$(which fish)"
		echo ""
	fi

	if ! command -v stow &>/dev/null; then
		echo "Note: stow is not installed. Manual symlinking was used."
		echo "For better dotfile management, consider installing stow:"
		echo "  sudo yum install stow    # Amazon Linux/RHEL"
		echo "  sudo apt install stow    # Ubuntu/Debian"
		echo ""
	fi

	print_success "Enjoy your configured environment! 🚀"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
	parse_args "$@"

	print_header "Dotfiles Offline Installer"

	if [[ $DRY_RUN == true ]]; then
		print_warning "DRY RUN MODE - No changes will be made"
	fi

	echo "Installation directory: $INSTALL_DIR"
	echo "Dotfiles source: $DOTFILES_DIR"
	echo ""

	# Run installation steps
	check_prerequisites
	install_binaries
	install_dotfiles
	configure_shell

	# Show post-install instructions
	if [[ $DRY_RUN == false ]]; then
		show_post_install
	else
		print_warning "DRY RUN complete - no changes were made"
	fi
}

# Run main function
main "$@"
