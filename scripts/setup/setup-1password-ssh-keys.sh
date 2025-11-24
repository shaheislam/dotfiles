#!/usr/bin/env bash
#
# Setup SSH keys from 1Password
# Retrieves SSH keys stored in 1Password and configures them for use
#
# Prerequisites:
# - 1Password CLI (op) must be installed
# - User must be signed in to 1Password
#
# Usage:
#   ./scripts/setup/setup-1password-ssh-keys.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
print_header() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if 1Password CLI is installed
check_op_cli() {
    if ! command -v op &>/dev/null; then
        print_error "1Password CLI (op) is not installed"
        echo ""
        echo "Install it with:"
        echo "  brew install --cask 1password-cli"
        echo ""
        echo "Or download from: https://1password.com/downloads/command-line/"
        return 1
    fi
    print_success "1Password CLI found: $(op --version)"
}

# Check if user is signed in to 1Password
check_op_signin() {
    if ! op account list &>/dev/null; then
        print_error "Not signed in to 1Password"
        echo ""
        echo "Sign in with:"
        echo "  eval \$(op signin)"
        echo ""
        return 1
    fi
    print_success "Signed in to 1Password"
}

# List available SSH keys in 1Password
list_ssh_keys() {
    print_header "Available SSH keys in 1Password:"

    # List items with SSH Key category
    local keys
    keys=$(op item list --categories "SSH Key" --format json 2>/dev/null || echo "[]")

    if [[ "$keys" == "[]" ]]; then
        print_warning "No SSH keys found with category 'SSH Key'"
        echo ""
        echo "Searching for items with 'ssh' or 'github' in title..."
        keys=$(op item list --format json 2>/dev/null | jq -r '.[] | select(.title | test("ssh|github|bitbucket"; "i")) | "\(.id)\t\(.title)"')
    else
        keys=$(echo "$keys" | jq -r '.[] | "\(.id)\t\(.title)"')
    fi

    if [[ -z "$keys" ]]; then
        print_error "No SSH keys found in 1Password"
        return 1
    fi

    echo "$keys" | while IFS=$'\t' read -r id title; do
        echo "  - $title (ID: $id)"
    done

    echo ""
}

# Retrieve SSH key from 1Password
retrieve_ssh_key() {
    local key_name="$1"
    local output_path="$2"

    print_header "Retrieving SSH key: $key_name"

    # Try to find the key by title
    local key_id
    key_id=$(op item list --format json 2>/dev/null | \
        jq -r ".[] | select(.title == \"$key_name\") | .id" | head -1)

    if [[ -z "$key_id" ]]; then
        print_error "SSH key '$key_name' not found in 1Password"
        return 1
    fi

    # Get the private key
    local private_key
    private_key=$(op item get "$key_id" --fields "private key" 2>/dev/null || \
                  op item get "$key_id" --fields "key" 2>/dev/null || \
                  op item get "$key_id" --format json | jq -r '.fields[] | select(.label == "private key" or .label == "key") | .value')

    if [[ -z "$private_key" ]]; then
        print_error "Could not retrieve private key from 1Password item"
        return 1
    fi

    # Save private key
    echo "$private_key" > "$output_path"
    chmod 600 "$output_path"
    print_success "Private key saved: $output_path"

    # Try to get public key
    local public_key
    public_key=$(op item get "$key_id" --fields "public key" 2>/dev/null || \
                 op item get "$key_id" --format json | jq -r '.fields[] | select(.label == "public key") | .value' || \
                 echo "")

    if [[ -n "$public_key" ]]; then
        echo "$public_key" > "${output_path}.pub"
        chmod 644 "${output_path}.pub"
        print_success "Public key saved: ${output_path}.pub"
    else
        print_warning "No public key found (can be generated from private key if needed)"
    fi
}

# Add SSH key to ssh-agent
add_to_ssh_agent() {
    local key_path="$1"

    print_header "Adding key to ssh-agent"

    # Start ssh-agent if not running
    if ! pgrep -u "$USER" ssh-agent &>/dev/null; then
        eval "$(ssh-agent -s)" &>/dev/null
    fi

    # Add key to agent
    if ssh-add "$key_path" 2>/dev/null; then
        print_success "Key added to ssh-agent"
    else
        print_warning "Failed to add key to ssh-agent (may require passphrase)"
        echo "  Run manually: ssh-add $key_path"
    fi

    # On macOS, add to keychain
    if [[ "$(uname)" == "Darwin" ]]; then
        if ssh-add --apple-use-keychain "$key_path" 2>/dev/null; then
            print_success "Key added to macOS Keychain"
        else
            print_warning "Could not add to macOS Keychain (passphrase may be required)"
        fi
    fi
}

# Main setup function
main() {
    print_header "Setting up SSH keys from 1Password"
    echo ""

    # Check prerequisites
    check_op_cli || exit 1
    check_op_signin || exit 1
    echo ""

    # Ensure ~/.ssh directory exists
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # List available keys
    list_ssh_keys || exit 1

    # Configure known SSH keys
    # GitHub Personal Key
    if retrieve_ssh_key "GitHub SSH Key" "$HOME/.ssh/shaheislam-github" 2>/dev/null || \
       retrieve_ssh_key "github" "$HOME/.ssh/shaheislam-github" 2>/dev/null || \
       retrieve_ssh_key "shaheislam-github" "$HOME/.ssh/shaheislam-github" 2>/dev/null; then
        add_to_ssh_agent "$HOME/.ssh/shaheislam-github"
        echo ""
    else
        print_warning "GitHub SSH key not configured automatically"
        echo "  Update script with correct key name from list above"
        echo ""
    fi

    # Bitbucket Key
    if retrieve_ssh_key "Bitbucket SSH Key" "$HOME/.ssh/bitbucket" 2>/dev/null || \
       retrieve_ssh_key "bitbucket" "$HOME/.ssh/bitbucket" 2>/dev/null; then
        add_to_ssh_agent "$HOME/.ssh/bitbucket"
        echo ""
    else
        print_warning "Bitbucket SSH key not found (skipping)"
        echo ""
    fi

    # Test SSH connections
    print_header "Testing SSH connections"

    echo -n "  GitHub: "
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "Connected"
    else
        print_warning "Not connected (check key permissions and GitHub settings)"
    fi

    echo ""
    print_success "SSH key setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify keys are loaded: ssh-add -l"
    echo "  2. Test GitHub: ssh -T git@github.com"
    echo "  3. Clone repositories with git@github.com URLs"
}

# Run main function
main "$@"
