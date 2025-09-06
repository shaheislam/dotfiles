#!/usr/bin/env bash
# Setup script for direnv + 1Password integration

set -e

echo "Setting up direnv + 1Password integration..."

# Check if direnv is installed
if ! command -v direnv >/dev/null 2>&1; then
    echo "Installing direnv..."
    brew install direnv
fi

# Check if 1Password CLI is installed
if ! command -v op >/dev/null 2>&1; then
    echo "Installing 1Password CLI..."
    brew install 1password-cli
fi

# Create direnv config directory if it doesn't exist
mkdir -p ~/.config/direnv

# Check if direnv is hooked into fish
if ! grep -q "direnv hook fish" ~/.config/fish/config.fish 2>/dev/null; then
    echo "Adding direnv hook to fish config..."
    cat >> ~/.config/fish/config.fish << 'EOF'

# direnv integration
if command -v direnv >/dev/null
    direnv hook fish | source
    set -g direnv_fish_mode eval_on_arrow
end
EOF
fi

# Test 1Password authentication
echo ""
echo "Testing 1Password CLI authentication..."
if op account get >/dev/null 2>&1; then
    echo "✓ 1Password CLI is authenticated"
else
    echo "⚠️  1Password CLI is not authenticated"
    echo "Run: eval \$(op signin)"
    echo "Or in Fish: op-auth"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Usage examples:"
echo "1. Copy .envrc.example to your project directory"
echo "2. Customize it with your 1Password references"
echo "3. Run: direnv allow"
echo ""
echo "Example .envrc entries:"
echo '  op_load "Personal/Linear/api_key" "LINEAR_API_KEY"'
echo '  op_load "Personal/GitHub/token" "GITHUB_TOKEN"'
echo ""
echo "For more examples, see:"
echo "  ~/dotfiles/.envrc.example"
echo "  ~/dotfiles/work/.envrc.example"