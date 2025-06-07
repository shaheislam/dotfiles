#!/bin/bash

# Script to update all Git repositories in a directory
# Usage: ./update-all-repos.sh [directory]

set -e

TARGET_DIR="${1:-$HOME/work}"
FAILED_REPOS=()
UPDATED_REPOS=()
UP_TO_DATE_REPOS=()

echo "🔄 Updating all repositories in: $TARGET_DIR"
echo ""

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Directory $TARGET_DIR does not exist!"
    exit 1
fi

cd "$TARGET_DIR"

# Find all git repositories and update them
for repo_dir in */; do
    if [ -d "$repo_dir/.git" ]; then
        repo_name=${repo_dir%/}
        echo "📂 Processing: $repo_name"

        cd "$repo_dir"

        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "⚠️  $repo_name has uncommitted changes, skipping..."
            FAILED_REPOS+=("$repo_name (uncommitted changes)")
        else
            # Get current branch
            current_branch=$(git branch --show-current)

            # Fetch latest changes
            if git fetch origin >/dev/null 2>&1; then
                # Check if we're behind
                if git status -uno | grep -q "behind"; then
                    if git pull origin "$current_branch" >/dev/null 2>&1; then
                        echo "✅ Updated: $repo_name"
                        UPDATED_REPOS+=("$repo_name")
                    else
                        echo "❌ Failed to update: $repo_name"
                        FAILED_REPOS+=("$repo_name (pull failed)")
                    fi
                else
                    echo "✨ Up to date: $repo_name"
                    UP_TO_DATE_REPOS+=("$repo_name")
                fi
            else
                echo "❌ Failed to fetch: $repo_name"
                FAILED_REPOS+=("$repo_name (fetch failed)")
            fi
        fi

        cd "$TARGET_DIR"
        echo ""
    fi
done

echo "========================================"
echo "📊 Update Summary:"
echo "========================================"
echo "✅ Updated: ${#UPDATED_REPOS[@]} repositories"
echo "✨ Up to date: ${#UP_TO_DATE_REPOS[@]} repositories"
echo "❌ Failed: ${#FAILED_REPOS[@]} repositories"
echo ""

if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
    echo "📝 Updated repositories:"
    for repo in "${UPDATED_REPOS[@]}"; do
        echo "   - $repo"
    done
    echo ""
fi

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
    echo "⚠️  Failed repositories:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "   - $repo"
    done
    echo ""
    echo "💡 For failed repos, you may need to:"
    echo "   - Commit or stash local changes"
    echo "   - Check network connectivity"
    echo "   - Verify SSH key access"
fi

echo "🎉 Update process completed!"
