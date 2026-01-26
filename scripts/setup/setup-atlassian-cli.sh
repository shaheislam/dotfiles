#!/usr/bin/env bash
#
# Setup Atlassian CLI with 1Password integration
# Retrieves Jira API token from 1Password and authenticates acli
#
# Prerequisites:
# - 1Password CLI (op) must be installed and signed in
# - Atlassian CLI (acli) must be installed
# - Jira API token stored in 1Password
#
# 1Password Item Setup:
#   Title: "Jira API Token" (or customize JIRA_1P_ITEM_NAME below)
#   Type: API Credential or Login
#   Fields:
#     - username: your.email@company.com
#     - credential (or password): your-api-token
#     - website: https://yourcompany.atlassian.net
#
# Usage:
#   ./scripts/setup/setup-atlassian-cli.sh
#   ./scripts/setup/setup-atlassian-cli.sh --item "My Jira Token"
#   ./scripts/setup/setup-atlassian-cli.sh --vault "Work"

set -euo pipefail

# Configuration - customize these or pass via flags
JIRA_1P_ITEM_NAME="${JIRA_1P_ITEM_NAME:-Jira API Token}"
JIRA_1P_VAULT="${JIRA_1P_VAULT:-}"  # Empty = search all vaults

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
print_header() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --item)
                JIRA_1P_ITEM_NAME="$2"
                shift 2
                ;;
            --vault)
                JIRA_1P_VAULT="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Setup Atlassian CLI with 1Password integration

Usage: $(basename "$0") [OPTIONS]

Options:
    --item NAME     1Password item name containing Jira credentials
                    (default: "Jira API Token")
    --vault NAME    1Password vault to search in (default: all vaults)
    -h, --help      Show this help message

Environment Variables:
    JIRA_1P_ITEM_NAME   Override default item name
    JIRA_1P_VAULT       Override default vault

1Password Item Setup:
    Create an item in 1Password with these fields:
    - username: your Jira email
    - credential (or password): your Jira API token
    - website: your Jira URL (e.g., https://company.atlassian.net)

Examples:
    $(basename "$0")
    $(basename "$0") --item "Work Jira"
    $(basename "$0") --vault "Work" --item "Jira Credentials"
EOF
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking prerequisites"

    # Check 1Password CLI
    if ! command -v op &>/dev/null; then
        print_error "1Password CLI (op) not installed"
        echo "  Install: brew install --cask 1password-cli"
        return 1
    fi
    print_success "1Password CLI found: $(op --version)"

    # Check if signed in to 1Password
    if ! op account list &>/dev/null; then
        print_error "Not signed in to 1Password"
        echo "  Sign in: eval \$(op signin)"
        return 1
    fi
    print_success "Signed in to 1Password"

    # Check Atlassian CLI
    if ! command -v acli &>/dev/null; then
        print_error "Atlassian CLI (acli) not installed"
        echo "  Install: brew tap atlassian/homebrew-acli && brew install acli"
        return 1
    fi
    print_success "Atlassian CLI found: $(acli --version | head -1)"
}

