#!/usr/bin/env bash
# Apply dotfiles-managed Firefox policy and default-profile preferences on macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREFOX_APP="${FIREFOX_APP:-/Applications/Firefox.app}"
FIREFOX_ROOT="${FIREFOX_ROOT:-$HOME/Library/Application Support/Firefox}"
POLICY_SOURCE="${FIREFOX_POLICY_SOURCE:-$SCRIPT_DIR/firefox/policies.json}"
USER_JS_SOURCE="${FIREFOX_USER_JS_SOURCE:-$SCRIPT_DIR/firefox/user.js}"
USER_CHROME_SOURCE="${FIREFOX_USER_CHROME_SOURCE:-$SCRIPT_DIR/firefox/chrome/userChrome.css}"
USER_CONTENT_SOURCE="${FIREFOX_USER_CONTENT_SOURCE:-$SCRIPT_DIR/firefox/chrome/userContent.css}"
CAPTURE_PREFS_HELPER="$SCRIPT_DIR/firefox-capture-prefs.py"

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

backup_existing_file() {
    local target_path="$1"
    local backup_path=""

    backup_path="${target_path}.backup.$(date +%Y%m%d-%H%M%S)"

    if cp "$target_path" "$backup_path"; then
        log_info "Backed up existing $(basename "$target_path") to $backup_path"
        return 0
    fi

    log_warning "Could not back up existing $(basename "$target_path")"
    return 1
}

copy_managed_file() {
    local source_path="$1"
    local target_path="$2"
    local label="$3"

    if [[ ! -f "$source_path" ]]; then
        log_warning "$label source missing: $source_path"
        return 0
    fi

    if [[ -f "$target_path" ]] && cmp -s "$source_path" "$target_path"; then
        log_success "$label already current"
        return 0
    fi

    if [[ -e "$target_path" && ! -f "$target_path" && ! -L "$target_path" ]]; then
        log_warning "$label target exists but is not a file: $target_path"
        return 1
    fi

    if ! mkdir -p "$(dirname "$target_path")" 2>/dev/null; then
        log_warning "Could not create $(dirname "$target_path")"
        return 1
    fi

    if [[ -f "$target_path" || -L "$target_path" ]]; then
        if ! backup_existing_file "$target_path"; then
            return 1
        fi

        if ! rm -f "$target_path"; then
            log_warning "Could not replace existing $label at $target_path"
            return 1
        fi
    fi

    if cp "$source_path" "$target_path"; then
        chmod 0644 "$target_path" 2>/dev/null || true
        log_success "Installed $label"
        return 0
    fi

    log_warning "Could not install $label to $target_path"
    return 1
}

