#!/usr/bin/env bash

# app-audit.sh - Brewfile-driven macOS app detection and reporting helpers

brewfile_casks() {
    local brewfile=$1
    local line
    local cask_regex='^[[:space:]]*cask[[:space:]]+"([^"]+)"'

    [[ -f "$brewfile" ]] || return 0

    while IFS= read -r line; do
        if [[ "$line" =~ $cask_regex ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        fi
    done <"$brewfile"
}

brewfile_mas_apps() {
    local brewfile=$1
    local line
    local mas_regex='^[[:space:]]*mas[[:space:]]+"([^"]+)".*id:[[:space:]]*([0-9]+)'

    [[ -f "$brewfile" ]] || return 0

    while IFS= read -r line; do
        if [[ "$line" =~ $mas_regex ]]; then
            printf '%s\t%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
        fi
    done <"$brewfile"
}

brewfile_cask_token() {
    local cask=$1
    printf '%s\n' "${cask##*/}"
}

brewfile_is_font_cask() {
    local cask token
    cask=$1
    token=$(brewfile_cask_token "$cask")

    [[ "$token" == font-* ]]
}

brewfile_gui_casks() {
    local brewfile=$1
    local cask

    while IFS= read -r cask; do
        brewfile_is_font_cask "$cask" && continue
        printf '%s\n' "$cask"
    done < <(brewfile_casks "$brewfile")
}

brewfile_cask_installed() {
    local cask token
    cask=$1
    token=$(brewfile_cask_token "$cask")

    command -v brew >/dev/null 2>&1 || return 1
    brew list --cask "$token" >/dev/null 2>&1
}

brewfile_mas_installed() {
    local app_id=$1
    local line

    command -v mas >/dev/null 2>&1 || return 1
    while IFS= read -r line; do
        [[ "$line" == "$app_id "* ]] && return 0
    done < <(mas list 2>/dev/null)

    return 1
}

dankmono_installed() {
    command -v fc-list >/dev/null 2>&1 || return 1
    fc-list 2>/dev/null | grep -qi "DankMono"
}

print_missing_apps_report() {
    local brewfile=${1:-"$DOTFILES_ROOT/homebrew/Brewfile"}
    local missing=0
    local cask app_id app_name

    [[ "${DETECTED_OS:-$(detect_os)}" == "macos" ]] || return 0

    print_header "macOS App Audit"

    if [[ ! -f "$brewfile" ]]; then
        print_warning "Brewfile not found: $brewfile"
        return 0
    fi

    while IFS= read -r cask; do
        [[ -n "$cask" ]] || continue
        if ! brewfile_cask_installed "$cask"; then
            print_warning "Missing Brew cask: $cask"
            echo "  Install: brew install --cask $cask"
            missing=$((missing + 1))
        fi
    done < <(brewfile_casks "$brewfile")

    while IFS=$'\t' read -r app_id app_name; do
        [[ -n "${app_id:-}" ]] || continue
        if ! brewfile_mas_installed "$app_id"; then
            print_warning "Missing Mac App Store app: $app_name ($app_id)"
            echo "  Install: mas install $app_id"
            missing=$((missing + 1))
        fi
    done < <(brewfile_mas_apps "$brewfile")

    if ! dankmono_installed; then
        print_warning "Missing manual font: DankMono Nerd Font"
        echo "  Download: https://github.com/saifulapm/my-fonts"
        echo "  Then: cp /tmp/my-fonts/DankMono\\ Nerd\\ Font/*.otf ~/Library/Fonts/"
        missing=$((missing + 1))
    fi

    if [[ ! -d "/Applications/CopyQ.app" ]]; then
        print_warning "Missing manual app: CopyQ"
        echo "  Install: bash $DOTFILES_ROOT/scripts/setup/setup-copyq.sh"
        missing=$((missing + 1))
    fi

    if [[ ! -d "/Applications/ClaudeUsage.app" ]]; then
        print_warning "Missing manual app: ClaudeUsage"
        echo "  Install: rerun setup Phase 9 or download from https://github.com/linuxlewis/claude-usage/releases"
        missing=$((missing + 1))
    fi

    if [[ $missing -eq 0 ]]; then
        print_success "All declared and manual macOS apps are present"
    else
        echo ""
        echo "Missing app summary: $missing item(s) need attention"
    fi

    return 0
}
