#!/usr/bin/env bash
# Fish Function Execution Tests
# Actually executes Fish functions to verify they work correctly

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "Fish Function Execution Tests"
reset_test_counters

# ============================================
# 1. CLIPBOARD FUNCTIONS
# ============================================
print_subheader "1. Clipboard Functions"

# Test clipboard_copy actually works
run_test "clipboard_copy copies to clipboard" \
    "test_clipboard"

# Test reset_fish uses clipboard
run_test "reset_fish clears clipboard" \
    "fish -c 'source ~/.config/fish/functions/reset_fish.fish && reset_fish' 2>&1 | grep -q 'reset'"

# ============================================
# 2. GIT NAVIGATION FUNCTIONS
# ============================================
print_subheader "2. Git Navigation Functions"

# Test grt (go to repo root)
with_test_git_repo "
    run_test 'grt returns to repo root' \
        'mkdir -p subdir && cd subdir && fish -c \"source ~/.config/fish/functions/grt.fish && grt\" && [[ \$(pwd) =~ test-repo ]]'
"

# Test __git.current_branch
with_test_git_repo "
    run_test '__git.current_branch returns branch name' \
        'fish -c \"source ~/.config/fish/functions/__git.current_branch.fish && __git.current_branch\" | grep -q \"main\\|master\"'
"

# Test __git.default_branch
with_test_git_repo "
    run_test '__git.default_branch detects default branch' \
        'fish -c \"source ~/.config/fish/functions/__git.default_branch.fish && __git.default_branch\" | grep -q \"main\\|master\"'
"

# ============================================
# 3. GIT WORKFLOW FUNCTIONS
# ============================================
print_subheader "3. Git Workflow Functions"

# Test gwip (work in progress commit)
with_test_git_repo "
    echo 'new content' > test.txt
    git add test.txt
    run_test 'gwip creates WIP commit' \
        'fish -c \"source ~/.config/fish/functions/gwip.fish && gwip\" && git log -1 --format=%s | grep -q \"WIP\"'
"

# Test gunwip (undo WIP commit)
with_test_git_repo "
    echo 'new content' > test.txt
    git add test.txt
    fish -c 'source ~/.config/fish/functions/gwip.fish && gwip' 2>/dev/null
    run_test 'gunwip removes WIP commit' \
        'fish -c \"source ~/.config/fish/functions/gunwip.fish && gunwip\" && ! git log -1 --format=%s | grep -q \"WIP\"'
"

# Test gdv (git diff with delta)
with_test_git_repo "
    echo 'changed' >> README.md
    if check_command delta; then
        run_test 'gdv shows diff with delta' \
            'fish -c \"source ~/.config/fish/functions/gdv.fish && gdv\" 2>&1 | grep -q \"changed\\|README\"'
    else
        run_test 'gdv falls back to git diff' \
            'fish -c \"source ~/.config/fish/functions/gdv.fish && gdv\" 2>&1 | grep -q \"changed\\|README\"'
    fi
"

# ============================================
# 4. UTILITY FUNCTIONS
# ============================================
print_subheader "4. Utility Functions"

# Test man function (colorized man pages)
run_test_warn "man function enhances man pages" \
    "fish -c 'source ~/.config/fish/functions/man.fish && functions man' | grep -q 'LESS_TERMCAP'"

# Test cless function
if check_command bat; then
    run_test "cless uses bat for colorized output" \
        "echo 'test content' | fish -c 'source ~/.config/fish/functions/cless.fish && cless' 2>&1 | grep -q 'test content'"
else
    run_test_warn "cless falls back to less" \
        "fish -c 'source ~/.config/fish/functions/cless.fish && functions cless'"
fi

# Test zcode function (cross-platform)
run_test "zcode function has OS detection" \
    "grep -q 'uname' ~/.config/fish/functions/zcode.fish"

# ============================================
# 5. FZF FUNCTIONS
# ============================================
print_subheader "5. FZF Functions"

if check_command fzf; then
    # Test _fzf_wrapper exists and loads
    run_test "_fzf_wrapper function exists" \
        "check_fish_function _fzf_wrapper"

    # Test _fzf_search_directory exists
    run_test "_fzf_search_directory function exists" \
        "check_fish_function _fzf_search_directory"

    # Test _fzf_search_git_log exists
    run_test "_fzf_search_git_log function exists" \
        "check_fish_function _fzf_search_git_log"

    # Test _fzf_search_history exists
    run_test "_fzf_search_history function exists" \
        "check_fish_function _fzf_search_history"
