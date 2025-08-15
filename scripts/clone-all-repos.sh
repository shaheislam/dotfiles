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


echo "📦 Cloning: access-your-teaching-qualifications"
if [ ! -d "access-your-teaching-qualifications" ]; then
    if git clone "git@github.com:DFE-Digital/access-your-teaching-qualifications.git" "access-your-teaching-qualifications"; then
        echo "✅ Successfully cloned: access-your-teaching-qualifications"
    else
        echo "❌ Failed to clone: access-your-teaching-qualifications"
        FAILED_REPOS+=("access-your-teaching-qualifications")
    fi
else
    echo "⏭️  Directory access-your-teaching-qualifications already exists, skipping..."
fi


echo "📦 Cloning: apply-for-qualified-teacher-status"
if [ ! -d "apply-for-qualified-teacher-status" ]; then
    if git clone "git@github.com:DFE-Digital/apply-for-qualified-teacher-status.git" "apply-for-qualified-teacher-status"; then
        echo "✅ Successfully cloned: apply-for-qualified-teacher-status"
    else
        echo "❌ Failed to clone: apply-for-qualified-teacher-status"
        FAILED_REPOS+=("apply-for-qualified-teacher-status")
    fi
else
    echo "⏭️  Directory apply-for-qualified-teacher-status already exists, skipping..."
fi


echo "📦 Cloning: apply-for-teacher-training"
if [ ! -d "apply-for-teacher-training" ]; then
    if git clone "git@github.com:DFE-Digital/apply-for-teacher-training.git" "apply-for-teacher-training"; then
        echo "✅ Successfully cloned: apply-for-teacher-training"
    else
        echo "❌ Failed to clone: apply-for-teacher-training"
        FAILED_REPOS+=("apply-for-teacher-training")
    fi
else
    echo "⏭️  Directory apply-for-teacher-training already exists, skipping..."
fi


echo "📦 Cloning: bat-infrastructure"
if [ ! -d "bat-infrastructure" ]; then
    if git clone "git@github.com:DFE-Digital/bat-infrastructure.git" "bat-infrastructure"; then
        echo "✅ Successfully cloned: bat-infrastructure"
    else
        echo "❌ Failed to clone: bat-infrastructure"
        FAILED_REPOS+=("bat-infrastructure")
    fi
else
    echo "⏭️  Directory bat-infrastructure already exists, skipping..."
fi


echo "📦 Cloning: check-childrens-barred-list"
if [ ! -d "check-childrens-barred-list" ]; then
    if git clone "git@github.com:DFE-Digital/check-childrens-barred-list.git" "check-childrens-barred-list"; then
        echo "✅ Successfully cloned: check-childrens-barred-list"
    else
        echo "❌ Failed to clone: check-childrens-barred-list"
        FAILED_REPOS+=("check-childrens-barred-list")
    fi
else
    echo "⏭️  Directory check-childrens-barred-list already exists, skipping..."
fi


echo "📦 Cloning: claim-additional-payments-for-teaching"
if [ ! -d "claim-additional-payments-for-teaching" ]; then
    if git clone "git@github.com:DFE-Digital/claim-additional-payments-for-teaching.git" "claim-additional-payments-for-teaching"; then
        echo "✅ Successfully cloned: claim-additional-payments-for-teaching"
    else
        echo "❌ Failed to clone: claim-additional-payments-for-teaching"
        FAILED_REPOS+=("claim-additional-payments-for-teaching")
    fi
else
    echo "⏭️  Directory claim-additional-payments-for-teaching already exists, skipping..."
fi


echo "📦 Cloning: early-careers-framework"
if [ ! -d "early-careers-framework" ]; then
    if git clone "git@github.com:DFE-Digital/early-careers-framework.git" "early-careers-framework"; then
        echo "✅ Successfully cloned: early-careers-framework"
    else
        echo "❌ Failed to clone: early-careers-framework"
        FAILED_REPOS+=("early-careers-framework")
    fi
