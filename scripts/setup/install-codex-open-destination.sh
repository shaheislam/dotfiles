#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
	exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFIG_DIR="$DOTFILES_ROOT/.config/codex-open-destination"
CONFIG_FILE="$CONFIG_DIR/config.env"
APPLESCRIPT_TEMPLATE="$CONFIG_DIR/open-destination.applescript.template"
PLIST_TEMPLATE="$CONFIG_DIR/Info.plist.template"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -f "$APPLESCRIPT_TEMPLATE" ]] || [[ ! -f "$PLIST_TEMPLATE" ]]; then
	echo "Codex open-destination files are missing under $CONFIG_DIR" >&2
	exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

IDENTITY_NAME="${CODEX_OPEN_DESTINATION_IDENTITY_NAME:-TextMate}"
BUNDLE_ID="${CODEX_OPEN_DESTINATION_BUNDLE_ID:-com.macromates.TextMate}"
ROUTE_MODE="${CODEX_OPEN_DESTINATION_ROUTE_MODE:-default-handler}"
TARGET_APP="${CODEX_OPEN_DESTINATION_TARGET_APP:-}"
TARGET_COMMAND="${CODEX_OPEN_DESTINATION_TARGET_COMMAND:-}"
APP_PATH="/Applications/${IDENTITY_NAME}.app"

escape_for_perl_substitution() {
	printf '%s' "$1" | sed 's#[/\\&]#\\&#g'
}

escape_for_applescript_string() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

build_open_statement() {
	case "$ROUTE_MODE" in
	default-handler)
		printf '    do shell script "open " & quoted form of POSIX path of aFile'
		;;
	open-app)
		if [[ -z "$TARGET_APP" ]]; then
			echo "CODEX_OPEN_DESTINATION_TARGET_APP is required for ROUTE_MODE=open-app" >&2
			exit 1
		fi
		local escaped_target_app
		escaped_target_app="$(escape_for_applescript_string "$TARGET_APP")"
		printf '    do shell script "open -a " & quoted form of "%s" & " -- " & quoted form of POSIX path of aFile' "$escaped_target_app"
		;;
	shell-command)
		if [[ -z "$TARGET_COMMAND" ]]; then
			echo "CODEX_OPEN_DESTINATION_TARGET_COMMAND is required for ROUTE_MODE=shell-command" >&2
			exit 1
		fi
		local escaped_target_command
		escaped_target_command="$(escape_for_applescript_string "$TARGET_COMMAND")"
		printf '    do shell script "%s " & quoted form of POSIX path of aFile' "$escaped_target_command"
		;;
	*)
		echo "Unsupported CODEX_OPEN_DESTINATION_ROUTE_MODE: $ROUTE_MODE" >&2
		exit 1
		;;
	esac
}

existing_app_is_managed_proxy() {
	local plist="$APP_PATH/Contents/Info.plist"
	[[ -f "$plist" ]] || return 1
	/usr/libexec/PlistBuddy -c 'Print :CodexOpenDestinationProxy' "$plist" 2>/dev/null | grep -qx 'true'
}

if [[ -d "$APP_PATH" ]] && ! existing_app_is_managed_proxy; then
	echo "Refusing to overwrite existing app at $APP_PATH" >&2
	echo "Choose another allowlisted identity in $CONFIG_FILE." >&2
	exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

open_statement="$(build_open_statement)"
escaped_open_statement="$(escape_for_perl_substitution "$open_statement")"
escaped_identity_name="$(escape_for_perl_substitution "$IDENTITY_NAME")"
escaped_bundle_id="$(escape_for_perl_substitution "$BUNDLE_ID")"

script_file="$tmp_dir/open-destination.applescript"
plist_file="$tmp_dir/Info.plist"
tmp_app="$tmp_dir/${IDENTITY_NAME}.app"

perl -0pe "s/__OPEN_STATEMENT__/$escaped_open_statement/g" "$APPLESCRIPT_TEMPLATE" >"$script_file"
osacompile -o "$tmp_app" "$script_file"

perl -0pe "s/__APP_NAME__/$escaped_identity_name/g; s/__BUNDLE_ID__/$escaped_bundle_id/g" "$PLIST_TEMPLATE" >"$plist_file"
plutil -lint "$plist_file" >/dev/null
cp "$plist_file" "$tmp_app/Contents/Info.plist"

xattr -cr "$tmp_app" 2>/dev/null || true
codesign --force --deep --sign - "$tmp_app" >/dev/null 2>&1 || true

if [[ -d "$APP_PATH" ]]; then
	rm -rf "$APP_PATH"
fi

mv "$tmp_app" /Applications/

if [[ -x "$LSREGISTER" ]]; then
	"$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
fi

echo "Installed Codex open destination proxy: $APP_PATH"
echo "Route mode: $ROUTE_MODE"
