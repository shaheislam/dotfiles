#!/usr/bin/env bash
# Test suite for claude-pipeline Fish function
# Tests configuration parsing, dry-run output, and basic validation
# Use --live to run actual Claude API calls (requires subscription)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_header() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }
print_success() { echo -e "${GREEN}  PASS${NC} $1"; }
print_error() { echo -e "${RED}  FAIL${NC} $1"; }
print_warning() { echo -e "${YELLOW}  SKIP${NC} $1"; }

PASS=0
FAIL=0
SKIP=0
LIVE_MODE=false

if [[ "${1:-}" == "--live" ]]; then
    LIVE_MODE=true
fi

assert_contains() {
    local description="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        print_success "$description"
        ((PASS++))
    else
        print_error "$description (expected: '$needle')"
        ((FAIL++))
    fi
}

assert_exit_code() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        print_success "$description"
        ((PASS++))
    else
        print_error "$description (expected exit $expected, got $actual)"
        ((FAIL++))
    fi
}

# ============================================================================
# Config Tests (no API calls)
# ============================================================================

print_header "Configuration Tests"

# Test: Function file exists
if [[ -f "$SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish" ]]; then
    print_success "claude-pipeline.fish exists"
    ((PASS++))
else
    print_error "claude-pipeline.fish not found"
    ((FAIL++))
fi

# Test: Alias file exists
if [[ -f "$SCRIPT_DIR/../.config/fish/functions/cpipe.fish" ]]; then
    print_success "cpipe.fish alias exists"
    ((PASS++))
else
    print_error "cpipe.fish alias not found"
    ((FAIL++))
fi

# Test: Help text
if command -v fish &>/dev/null; then
    help_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --help" 2>&1)
    assert_contains "Help: shows usage" "$help_output" "Usage: claude-pipeline"
    assert_contains "Help: shows presets" "$help_output" "Pipeline Presets"
    assert_contains "Help: shows model aliases" "$help_output" "opusplan"
    assert_contains "Help: shows examples" "$help_output" "Examples"
    assert_contains "Help: shows related commands" "$help_output" "Related"

    # Test: Dry run default (2-stage opus→sonnet)
    dry_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --dry-run 'test prompt'" 2>&1)
    assert_contains "Dry run: shows 2 stages" "$dry_output" "2 stages"
    assert_contains "Dry run: stage 1 uses opus" "$dry_output" "Stage 1 \[opus\]"
    assert_contains "Dry run: stage 2 uses sonnet" "$dry_output" "Stage 2 \[sonnet\]"

    # Test: Dry run with preset review (3-stage)
    dry_review=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --dry-run --preset review 'test'" 2>&1)
    assert_contains "Preset review: 3 stages" "$dry_review" "3 stages"
    assert_contains "Preset review: stage 1 opus" "$dry_review" "Stage 1 \[opus\]"
    assert_contains "Preset review: stage 2 sonnet" "$dry_review" "Stage 2 \[sonnet\]"
    assert_contains "Preset review: stage 3 haiku" "$dry_review" "Stage 3 \[haiku\]"

    # Test: Dry run with preset cheap
    dry_cheap=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --dry-run --preset cheap 'test'" 2>&1)
    assert_contains "Preset cheap: stage 1 sonnet" "$dry_cheap" "Stage 1 \[sonnet\]"
    assert_contains "Preset cheap: stage 2 haiku" "$dry_cheap" "Stage 2 \[haiku\]"

    # Test: Dry run with custom models
    dry_custom=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --dry-run --reason haiku --execute opus 'test'" 2>&1)
    assert_contains "Custom models: stage 1 haiku" "$dry_custom" "Stage 1 \[haiku\]"
    assert_contains "Custom models: stage 2 opus" "$dry_custom" "Stage 2 \[opus\]"

    # Test: Dry run with local preset
    dry_local=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --dry-run --preset local 'test'" 2>&1)
    assert_contains "Preset local: stage 1 ollama" "$dry_local" "Stage 1 \[ollama\]"
    assert_contains "Preset local: stage 2 sonnet" "$dry_local" "Stage 2 \[sonnet\]"

    # Test: No prompt error
    no_prompt_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline" 2>&1)
    no_prompt_exit=$?
    assert_contains "No prompt: shows error" "$no_prompt_output" "No prompt provided"

    # Test: Invalid preset error
    bad_preset_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset nonexistent 'test'" 2>&1)
    assert_contains "Bad preset: shows error" "$bad_preset_output" "Unknown preset"

    # Test: Stages validation
    bad_stages_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --stages 6 'test'" 2>&1)
    assert_contains "Invalid stages: shows error" "$bad_stages_output" "Stages must be between 2 and 5"
else
    print_warning "Fish shell not installed - skipping function tests"
    ((SKIP++))
fi

# ============================================================================
# Live Tests (require Claude subscription)
# ============================================================================

if $LIVE_MODE; then
    print_header "Live Tests (API calls)"

    if ! command -v claude &>/dev/null; then
        print_error "claude CLI not found"
        ((FAIL++))
    else
        # Test: Basic 2-stage pipeline (cheap preset to save tokens)
        print_warning "Running live pipeline (cheap preset)..."
        live_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap 'What is 2+2? Reply with just the number.'" 2>&1)
        live_exit=$?
        assert_exit_code "Live pipeline exits 0" "0" "$live_exit"
        if [[ -n "$live_output" ]]; then
            print_success "Live pipeline produced output ($(echo "$live_output" | wc -c | tr -d ' ') bytes)"
            ((PASS++))
        else
            print_error "Live pipeline produced no output"
            ((FAIL++))
        fi

        # Test: Pipeline with --save
        tmpdir=$(mktemp -d)
        save_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap --save $tmpdir/test --verbose 'What is 2+2? Reply with just the number.'" 2>&1)
        if [[ -f "$tmpdir/test-stage1.txt" ]]; then
            print_success "Save: stage1 file created"
            ((PASS++))
        else
            print_error "Save: stage1 file not created"
            ((FAIL++))
        fi
        if [[ -f "$tmpdir/test-stage2.txt" ]]; then
            print_success "Save: stage2 file created"
            ((PASS++))
        else
            print_error "Save: stage2 file not created"
            ((FAIL++))
        fi
        rm -rf "$tmpdir"

        # Test: Piped input
        pipe_output=$(echo "The sky is blue" | fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap 'What color is mentioned? Reply with just the color.'" 2>&1)
        if [[ -n "$pipe_output" ]]; then
            print_success "Piped input produced output"
            ((PASS++))
        else
            print_error "Piped input produced no output"
            ((FAIL++))
        fi
    fi
else
    print_header "Live Tests (skipped)"
    print_warning "Use --live to run API tests (requires Claude subscription)"
    ((SKIP++))
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "==============================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
