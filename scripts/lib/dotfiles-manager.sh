#!/usr/bin/env bash

# dotfiles-manager.sh - Stow-based dotfile management
# Handles symlinking dotfiles across macOS and Linux

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# Stow Installation
# ============================================================================

ensure_stow() {
	if command_exists stow; then
		return 0
	fi

	print_step "Installing stow..."

	if pm_install stow; then
		print_success "Stow installed"
		return 0
	else
		print_warning "Failed to install stow, will use manual symlinking"
		return 1
	fi
}

# ============================================================================
# Stow-based Symlinking
# ============================================================================

detect_stow_conflicts() {
	cd "$DOTFILES_ROOT" || return 1

	# Run stow in simulation mode to detect conflicts
	local conflicts
	conflicts=$(stow . --no --verbose 2>&1 | grep -E "existing target|cannot stow" | head -10)

	if [[ -n "$conflicts" ]]; then
		return 0 # Conflicts found
	fi
	return 1 # No conflicts
}

backup_conflicting_files() {
	print_step "Backing up conflicting files..."

	local backup_dir
	backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$backup_dir"

	cd "$DOTFILES_ROOT" || return 1

	# Get list of conflicting files
	local conflicts
	conflicts=$(stow . --no --verbose 2>&1 | grep "existing target" | sed -E 's/.*existing target (.*) since.*/\1/' | sed 's/^[ \t]*//')

	if [[ -z "$conflicts" ]]; then
		log_verbose "No files to backup"
		return 0
	fi

	# Backup each conflicting file
	while IFS= read -r file; do
		if [[ -n "$file" && -e "$HOME/$file" && ! -L "$HOME/$file" ]]; then
			local backup_path="$backup_dir/$file"
			mkdir -p "$(dirname "$backup_path")"
			cp -a "$HOME/$file" "$backup_path"
			log_verbose "Backed up: $file"
		fi
	done <<<"$conflicts"

	print_success "Backed up conflicting files to: $backup_dir"
	return 0
}

stow_dotfiles() {
	print_header "Symlinking Dotfiles"

	cd "$DOTFILES_ROOT" || return 1

	if ! ensure_stow; then
		manual_symlink_dotfiles
		return $?
	fi

	print_step "Running stow..."

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		stow . --no --verbose
		return 0
	fi

	# Check for conflicts first
	if detect_stow_conflicts; then
		print_warning "Stow conflicts detected"

		# Backup conflicting files
		backup_conflicting_files

		# Now run stow with --adopt to handle conflicts
		print_step "Running stow with conflict resolution..."
	fi

	if stow . --adopt --verbose 2>&1 | tee /tmp/stow-output.log; then
		print_success "Dotfiles symlinked with stow"

		# Check if any files were adopted
		if grep -q "LINK:" /tmp/stow-output.log; then
			print_warning "Some files were adopted (local versions kept)"
			log_verbose "Review changes with: git status"
		fi
	else
		print_warning "Stow encountered issues, see /tmp/stow-output.log"
		return 1
	fi

	# Link SSH config separately (not managed by stow)
	link_ssh_config
}

# ============================================================================
# SSH Configuration
# ============================================================================

link_ssh_config() {
	if [[ -f "$DOTFILES_ROOT/.ssh/config" ]]; then
		print_step "Linking SSH configuration..."
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"

		if [[ -f "$HOME/.ssh/config" ]] && [[ ! -L "$HOME/.ssh/config" ]]; then
			# Backup existing config
			mv "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d-%H%M%S)"
			log_verbose "Backed up existing SSH config"
		fi

		ln -sf "$DOTFILES_ROOT/.ssh/config" "$HOME/.ssh/config"
		chmod 600 "$HOME/.ssh/config"
		print_success "SSH config linked from dotfiles"
	fi
}

# ============================================================================
# Manual Fallback Symlinking
# ============================================================================

manual_symlink_dotfiles() {
	print_step "Using manual symlinking..."

	local linked=0
	cd "$DOTFILES_ROOT" || return 1

	# Link root-level dotfiles
	for file in .??*; do
		[[ ! -f "$file" && ! -d "$file" ]] && continue
		[[ "$file" =~ ^\.(git|stow-local-ignore)$ ]] && continue

		safe_symlink "$(pwd)/$file" "$HOME/$file"
		((linked++)) || true
	done

	# Link .config directory
	if [[ -d ".config" ]]; then
		mkdir -p "$HOME/.config"
		for dir in .config/*; do
			[[ ! -d "$dir" ]] && continue
			safe_symlink "$(pwd)/$dir" "$HOME/$dir"
			((linked++)) || true
		done
	fi

	print_success "Manually symlinked $linked items"
}

log_verbose "Dotfiles manager module loaded"
