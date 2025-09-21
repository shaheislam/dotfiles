#!/bin/bash

# K9s Plugin Dependencies Installation Script
# This script installs optional dependencies for K9s plugins

echo "🚀 Installing K9s Plugin Dependencies..."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

echo "📦 Installing missing tools via Homebrew..."

# Install watch (for resource watching)
if ! command -v watch &> /dev/null; then
    echo "Installing watch..."
    brew install watch
else
    echo "✅ watch already installed"
fi

# Install istioctl (for Istio service mesh)
if ! command -v istioctl &> /dev/null; then
    echo "Installing istioctl..."
    brew install istioctl
else
    echo "✅ istioctl already installed"
fi

# Install kubectl-argo-rollouts plugin
if ! command -v kubectl-argo-rollouts &> /dev/null; then
    echo "Installing kubectl-argo-rollouts..."
    brew install argoproj/tap/kubectl-argo-rollouts
else
    echo "✅ kubectl-argo-rollouts already installed"
fi

# Install bunyan (Node.js tool for log formatting)
if ! command -v bunyan &> /dev/null; then
    echo "Installing bunyan via npm..."
    if command -v npm &> /dev/null; then
        npm install -g bunyan
    else
        echo "⚠️  npm not found. Install Node.js to get bunyan log formatting."
    fi
else
    echo "✅ bunyan already installed"
fi

# Install helm-diff plugin
if ! helm plugin list | grep -q diff; then
    echo "Installing helm-diff plugin..."
    helm plugin install https://github.com/databus23/helm-diff
else
    echo "✅ helm-diff plugin already installed"
fi

# Install kubectl-node-shell plugin (for node shell access)
if ! command -v kubectl-node-shell &> /dev/null; then
    echo "Installing kubectl-node-shell..."
    curl -LO https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell
    chmod +x ./kubectl-node_shell
    sudo mv ./kubectl-node_shell /usr/local/bin/kubectl-node-shell
else
    echo "✅ kubectl-node-shell already installed"
fi

echo ""
echo "✅ K9s plugin dependencies installation complete!"
echo ""
echo "📋 Summary:"
echo "  • watch - Resource monitoring"
echo "  • istioctl - Istio service mesh management"
echo "  • kubectl-argo-rollouts - Progressive delivery"
echo "  • bunyan - JSON log formatting"
echo "  • helm-diff - Helm release diffs"
echo "  • kubectl-node-shell - Node debugging"
echo ""
echo "🎯 Your K9s plugins are now fully operational!"