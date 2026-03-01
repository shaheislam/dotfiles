#!/usr/bin/env bash
# Merge Driver Tests
# Tests that the union merge driver correctly resolves documentation conflicts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

DRIVER="$SCRIPT_DIR/../merge-driver-union.sh"
TEST_DIR=""

print_header "Merge Driver Tests"
reset_test_counters

# Setup temp git repo for each test
setup_test_repo() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || return 1
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
}

cleanup_test_repo() {
    [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ============================================
# 1. MERGE DRIVER SCRIPT VALIDATION
# ============================================
print_subheader "1. Merge Driver Script Validation"

run_test "merge-driver-union.sh exists" \
    "test -f '$DRIVER'"

run_test "merge-driver-union.sh is executable" \
    "test -x '$DRIVER'"

run_test "merge-driver-union.sh has valid bash syntax" \
    "bash -n '$DRIVER'"

run_test "auto-merge.sh has valid bash syntax" \
    "bash -n '$SCRIPT_DIR/../auto-merge.sh'"

# ============================================
# 2. GITATTRIBUTES CONFIGURATION
# ============================================
print_subheader "2. Gitattributes Configuration"

DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

run_test ".gitattributes exists" \
    "test -f '$DOTFILES_ROOT/.gitattributes'"

run_test ".gitattributes has CLAUDE.md union-doc entry" \
    "grep -q 'CLAUDE.md.*merge=union-doc' '$DOTFILES_ROOT/.gitattributes'"

run_test ".gitattributes has AGENTS.md union-doc entry" \
    "grep -q 'AGENTS.md.*merge=union-doc' '$DOTFILES_ROOT/.gitattributes'"

# ============================================
# 3. SETUP.SH INTEGRATION
# ============================================
print_subheader "3. Setup Script Integration"

run_test "setup.sh registers union-doc merge driver" \
    "grep -q 'merge.union-doc.driver' '$DOTFILES_ROOT/scripts/setup.sh'"

run_test "setup.sh configures merge driver name" \
    "grep -q 'merge.union-doc.name' '$DOTFILES_ROOT/scripts/setup.sh'"

# ============================================
# 4. APPEND CONFLICT RESOLUTION
# ============================================
print_subheader "4. Append Conflict Resolution"

# Test: Both sides append different lines to the end
run_test "resolves append-only conflicts (both sides add lines)" '
    setup_test_repo
    echo -e "# Doc\nLine 1\nLine 2" > doc.md
    git add doc.md && git commit -q -m "base"

    # Branch A adds lines
    git checkout -q -b branch-a
    echo -e "# Doc\nLine 1\nLine 2\nBranch A addition" > doc.md
    git add doc.md && git commit -q -m "branch a"

    # Branch B adds different lines
    git checkout -q main
    git checkout -q -b branch-b
    echo -e "# Doc\nLine 1\nLine 2\nBranch B addition" > doc.md
    git add doc.md && git commit -q -m "branch b"

    # Create conflict scenario with temp files
    git show branch-b:doc.md > /tmp/test_ours.md
    git show main~0:doc.md > /tmp/test_base.md 2>/dev/null || echo -e "# Doc\nLine 1\nLine 2" > /tmp/test_base.md
    git show branch-a:doc.md > /tmp/test_theirs.md

    # Run merge driver
    '"$DRIVER"' /tmp/test_ours.md /tmp/test_base.md /tmp/test_theirs.md 7 doc.md
    result=$?

    # Verify both additions are present
    grep -q "Branch A addition" /tmp/test_ours.md && \
    grep -q "Branch B addition" /tmp/test_ours.md && \
    test $result -eq 0

    cleanup_test_repo
'

# Test: Both sides add to same section
run_test "resolves both-sides-add-to-section conflicts" '
    setup_test_repo
    echo -e "# Updates\n- item 1\n- item 2" > doc.md
    git add doc.md && git commit -q -m "base"

    cp doc.md /tmp/test_base2.md
    echo -e "# Updates\n- item 1\n- item 2\n- ours added" > /tmp/test_ours2.md
    echo -e "# Updates\n- item 1\n- item 2\n- theirs added" > /tmp/test_theirs2.md

    '"$DRIVER"' /tmp/test_ours2.md /tmp/test_base2.md /tmp/test_theirs2.md 7 doc.md
    result=$?

    grep -q "ours added" /tmp/test_ours2.md && \
    grep -q "theirs added" /tmp/test_ours2.md && \
    test $result -eq 0

    cleanup_test_repo
'

# ============================================
# 5. CLEAN MERGE PASSTHROUGH
# ============================================
print_subheader "5. Clean Merge Passthrough"

run_test "clean merge (no conflict) passes through" '
    echo -e "# Doc\nLine 1" > /tmp/test_clean_base.md
    echo -e "# Doc\nLine 1\nOurs only" > /tmp/test_clean_ours.md
    cp /tmp/test_clean_base.md /tmp/test_clean_theirs.md

    '"$DRIVER"' /tmp/test_clean_ours.md /tmp/test_clean_base.md /tmp/test_clean_theirs.md 7 doc.md
    result=$?

    grep -q "Ours only" /tmp/test_clean_ours.md && test $result -eq 0
'

# ============================================
# 6. NO CONFLICT MARKERS IN OUTPUT
# ============================================
print_subheader "6. No Conflict Markers in Output"

run_test "output never contains conflict markers" '
    echo -e "# Doc\nShared line" > /tmp/test_markers_base.md
    echo -e "# Doc\nOurs version of shared line\nOurs new" > /tmp/test_markers_ours.md
    echo -e "# Doc\nTheirs version of shared line\nTheirs new" > /tmp/test_markers_theirs.md

    '"$DRIVER"' /tmp/test_markers_ours.md /tmp/test_markers_base.md /tmp/test_markers_theirs.md 7 doc.md

    ! grep -q "^<<<<<<<\|^>>>>>>>\|^=======$\|^|||||||" /tmp/test_markers_ours.md
'

# ============================================
# 7. DEDUPLICATION
# ============================================
print_subheader "7. Line Deduplication"

run_test "deduplicates identical consecutive lines" '
    echo -e "# Doc\nLine 1" > /tmp/test_dedup_base.md
    echo -e "# Doc\nLine 1\nNew section" > /tmp/test_dedup_ours.md
    echo -e "# Doc\nLine 1\nNew section" > /tmp/test_dedup_theirs.md

    '"$DRIVER"' /tmp/test_dedup_ours.md /tmp/test_dedup_base.md /tmp/test_dedup_theirs.md 7 doc.md
    result=$?

    # Should not have duplicate "New section" lines
    count=$(grep -c "New section" /tmp/test_dedup_ours.md)
    test "$count" -eq 1 && test $result -eq 0
'

# ============================================
# 8. AUTO-MERGE.SH UNION INTEGRATION
# ============================================
print_subheader "8. Auto-Merge Union Integration"

run_test "auto-merge.sh has union merge fallback for .md files" \
    "grep -q 'union.*merge.*md\|trying union merge' '$SCRIPT_DIR/../auto-merge.sh'"

run_test "auto-merge.sh extracts three versions for union merge" \
    "grep -q 'git show.*:2:\|git show.*:1:\|git show.*:3:' '$SCRIPT_DIR/../auto-merge.sh'"

# ============================================
# SUMMARY
# ============================================
echo ""
print_test_summary
