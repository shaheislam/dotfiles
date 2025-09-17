#!/bin/bash
# Test script for kubectl.nvim

echo "Testing kubectl.nvim setup..."
echo ""

# Check kubectl
echo "✓ kubectl installed: $(which kubectl)"
echo "✓ kubectl version: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
echo ""

# Check current context
echo "✓ Current context: $(kubectl config current-context)"
echo ""

# Check pods
echo "✓ Pods in cluster:"
kubectl get pods --no-headers | awk '{print "  - " $1 " (" $3 ")"}'
echo ""

# Check Neovim
echo "✓ Neovim version:"
nvim --version | head -1
echo ""

# Instructions
echo "================================"
echo "To test kubectl.nvim in Neovim:"
echo "================================"
echo ""
echo "1. Open Neovim: nvim"
echo "2. Run: :Lazy sync"
echo "3. Restart Neovim"
echo "4. Try: :Kubectl or press <leader>k"
echo ""
echo "If still having issues, try:"
echo "  :Lazy update kubectl.nvim"
echo "  :Lazy update blink.download"
echo "  :Lazy update plenary.nvim"
echo ""
echo "Or manually test with:"
echo "  :lua require('kubectl').toggle()"