else
    echo "⏭️  Directory early-careers-framework already exists, skipping..."
fi


echo "📦 Cloning: find-a-lost-trn"
if [ ! -d "find-a-lost-trn" ]; then
    if git clone "git@github.com:DFE-Digital/find-a-lost-trn.git" "find-a-lost-trn"; then
        echo "✅ Successfully cloned: find-a-lost-trn"
    else
        echo "❌ Failed to clone: find-a-lost-trn"
        FAILED_REPOS+=("find-a-lost-trn")
    fi
else
    echo "⏭️  Directory find-a-lost-trn already exists, skipping..."
fi


echo "📦 Cloning: get-a-teacher-relocation-payment"
if [ ! -d "get-a-teacher-relocation-payment" ]; then
    if git clone "git@github.com:DFE-Digital/get-a-teacher-relocation-payment.git" "get-a-teacher-relocation-payment"; then
        echo "✅ Successfully cloned: get-a-teacher-relocation-payment"
    else
        echo "❌ Failed to clone: get-a-teacher-relocation-payment"
        FAILED_REPOS+=("get-a-teacher-relocation-payment")
    fi
else
    echo "⏭️  Directory get-a-teacher-relocation-payment already exists, skipping..."
fi


echo "📦 Cloning: get-an-identity"
if [ ! -d "get-an-identity" ]; then
    if git clone "git@github.com:DFE-Digital/get-an-identity.git" "get-an-identity"; then
        echo "✅ Successfully cloned: get-an-identity"
    else
        echo "❌ Failed to clone: get-an-identity"
        FAILED_REPOS+=("get-an-identity")
    fi
else
    echo "⏭️  Directory get-an-identity already exists, skipping..."
fi


echo "📦 Cloning: get-into-teaching-api"
if [ ! -d "get-into-teaching-api" ]; then
    if git clone "git@github.com:DFE-Digital/get-into-teaching-api.git" "get-into-teaching-api"; then
        echo "✅ Successfully cloned: get-into-teaching-api"
    else
        echo "❌ Failed to clone: get-into-teaching-api"
        FAILED_REPOS+=("get-into-teaching-api")
    fi
else
    echo "⏭️  Directory get-into-teaching-api already exists, skipping..."
fi


echo "📦 Cloning: get-into-teaching-app"
if [ ! -d "get-into-teaching-app" ]; then
    if git clone "git@github.com:DFE-Digital/get-into-teaching-app.git" "get-into-teaching-app"; then
        echo "✅ Successfully cloned: get-into-teaching-app"
    else
        echo "❌ Failed to clone: get-into-teaching-app"
        FAILED_REPOS+=("get-into-teaching-app")
    fi
else
    echo "⏭️  Directory get-into-teaching-app already exists, skipping..."
fi


echo "📦 Cloning: github-actions"
if [ ! -d "github-actions" ]; then
    if git clone "git@github.com:DFE-Digital/github-actions.git" "github-actions"; then
        echo "✅ Successfully cloned: github-actions"
    else
        echo "❌ Failed to clone: github-actions"
        FAILED_REPOS+=("github-actions")
    fi
else
    echo "⏭️  Directory github-actions already exists, skipping..."
fi


echo "📦 Cloning: itt-mentor-services"
if [ ! -d "itt-mentor-services" ]; then
    if git clone "git@github.com:DFE-Digital/itt-mentor-services.git" "itt-mentor-services"; then
        echo "✅ Successfully cloned: itt-mentor-services"
    else
        echo "❌ Failed to clone: itt-mentor-services"
        FAILED_REPOS+=("itt-mentor-services")
    fi
else
    echo "⏭️  Directory itt-mentor-services already exists, skipping..."
fi


