#!/bin/bash

# Setup VS Code debug configuration for a new project
# Usage: setup-debug-config.sh [template-name]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../.config/launch-templates"
PROJECT_DIR="$(pwd)"

# Function to show available templates
show_templates() {
    echo "Available debug templates:"
    for template in "$TEMPLATES_DIR"/*.json; do
        if [[ -f "$template" ]]; then
            basename "$template" .json | sed 's/^/  - /'
        fi
    done
}

# Function to copy template
copy_template() {
    local template_name="$1"
    local template_file="$TEMPLATES_DIR/${template_name}.json"
    local target_dir="$PROJECT_DIR/.vscode"
    local target_file="$target_dir/launch.json"
    
    if [[ ! -f "$template_file" ]]; then
        echo "❌ Template '$template_name' not found!"
        show_templates
        exit 1
    fi
    
    # Create .vscode directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Copy template
    cp "$template_file" "$target_file"
    
    echo "✅ Debug configuration '$template_name' copied to $target_file"
    echo "💡 You can now customize it for your specific project needs!"
}

# Main logic
if [[ $# -eq 0 ]]; then
    echo "🔧 VS Code Debug Configuration Setup"
    echo "Usage: $(basename "$0") <template-name>"
    echo ""
    show_templates
    echo ""
    echo "Example: $(basename "$0") python-basic"
elif [[ "$1" == "--list" ]]; then
    show_templates
else
    copy_template "$1"
fi