# Retrieve credentials from 1Password
get_jira_credentials() {
    print_header "Retrieving Jira credentials from 1Password"

    local vault_flag=""
    [[ -n "$JIRA_1P_VAULT" ]] && vault_flag="--vault $JIRA_1P_VAULT"

    # Try to find the item
    local item_json
    # shellcheck disable=SC2086
    item_json=$(op item get "$JIRA_1P_ITEM_NAME" $vault_flag --format json 2>/dev/null) || {
        print_error "Could not find 1Password item: $JIRA_1P_ITEM_NAME"
        echo ""
        echo "Available items with 'jira' in title:"
        # shellcheck disable=SC2086
        op item list $vault_flag --format json 2>/dev/null | \
            jq -r '.[] | select(.title | test("jira"; "i")) | "  - \(.title)"' || true
        echo ""
        echo "Create an item named '$JIRA_1P_ITEM_NAME' with:"
        echo "  - username: your Jira email"
        echo "  - credential: your Jira API token"
        echo "  - website: your Jira URL"
        return 1
    }

    # Extract fields - try multiple common field names
    JIRA_EMAIL=$(echo "$item_json" | jq -r '
        .fields[]? |
        select(.label == "username" or .label == "email" or .id == "username") |
        .value // empty
    ' | head -1)

    # Note: jq extraction from JSON doesn't include revealed values
    # Use direct field retrieval with --reveal for sensitive fields
    local vault_arg=""
    [[ -n "$JIRA_1P_VAULT" ]] && vault_arg="--vault $JIRA_1P_VAULT"

    # shellcheck disable=SC2086
    JIRA_TOKEN=$(op item get "$JIRA_1P_ITEM_NAME" $vault_arg --fields password --reveal 2>/dev/null || \
                 op item get "$JIRA_1P_ITEM_NAME" $vault_arg --fields credential --reveal 2>/dev/null || \
                 echo "")

    JIRA_URL=$(echo "$item_json" | jq -r '
        .fields[]? |
        select(.label == "website" or .label == "url" or .id == "website") |
        .value // empty
    ' | head -1)

    # Fallback: try to get URL from urls array
    if [[ -z "$JIRA_URL" ]]; then
        JIRA_URL=$(echo "$item_json" | jq -r '.urls[0].href // empty')
    fi

    # Validate extracted values
    local missing=()
    [[ -z "$JIRA_EMAIL" ]] && missing+=("username/email")
    [[ -z "$JIRA_TOKEN" ]] && missing+=("credential/password")
    [[ -z "$JIRA_URL" ]] && missing+=("website/url")

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing fields in 1Password item: ${missing[*]}"
        echo ""
        echo "Item fields found:"
        echo "$item_json" | jq -r '.fields[]? | "  - \(.label // .id): \(.value | if . then "****" else "(empty)" end)"'
        return 1
    fi

    # Clean URL - remove trailing slashes and /jira suffix for acli
    JIRA_URL="${JIRA_URL%/}"
    JIRA_URL="${JIRA_URL%/jira}"

    # Extract just the site name for acli
    JIRA_SITE=$(echo "$JIRA_URL" | sed -E 's|https?://||' | sed 's|/.*||')

    print_success "Retrieved credentials for: $JIRA_EMAIL"
    print_success "Jira site: $JIRA_SITE"
}

# Authenticate with Atlassian CLI
authenticate_acli() {
    print_header "Authenticating Atlassian CLI"

    # Check current auth status
    if acli jira auth status 2>/dev/null | grep -q "Logged in"; then
        print_warning "Already authenticated with Jira"
        echo ""
        read -rp "Re-authenticate? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_success "Keeping existing authentication"
            return 0
        fi
    fi

    # Authenticate using the retrieved credentials
    echo "$JIRA_TOKEN" | acli jira auth login \
        --site "$JIRA_SITE" \
        --email "$JIRA_EMAIL" \
        --token

    if acli jira auth status 2>/dev/null | grep -q "Logged in"; then
        print_success "Successfully authenticated with Jira"
    else
        print_error "Authentication failed"
        return 1
    fi
}

# Test the connection
test_connection() {
    print_header "Testing Jira connection"

    # Try to list projects
    if acli jira project list --limit 3 &>/dev/null; then
        print_success "Connection successful"
        echo ""
        echo "Sample projects:"
        acli jira project list --limit 5 2>/dev/null | head -10
    else
        print_warning "Could not list projects (may be permission issue)"
        echo "Try: acli jira issue list --limit 5"
    fi
}

# Show wrapper function for fish shell
show_fish_wrapper() {
    print_header "Fish shell wrapper (optional)"
    echo ""
    echo "Add to ~/.config/fish/functions/jira-auth.fish for easy re-auth:"
    echo ""
    cat << 'EOF'
function jira-auth --description "Authenticate Jira CLI with 1Password"
    set -l token (op item get "Jira API Token" --fields credential 2>/dev/null)
    if test -z "$token"
        echo "Failed to get token from 1Password"
        return 1
    end
    echo $token | acli jira auth login \
        --site "petlab.atlassian.net" \
        --email "shahe.islam@thepetlabco.com" \
        --token
end
EOF
    echo ""
}

# Main
main() {
    parse_args "$@"

    echo ""
    print_header "Atlassian CLI Setup with 1Password"
    echo ""

    check_prerequisites || exit 1
    echo ""

    get_jira_credentials || exit 1
    echo ""

    authenticate_acli || exit 1
    echo ""

    test_connection
    echo ""

    show_fish_wrapper
    echo ""

    print_success "Setup complete!"
    echo ""
    echo "Quick commands:"
    echo "  acli jira issue list              # List your issues"
    echo "  acli jira issue create            # Create issue (interactive)"
    echo "  acli jira issue view PROJ-123     # View issue details"
    echo "  acli jira auth status             # Check auth status"
}

main "$@"