resolve_profile_path() {
    local profile_ref="$1"

    if [[ "$profile_ref" == /* ]]; then
        printf '%s\n' "$profile_ref"
    else
        printf '%s/%s\n' "$FIREFOX_ROOT" "$profile_ref"
    fi
}

find_default_profile() {
    local profiles_ini="$FIREFOX_ROOT/profiles.ini"
    local section=""
    local path=""
    local is_relative="1"
    local is_default="0"
    local install_default=""
    local profile_default=""
    local profile_default_relative="1"
    local first_profile=""
    local first_profile_relative="1"

    [[ -f "$profiles_ini" ]] || return 1

    commit_profile_section() {
        if [[ "$section" != Profile* || -z "$path" ]]; then
            return 0
        fi

        if [[ -z "$first_profile" ]]; then
            first_profile="$path"
            first_profile_relative="$is_relative"
        fi

        if [[ "$is_default" == "1" ]]; then
            profile_default="$path"
            profile_default_relative="$is_relative"
        fi
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"

        case "$line" in
        '' | \#* | \;*)
            continue
            ;;
        \[*\])
            commit_profile_section
            section="${line#[}"
            section="${section%]}"
            path=""
            is_relative="1"
            is_default="0"
            continue
            ;;
        esac

        case "$section" in
        Install*)
            case "$line" in
            Default=*) install_default="${line#Default=}" ;;
            esac
            ;;
        Profile*)
            case "$line" in
            Path=*) path="${line#Path=}" ;;
            IsRelative=*) is_relative="${line#IsRelative=}" ;;
            Default=1) is_default="1" ;;
            esac
            ;;
        esac
    done <"$profiles_ini"

    commit_profile_section

    if [[ -n "$install_default" ]]; then
        resolve_profile_path "$install_default"
        return 0
    fi

    if [[ -n "$profile_default" ]]; then
        if [[ "$profile_default_relative" == "1" ]]; then
            resolve_profile_path "$profile_default"
        else
            printf '%s\n' "$profile_default"
        fi
        return 0
    fi

    if [[ -n "$first_profile" ]]; then
        if [[ "$first_profile_relative" == "1" ]]; then
            resolve_profile_path "$first_profile"
        else
            printf '%s\n' "$first_profile"
        fi
        return 0
    fi

    return 1
}

install_policy() {
    local policy_target="$FIREFOX_APP/Contents/Resources/distribution/policies.json"

    if [[ ! -d "$FIREFOX_APP" ]]; then
        log_warning "Firefox.app not found at $FIREFOX_APP; skipping enterprise policy"
        return 0
    fi

    if copy_managed_file "$POLICY_SOURCE" "$policy_target" "Firefox policies.json"; then
        return 0
    fi

    log_warning "Manual policy install: sudo mkdir -p \"$(dirname "$policy_target")\" && sudo cp \"$POLICY_SOURCE\" \"$policy_target\""
    return 1
}

install_user_js() {
    local profile_path=""

    if ! profile_path="$(find_default_profile)"; then
        log_warning "No Firefox profile found; run Firefox once, then rerun setup to install user.js"
        return 0
    fi

    if [[ ! -d "$profile_path" ]]; then
        log_warning "Default Firefox profile directory does not exist: $profile_path"
        return 0
    fi

    copy_managed_file "$USER_JS_SOURCE" "$profile_path/user.js" "Firefox default-profile user.js"
}

install_user_chrome() {
    local profile_path=""

    if ! profile_path="$(find_default_profile)"; then
        log_warning "No Firefox profile found; run Firefox once, then rerun setup to install userChrome.css"
        return 0
    fi

    if [[ ! -d "$profile_path" ]]; then
        log_warning "Default Firefox profile directory does not exist: $profile_path"
        return 0
    fi

    copy_managed_file "$USER_CHROME_SOURCE" "$profile_path/chrome/userChrome.css" "Firefox Sidebery userChrome.css"
}

install_user_content() {
    local profile_path=""

    if ! profile_path="$(find_default_profile)"; then
        log_warning "No Firefox profile found; run Firefox once, then rerun setup to install userContent.css"
        return 0
    fi

    if [[ ! -d "$profile_path" ]]; then
        log_warning "Default Firefox profile directory does not exist: $profile_path"
        return 0
    fi

    copy_managed_file "$USER_CONTENT_SOURCE" "$profile_path/chrome/userContent.css" "Firefox minimal userContent.css"
}

capture_current_prefs() {
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "python3 is required to capture Firefox prefs"
        return 1
    fi

    python3 "$CAPTURE_PREFS_HELPER" --firefox-root "$FIREFOX_ROOT" --user-js "$USER_JS_SOURCE" "$@"
}

self_test() {
    local tmp_dir=""
    local profile_dir=""
    local old_firefox_app=""
    local old_firefox_root=""
    local result=0

    old_firefox_app="$FIREFOX_APP"
    old_firefox_root="$FIREFOX_ROOT"

    tmp_dir="$(mktemp -d)"
    profile_dir="$tmp_dir/Firefox/Profiles/test.default"

    mkdir -p "$profile_dir" "$tmp_dir/Firefox.app"
    printf '%s\n' \
        '[Install1234567890]' \
        'Default=Profiles/test.default' \
        '[Profile0]' \
        'Name=default' \
        'IsRelative=1' \
        'Path=Profiles/test.default' \
        'Default=1' >"$tmp_dir/Firefox/profiles.ini"

    FIREFOX_APP="$tmp_dir/Firefox.app"
    FIREFOX_ROOT="$tmp_dir/Firefox"

    install_policy >/dev/null
    install_user_js >/dev/null
    install_user_chrome >/dev/null
    install_user_content >/dev/null
    install_policy >/dev/null
    install_user_js >/dev/null
    install_user_chrome >/dev/null
    install_user_content >/dev/null

    [[ -f "$FIREFOX_APP/Contents/Resources/distribution/policies.json" ]] || result=1
    [[ -f "$profile_dir/user.js" ]] || result=1
    [[ -f "$profile_dir/chrome/userChrome.css" ]] || result=1
    [[ -f "$profile_dir/chrome/userContent.css" ]] || result=1
    compgen -G "$profile_dir/user.js.backup.*" >/dev/null && result=1
    compgen -G "$profile_dir/chrome/userChrome.css.backup.*" >/dev/null && result=1
    compgen -G "$profile_dir/chrome/userContent.css.backup.*" >/dev/null && result=1

    FIREFOX_APP="$old_firefox_app"
    FIREFOX_ROOT="$old_firefox_root"
    rm -rf "$tmp_dir"

    return "$result"
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
    esac

    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_info "Firefox setup is macOS-only; skipping"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -m json.tool "$POLICY_SOURCE" >/dev/null; then
            log_warning "Firefox policy JSON is invalid: $POLICY_SOURCE"
            return 1
        fi
    fi

    local had_warnings=false

    install_policy || had_warnings=true
    install_user_js || had_warnings=true
    install_user_chrome || had_warnings=true
    install_user_content || had_warnings=true

    if [[ "$had_warnings" == "true" ]]; then
        log_warning "Firefox dotfiles setup completed with warnings"
    else
        log_success "Firefox dotfiles setup complete"
    fi
}

main "$@"