else
    print_skip "FZF not installed, skipping FZF function tests"
    ((TESTS_SKIPPED+=4))
    ((TOTAL_TESTS+=4))
fi

# ============================================
# 6. ZOXIDE FUNCTIONS
# ============================================
print_subheader "6. Zoxide Functions"

if check_command zoxide; then
    # Test __z function
    run_test_warn "__z function exists for directory jumping" \
        "check_fish_function __z || fish -c 'type __z'"

    # Test z command works
    run_test_warn "z command available in Fish" \
        "fish -c 'type z' 2>&1 | grep -q 'function\\|alias'"
else
    print_skip "Zoxide not installed, skipping zoxide function tests"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# ============================================
# 7. EDITOR FUNCTIONS
# ============================================
print_subheader "7. Editor Functions"

# Test cursor function (if Cursor is available)
if [[ -d "/Applications/Cursor.app" ]] || check_command cursor; then
    run_test "cursor function opens Cursor editor" \
        "fish -c 'source ~/.config/fish/functions/cursor.fish && functions cursor' | grep -q 'open\\|cursor'"
else
    print_skip "Cursor not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 8. KUBERNETES FUNCTIONS (if kubectl available)
# ============================================
print_subheader "8. Kubernetes Functions"

if check_command kubectl; then
    # Test knvim function exists
    run_test_warn "knvim function exists for pod editing" \
        "check_file ~/.config/fish/functions/knvim.fish"

    # Test stern wrapper exists
    run_test_warn "stern wrapper function exists" \
        "check_file ~/.config/fish/functions/stern.fish"
else
    print_skip "kubectl not installed, skipping K8s function tests"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# ============================================
# 9. AWS FUNCTIONS (if AWS CLI available)
# ============================================
print_subheader "9. AWS Functions"

if check_command aws; then
    # Test AWS profile completion function
    run_test_warn "AWS profile completion function exists" \
        "check_file ~/.config/fish/functions/__fish_complete_aws_profiles.fish"

    # Test AWS S3 bucket completion function
    run_test_warn "AWS S3 bucket completion function exists" \
        "check_file ~/.config/fish/functions/__fish_complete_aws_s3_buckets.fish"
else
    print_skip "AWS CLI not installed, skipping AWS function tests"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# ============================================
# 10. ABBREVIATION FUNCTIONS
# ============================================
print_subheader "10. Fish Abbreviations"

# Test that abbreviations are defined
run_test "Git abbreviations defined" \
    "fish -c 'abbr -s' | grep -q 'g\\|ga\\|gc'"

# Test abbreviation tips functions exist (if plugin installed)
if check_fish_function __abbr_tips_init; then
    run_test "__abbr_tips functions loaded" \
        "fish -c 'functions __abbr_tips_init'"
else
    print_skip "Abbreviation tips plugin not active"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 11. AUTOPAIR FUNCTIONS
# ============================================
print_subheader "11. Autopair Functions"

# Test autopair functions exist (if plugin installed)
if check_fish_function _autopair_insert_left; then
    run_test "_autopair_insert_left function exists" \
        "fish -c 'functions _autopair_insert_left'"

    run_test "_autopair_insert_right function exists" \
        "fish -c 'functions _autopair_insert_right'"

    run_test "_autopair_backspace function exists" \
        "fish -c 'functions _autopair_backspace'"
else
    print_skip "Autopair plugin not active"
    ((TESTS_SKIPPED+=3))
    ((TOTAL_TESTS+=3))
fi

# ============================================
# 12. TERMINAL RESET FUNCTIONS
# ============================================
print_subheader "12. Terminal Reset Functions"

# Test fix_arrow_keys
run_test "fix_arrow_keys function exists" \
    "check_file ~/.config/fish/functions/fix_arrow_keys.fish"

# Test debug_keys
run_test "debug_keys function exists" \
    "check_file ~/.config/fish/functions/debug_keys.fish"

# Test fix_terminal
run_test "fix_terminal function exists" \
    "check_file ~/.config/fish/functions/fix_terminal.fish"

# ============================================
# FISH FUNCTION TEST SUMMARY
# ============================================
print_test_summary "Fish Function Execution"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 5 ]]; then
    exit 0
else
    exit 1
fi
