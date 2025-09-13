#!/bin/bash

# Auto-generated script to clone all repositories from ~/work
# Generated on: $(date)
# Usage: ./clone-all-repos.sh [target_directory] [--debug]

# Check for debug flag
DEBUG=false
for arg in "$@"; do
    if [ "$arg" = "--debug" ] || [ "$arg" = "-d" ]; then
        DEBUG=true
    fi
done

# Set error handling based on debug mode
if [ "$DEBUG" = true ]; then
    set -ex # Exit on error and print commands
    echo "🐛 Debug mode enabled"
else
    set -e # Just exit on error
fi

# Parse target directory (skip debug flags)
TARGET_DIR=""
for arg in "$@"; do
    if [ "$arg" != "--debug" ] && [ "$arg" != "-d" ]; then
        TARGET_DIR="$arg"
        break
    fi
done
TARGET_DIR="${TARGET_DIR:-$HOME/work}"

FAILED_REPOS=()

# Debug function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "🔍 DEBUG: $1"
    fi
}

# Clone repository function with debug support
clone_repo() {
    local repo_name="$1"
    local git_url="$2"

    echo "📦 Cloning: $repo_name"
    debug_log "Checking if directory exists: $repo_name"

    if [ ! -d "$repo_name" ]; then
        debug_log "Directory doesn't exist, proceeding with clone"
        debug_log "Clone command: git clone $git_url $repo_name"
        debug_log "SSH key check: ssh-add -l | grep -q 'ED25519' && echo 'SSH key loaded' || echo 'No SSH key'"

        if [ "$DEBUG" = true ]; then
            # In debug mode, show more detailed git output
            if GIT_SSH_COMMAND="ssh -v" git clone "$git_url" "$repo_name" 2>&1 | tee /tmp/git-clone-debug.log; then
                echo "✅ Successfully cloned: $repo_name"
                debug_log "Clone successful"
            else
                local exit_code=$?
                echo "❌ Failed to clone: $repo_name"
                debug_log "Clone failed with exit code: $exit_code"
                debug_log "Check /tmp/git-clone-debug.log for details"
                FAILED_REPOS+=("$repo_name")
            fi
        else
            if git clone "$git_url" "$repo_name"; then
                echo "✅ Successfully cloned: $repo_name"
            else
                echo "❌ Failed to clone: $repo_name"
                FAILED_REPOS+=("$repo_name")
            fi
        fi
    else
        echo "⏭️  Directory $repo_name already exists, skipping..."
        debug_log "Directory already exists, skipping clone"
    fi

    echo "" # Add spacing between repos
}

echo "🚀 Cloning repositories to: $TARGET_DIR"
debug_log "Target directory: $TARGET_DIR"
debug_log "Current directory: $(pwd)"

echo "📂 Creating target directory if it doesn't exist..."
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
debug_log "Changed to directory: $(pwd)"

echo ""
echo "========================================"
echo "Starting repository cloning process..."
echo "========================================"
echo ""

# Clone all repositories using the new function
clone_repo "access-your-teaching-qualifications" "git@github.com:DFE-Digital/access-your-teaching-qualifications.git"
clone_repo "apply-for-qualified-teacher-status" "git@github.com:DFE-Digital/apply-for-qualified-teacher-status.git"

clone_repo "apply-for-teacher-training" "git@github.com:DFE-Digital/apply-for-teacher-training.git"

clone_repo "bat-infrastructure" "git@github.com:DFE-Digital/bat-infrastructure.git"

clone_repo "check-childrens-barred-list" "git@github.com:DFE-Digital/check-childrens-barred-list.git"

clone_repo "claim-additional-payments-for-teaching" "git@github.com:DFE-Digital/claim-additional-payments-for-teaching.git"

clone_repo "early-careers-framework" "git@github.com:DFE-Digital/early-careers-framework.git"

clone_repo "find-a-lost-trn" "git@github.com:DFE-Digital/find-a-lost-trn.git"

clone_repo "get-a-teacher-relocation-payment" "git@github.com:DFE-Digital/get-a-teacher-relocation-payment.git"

clone_repo "get-an-identity" "git@github.com:DFE-Digital/get-an-identity.git"

clone_repo "get-into-teaching-api" "git@github.com:DFE-Digital/get-into-teaching-api.git"

clone_repo "get-into-teaching-app" "git@github.com:DFE-Digital/get-into-teaching-app.git"

clone_repo "github-actions" "git@github.com:DFE-Digital/github-actions.git"

clone_repo "itt-mentor-services" "git@github.com:DFE-Digital/itt-mentor-services.git"

clone_repo "national-professional-qualification" "git@github.com:DFE-Digital/national-professional-qualification.git"

clone_repo "npq-registration" "https://github.com/DFE-Digital/npq-registration"

