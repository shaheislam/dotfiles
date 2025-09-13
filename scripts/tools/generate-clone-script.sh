#!/bin/bash

# Script to generate a clone script for all repos in ~/work directory
# Usage: ./generate-clone-script.sh

set -e

WORK_DIR="$HOME/work"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_SCRIPT="$SCRIPT_DIR/clone-all-repos.sh"

echo "🔍 Scanning for Git repositories in $WORK_DIR..."
echo "📝 Generating clone script: $OUTPUT_SCRIPT"

# Start writing the clone script
cat > "$OUTPUT_SCRIPT" << 'EOF'
#!/bin/bash

# Auto-generated script to clone all repositories from ~/work
# Generated on: $(date)
# Usage: ./clone-all-repos.sh [target_directory]

set -e

TARGET_DIR="${1:-$HOME/work}"
FAILED_REPOS=()

echo "🚀 Cloning repositories to: $TARGET_DIR"
echo "📂 Creating target directory if it doesn't exist..."
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo ""
echo "========================================"
echo "Starting repository cloning process..."
echo "========================================"
echo ""

EOF

# Counter for found repos
repo_count=0

# Find all git repositories and extract their remote URLs
for dir in "$WORK_DIR"/*; do
    if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
        repo_name=$(basename "$dir")

        # Get the remote origin URL
        cd "$dir"
        if git remote get-url origin >/dev/null 2>&1; then
            remote_url=$(git remote get-url origin)
            echo "✅ Found: $repo_name -> $remote_url"

            # Add clone command to the script
            cat >> "$OUTPUT_SCRIPT" << EOF

echo "📦 Cloning: $repo_name"
if [ ! -d "$repo_name" ]; then
    if git clone "$remote_url" "$repo_name"; then
        echo "✅ Successfully cloned: $repo_name"
    else
        echo "❌ Failed to clone: $repo_name"
        FAILED_REPOS+=("$repo_name")
    fi
else
    echo "⏭️  Directory $repo_name already exists, skipping..."
fi

EOF
            ((repo_count++))
        else
            echo "⚠️  Skipping $repo_name (no remote origin found)"
        fi
    fi
done

# Add summary section to the clone script
cat >> "$OUTPUT_SCRIPT" << 'EOF'

echo ""
echo "========================================"
echo "Cloning process completed!"
echo "========================================"

if [ ${#FAILED_REPOS[@]} -eq 0 ]; then
    echo "🎉 All repositories cloned successfully!"
else
    echo "⚠️  Some repositories failed to clone:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "   - $repo"
    done
    echo ""
    echo "💡 You may need to:"
    echo "   - Check your SSH keys are set up"
    echo "   - Verify you have access to private repositories"
    echo "   - Check your internet connection"
fi

echo ""
echo "📁 All repositories are in: $TARGET_DIR"
echo "🔧 To update all repos later, you can run:"
echo "   find $TARGET_DIR -type d -name '.git' -exec dirname {} \; | xargs -I {} git -C {} pull"

EOF

# Make the generated script executable
chmod +x "$OUTPUT_SCRIPT"

echo ""
echo "========================================"
echo "📊 Summary:"
echo "   Found: $repo_count Git repositories"
echo "   Generated: $OUTPUT_SCRIPT"
echo "========================================"
echo ""
echo "🚀 To use on another laptop:"
echo "   1. Copy $OUTPUT_SCRIPT to the new laptop"
echo "   2. Run: chmod +x clone-all-repos.sh"
echo "   3. Run: ./clone-all-repos.sh [optional_target_directory]"
echo ""
echo "💡 The script will clone to ~/work by default, or specify a different directory"
EOF