echo "📦 Cloning: national-professional-qualification"
if [ ! -d "national-professional-qualification" ]; then
    if git clone "git@github.com:DFE-Digital/national-professional-qualification.git" "national-professional-qualification"; then
        echo "✅ Successfully cloned: national-professional-qualification"
    else
        echo "❌ Failed to clone: national-professional-qualification"
        FAILED_REPOS+=("national-professional-qualification")
    fi
else
    echo "⏭️  Directory national-professional-qualification already exists, skipping..."
fi


echo "📦 Cloning: npq-registration"
if [ ! -d "npq-registration" ]; then
    if git clone "https://github.com/DFE-Digital/npq-registration" "npq-registration"; then
        echo "✅ Successfully cloned: npq-registration"
    else
        echo "❌ Failed to clone: npq-registration"
        FAILED_REPOS+=("npq-registration")
    fi
else
    echo "⏭️  Directory npq-registration already exists, skipping..."
fi


echo "📦 Cloning: publish-teacher-training"
if [ ! -d "publish-teacher-training" ]; then
    if git clone "git@github.com:DFE-Digital/publish-teacher-training.git" "publish-teacher-training"; then
        echo "✅ Successfully cloned: publish-teacher-training"
    else
        echo "❌ Failed to clone: publish-teacher-training"
        FAILED_REPOS+=("publish-teacher-training")
    fi
else
    echo "⏭️  Directory publish-teacher-training already exists, skipping..."
fi


echo "📦 Cloning: register-early-career-teachers-public"
if [ ! -d "register-early-career-teachers-public" ]; then
    if git clone "git@github.com:DFE-Digital/register-early-career-teachers-public.git" "register-early-career-teachers-public"; then
        echo "✅ Successfully cloned: register-early-career-teachers-public"
    else
        echo "❌ Failed to clone: register-early-career-teachers-public"
        FAILED_REPOS+=("register-early-career-teachers-public")
    fi
else
    echo "⏭️  Directory register-early-career-teachers-public already exists, skipping..."
fi


echo "📦 Cloning: register-trainee-teachers"
if [ ! -d "register-trainee-teachers" ]; then
    if git clone "git@github.com:DFE-Digital/register-trainee-teachers.git" "register-trainee-teachers"; then
        echo "✅ Successfully cloned: register-trainee-teachers"
    else
        echo "❌ Failed to clone: register-trainee-teachers"
        FAILED_REPOS+=("register-trainee-teachers")
    fi
else
    echo "⏭️  Directory register-trainee-teachers already exists, skipping..."
fi


echo "📦 Cloning: schools-experience"
if [ ! -d "schools-experience" ]; then
    if git clone "git@github.com:DFE-Digital/schools-experience.git" "schools-experience"; then
        echo "✅ Successfully cloned: schools-experience"
    else
        echo "❌ Failed to clone: schools-experience"
        FAILED_REPOS+=("schools-experience")
    fi
else
    echo "⏭️  Directory schools-experience already exists, skipping..."
fi


echo "📦 Cloning: teacher-pay-calculator"
if [ ! -d "teacher-pay-calculator" ]; then
    if git clone "git@github.com:DFE-Digital/teacher-pay-calculator.git" "teacher-pay-calculator"; then
        echo "✅ Successfully cloned: teacher-pay-calculator"
    else
        echo "❌ Failed to clone: teacher-pay-calculator"
        FAILED_REPOS+=("teacher-pay-calculator")
    fi
else
    echo "⏭️  Directory teacher-pay-calculator already exists, skipping..."
fi


echo "📦 Cloning: teacher-services-cloud"
if [ ! -d "teacher-services-cloud" ]; then
    if git clone "git@github.com:DFE-Digital/teacher-services-cloud.git" "teacher-services-cloud"; then
        echo "✅ Successfully cloned: teacher-services-cloud"
    else
        echo "❌ Failed to clone: teacher-services-cloud"
        FAILED_REPOS+=("teacher-services-cloud")
    fi
else
    echo "⏭️  Directory teacher-services-cloud already exists, skipping..."
fi


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