clone_repo "publish-teacher-training" "git@github.com:DFE-Digital/publish-teacher-training.git"

clone_repo "register-early-career-teachers-public" "git@github.com:DFE-Digital/register-early-career-teachers-public.git"

clone_repo "register-trainee-teachers" "git@github.com:DFE-Digital/register-trainee-teachers.git"

clone_repo "schools-experience" "git@github.com:DFE-Digital/schools-experience.git"

clone_repo "teacher-pay-calculator" "git@github.com:DFE-Digital/teacher-pay-calculator.git"

clone_repo "teacher-services-cloud" "git@github.com:DFE-Digital/teacher-services-cloud.git"

echo "📦 Cloning: teacher-services-tech-docs"
if [ ! -d "teacher-services-tech-docs" ]; then
    if git clone "git@github.com:DFE-Digital/teacher-services-tech-docs.git" "teacher-services-tech-docs"; then
        echo "✅ Successfully cloned: teacher-services-tech-docs"
    else
        echo "❌ Failed to clone: teacher-services-tech-docs"
        FAILED_REPOS+=("teacher-services-tech-docs")
    fi
else
    echo "⏭️  Directory teacher-services-tech-docs already exists, skipping..."
fi

echo "📦 Cloning: teaching-record-system"
if [ ! -d "teaching-record-system" ]; then
    if git clone "git@github.com:DFE-Digital/teaching-record-system.git" "teaching-record-system"; then
        echo "✅ Successfully cloned: teaching-record-system"
    else
        echo "❌ Failed to clone: teaching-record-system"
        FAILED_REPOS+=("teaching-record-system")
    fi
else
    echo "⏭️  Directory teaching-record-system already exists, skipping..."
fi

echo "📦 Cloning: teaching-school-hub-finder"
if [ ! -d "teaching-school-hub-finder" ]; then
    if git clone "git@github.com:DFE-Digital/teaching-school-hub-finder.git" "teaching-school-hub-finder"; then
        echo "✅ Successfully cloned: teaching-school-hub-finder"
    else
        echo "❌ Failed to clone: teaching-school-hub-finder"
        FAILED_REPOS+=("teaching-school-hub-finder")
    fi
else
    echo "⏭️  Directory teaching-school-hub-finder already exists, skipping..."
fi

echo "📦 Cloning: teaching-vacancies"
if [ ! -d "teaching-vacancies" ]; then
    if git clone "git@github.com:DFE-Digital/teaching-vacancies.git" "teaching-vacancies"; then
        echo "✅ Successfully cloned: teaching-vacancies"
    else
        echo "❌ Failed to clone: teaching-vacancies"
        FAILED_REPOS+=("teaching-vacancies")
    fi
else
    echo "⏭️  Directory teaching-vacancies already exists, skipping..."
fi

echo "📦 Cloning: technical-guidance"
if [ ! -d "technical-guidance" ]; then
    if git clone "git@github.com:DFE-Digital/technical-guidance.git" "technical-guidance"; then
        echo "✅ Successfully cloned: technical-guidance"
    else
        echo "❌ Failed to clone: technical-guidance"
        FAILED_REPOS+=("technical-guidance")
    fi
else
    echo "⏭️  Directory technical-guidance already exists, skipping..."
fi

echo "📦 Cloning: terraform-modules"
if [ ! -d "terraform-modules" ]; then
    if git clone "git@github.com:DFE-Digital/terraform-modules.git" "terraform-modules"; then
        echo "✅ Successfully cloned: terraform-modules"
    else
        echo "❌ Failed to clone: terraform-modules"
        FAILED_REPOS+=("terraform-modules")
    fi
else
    echo "⏭️  Directory terraform-modules already exists, skipping..."
fi

echo "📦 Cloning: tra-shared-services"
if [ ! -d "tra-shared-services" ]; then
    if git clone "git@github.com:DFE-Digital/tra-shared-services.git" "tra-shared-services"; then
        echo "✅ Successfully cloned: tra-shared-services"
    else
        echo "❌ Failed to clone: tra-shared-services"
        FAILED_REPOS+=("tra-shared-services")
    fi
else
    echo "⏭️  Directory tra-shared-services already exists, skipping..."
fi

echo "📦 Cloning: tra-trn-generation-api"
if [ ! -d "tra-trn-generation-api" ]; then
    if git clone "git@github.com:DFE-Digital/tra-trn-generation-api.git" "tra-trn-generation-api"; then
        echo "✅ Successfully cloned: tra-trn-generation-api"
    else
        echo "❌ Failed to clone: tra-trn-generation-api"
        FAILED_REPOS+=("tra-trn-generation-api")
    fi
else
    echo "⏭️  Directory tra-trn-generation-api already exists, skipping..."
fi

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
