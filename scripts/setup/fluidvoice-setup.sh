#!/usr/bin/env bash
# Validate and optionally apply dotfiles-managed FluidVoice preferences on macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="${FLUIDVOICE_CONFIG_HELPER:-$SCRIPT_DIR/fluidvoice-config.py}"
CONFIG_SOURCE="${FLUIDVOICE_CONFIG_SOURCE:-$DOTFILES_ROOT/.config/fluidvoice/config.json}"
PREFS_PLIST="${FLUIDVOICE_PREFS_PLIST:-$HOME/Library/Preferences/com.FluidApp.app.plist}"
FLUIDVOICE_APP="${FLUIDVOICE_APP:-/Applications/FluidVoice.app}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

require_python() {
	if ! command -v python3 >/dev/null 2>&1; then
		log_warning "python3 is required for FluidVoice config management"
		return 1
	fi
}

validate_config() {
	require_python || return 1
	python3 "$HELPER" validate --config "$CONFIG_SOURCE"
}

apply_config() {
	require_python || return 1

	if [[ "$(uname -s)" != "Darwin" ]]; then
		log_info "FluidVoice setup is macOS-only; skipping"
		return 0
	fi

	if [[ ! -d "$FLUIDVOICE_APP" ]]; then
		log_warning "FluidVoice.app not found at $FLUIDVOICE_APP; install or open FluidVoice, then rerun setup"
		return 0
	fi

	python3 "$HELPER" apply --config "$CONFIG_SOURCE" --prefs-plist "$PREFS_PLIST"
}

dry_run_apply() {
	require_python || return 1
	python3 "$HELPER" apply --config "$CONFIG_SOURCE" --prefs-plist "$PREFS_PLIST" --dry-run
}

capture_current_prefs() {
	require_python || return 1
	python3 "$HELPER" capture --source-plist "$PREFS_PLIST" --config "$CONFIG_SOURCE" "$@"
}

self_test() {
	require_python || return 1
	python3 "$HELPER" self-test
}

main() {
	case "${1:-}" in
	--self-test)
		self_test
		return 0
		;;
	--capture-current-prefs)
		shift
		capture_current_prefs "$@"
		return 0
		;;
	--apply)
		apply_config
		return 0
		;;
	--dry-run)
		dry_run_apply
		return 0
		;;
	--validate)
		validate_config
		return 0
		;;
	esac

	if [[ ! -f "$CONFIG_SOURCE" ]]; then
		log_warning "FluidVoice config missing: $CONFIG_SOURCE"
		log_info "Seed it with: $0 --capture-current-prefs"
		return 0
	fi

	validate_config || return 1

	if [[ "${DOTFILES_APPLY_FLUIDVOICE:-0}" == "1" ]]; then
		apply_config
	else
		log_info "FluidVoice config is managed in dotfiles but not applied by default"
		log_info "Run with DOTFILES_APPLY_FLUIDVOICE=1 or use: $0 --apply"
		log_success "FluidVoice dotfiles config check complete"
	fi
}

main "$@"
