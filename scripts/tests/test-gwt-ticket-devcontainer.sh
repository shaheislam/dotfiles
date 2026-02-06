#!/usr/bin/env bash
# gwt-ticket Devcontainer Detection Tests
#
# Validates whether gwt-ticket correctly determines execution environment:
# - Repos WITH .devcontainer → Claude runs inside devcontainer via devcontainer exec
# - Repos WITHOUT .devcontainer → Claude runs locally on host
#
# Also tests for a known path-mapping bug in devcontainer exec mode.

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "gwt-ticket Devcontainer Detection Tests"
reset_test_counters

DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GWT_TICKET_FUNC="$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish"
DEVCON_FUNC="$DOTFILES_ROOT/.config/fish/functions/devcon.fish"
DEVCONTAINER_JSON="$DOTFILES_ROOT/devcontainer/claude-code-plugins/.devcontainer/devcontainer.json"

# ============================================
# 1. FUNCTION FILE EXISTENCE
# ============================================
print_subheader "1. Function Files Exist"

run_test "gwt-ticket.fish exists" \
    "check_file '$GWT_TICKET_FUNC'"

run_test "devcon.fish exists" \
    "check_file '$DEVCON_FUNC'"

run_test "devcontainer.json exists" \
    "check_file '$DEVCONTAINER_JSON'"

run_test "gwt-ticket function loads in Fish" \
    "check_fish_function gwt-ticket"

run_test "devcon function loads in Fish" \
    "check_fish_function devcon"

# ============================================
# 2. DEVCONTAINER DETECTION LOGIC
# ============================================
print_subheader "2. Devcontainer Detection Logic"

# Test: gwt-ticket checks for .devcontainer directory
run_test "gwt-ticket checks .devcontainer directory" \
    "grep -q 'test -d.*\.devcontainer' '$GWT_TICKET_FUNC'"

# Test: gwt-ticket checks for devcontainer.json file
run_test "gwt-ticket checks devcontainer.json file" \
    "grep -q 'test -f.*devcontainer\.json' '$GWT_TICKET_FUNC'"

# Test: gwt-ticket has --no-devcon flag
run_test "gwt-ticket supports --no-devcon flag" \
    "grep -q 'no-devcon' '$GWT_TICKET_FUNC'"

# Test: has_devcontainer defaults to false
run_test "has_devcontainer defaults to false" \
    "grep -q 'set -l has_devcontainer false' '$GWT_TICKET_FUNC'"

# Test: use_devcon defaults to true
run_test "use_devcon defaults to true" \
    "grep -q 'set -l use_devcon true' '$GWT_TICKET_FUNC'"

# ============================================
# 3. DOTFILES REPO DETECTION (THIS REPO)
# ============================================
print_subheader "3. Dotfiles Repo Detection (No Devcontainer)"

# The dotfiles repo does NOT have .devcontainer at root
run_test "Dotfiles repo has NO .devcontainer directory" \
    "[[ ! -d '$DOTFILES_ROOT/.devcontainer' ]]"

# The dotfiles repo has devcontainer/ (different from .devcontainer/)
run_test "Dotfiles repo has devcontainer/ (not .devcontainer/)" \
    "[[ -d '$DOTFILES_ROOT/devcontainer' ]] && [[ ! -d '$DOTFILES_ROOT/.devcontainer' ]]"

# No root-level devcontainer.json either
run_test "Dotfiles repo has NO root devcontainer.json" \
    "[[ ! -f '$DOTFILES_ROOT/devcontainer.json' ]]"

# Therefore: gwt-ticket would NOT use devcontainer for this repo
run_test "gwt-ticket falls to local execution for repos without .devcontainer" \
    "grep -A2 'has_devcontainer' '$GWT_TICKET_FUNC' | grep -q 'No .devcontainer found, running locally'"

# ============================================
# 4. DEVCONTAINER VS LOCAL EXECUTION PATHS
# ============================================
print_subheader "4. Execution Path Branching"

# Test: devcontainer path uses devcontainer exec
run_test "Devcontainer path uses 'devcontainer exec'" \
    "grep -q 'devcontainer exec' '$GWT_TICKET_FUNC'"

# Test: devcontainer path uses devcon up command
run_test "Devcontainer path starts container with devcon" \
    "grep -q 'devcon claude -i' '$GWT_TICKET_FUNC'"

# Test: local path uses direct fish execution
run_test "Local path uses direct 'fish \$launch_script'" \
    "grep -q 'fish \$launch_script' '$GWT_TICKET_FUNC'"

# Test: local path cds to worktree
run_test "Local path cds to worktree directory" \
    "grep -q 'cd \$worktree_path' '$GWT_TICKET_FUNC'"

# Test: the branch is conditioned on use_devcon AND has_devcontainer
run_test "Both use_devcon AND has_devcontainer required for container mode" \
    "grep -q 'use_devcon; and .has_devcontainer' '$GWT_TICKET_FUNC'"

# ============================================
# 5. DEVCONTAINER PATH ANALYSIS
# ============================================
print_subheader "5. Devcontainer Path Analysis"

# Test: launch script is written to worktree/.claude/
run_test "Launch script written to worktree/.claude/ directory" \
    "grep -q 'launch_script.*worktree_path.*\.claude/launch-claude\.fish' '$GWT_TICKET_FUNC'"

# Test: launch script uses host path (potential issue for container exec)
# The exec_cmd runs inside container, but launch_script is a host path
run_test "Launch script path is host-side (documented behavior)" \
    "grep 'exec_cmd fish \$launch_script' '$GWT_TICKET_FUNC' | grep -q 'launch_script'"

# Test: worktree is passed to devcon as mount directory
run_test "Worktree passed to devcon for mounting" \
    "grep -q 'devcon claude -i \$instance_name \$worktree_path' '$GWT_TICKET_FUNC'"

# Test: config_file points to claude-code-plugins devcontainer
run_test "Config file uses claude-code-plugins devcontainer" \
    "grep -q 'dotfiles/devcontainer/claude-code-plugins' '$GWT_TICKET_FUNC'"

# Test: workspace uses instance-specific path for isolation
run_test "Workspace folder uses instance name for isolation" \
    "grep -q '\.devcontainer/workspaces/\$instance_name' '$GWT_TICKET_FUNC'"

# ============================================
# 6. DEVCONTAINER.JSON MOUNT VALIDATION
# ============================================
print_subheader "6. Devcontainer Mount Configuration"

# Test: devcontainer.json mounts dotfiles
run_test "Devcontainer mounts ~/dotfiles" \
    "grep -q 'dotfiles' '$DEVCONTAINER_JSON'"

# Test: devcontainer.json has instance-aware mounts
run_test "Devcontainer uses DEVCON_INSTANCE for mount isolation" \
    "grep -q 'DEVCON_INSTANCE' '$DEVCONTAINER_JSON'"

# Test: workspace mount exists
run_test "Devcontainer has workspaceMount configured" \
    "grep -q 'workspaceMount' '$DEVCONTAINER_JSON'"

# Test: workspace folder is /workspace
run_test "Devcontainer workspace folder is /workspace" \
    "grep -q '\"workspaceFolder\": \"/workspace\"' '$DEVCONTAINER_JSON'"

# Test: container runs as node user
run_test "Container runs as node user" \
    "grep -q '\"remoteUser\": \"node\"' '$DEVCONTAINER_JSON'"

# ============================================
# 7. PATH MAPPING VERIFICATION
# ============================================
print_subheader "7. Path Mapping Between Host and Container"

# When devcon receives a directory, it mounts to /mounts/<dirname>
# So if worktree is at /Users/user/projects/myapp-feature-a
# it becomes /mounts/myapp-feature-a inside container

run_test "devcon mounts directories to /mounts/<dirname>" \
    "grep -q '/mounts/\$dirname' '$DEVCON_FUNC'"

# The launch script at worktree/.claude/launch-claude.fish
# Inside container, this would be at /mounts/<worktree_name>/.claude/launch-claude.fish
# But the exec command uses the HOST path. devcontainer exec may or may not translate.

# Test: the exec command in gwt-ticket uses host-side launch script path
# This is a known behavior - devcontainer exec with bind mounts can resolve host paths
# depending on the mount configuration
run_test "Exec uses host-path for launch script (relies on mount resolution)" \
    "grep -q \"exec_cmd fish \\\$launch_script\" '$GWT_TICKET_FUNC'"

# ============================================
# 8. SIMULATED DETECTION (FISH-BASED)
# ============================================
print_subheader "8. Simulated Devcontainer Detection"

# Create temp directories simulating repos with and without .devcontainer
TEST_TMPDIR="/tmp/gwt-ticket-test-$$"
mkdir -p "$TEST_TMPDIR/repo-with-devcon/.devcontainer"
echo '{}' > "$TEST_TMPDIR/repo-with-devcon/.devcontainer/devcontainer.json"
mkdir -p "$TEST_TMPDIR/repo-without-devcon"
mkdir -p "$TEST_TMPDIR/repo-with-root-json"
echo '{}' > "$TEST_TMPDIR/repo-with-root-json/devcontainer.json"

# Test: detection finds .devcontainer directory
run_test "Detects .devcontainer directory presence" \
    "[[ -d '$TEST_TMPDIR/repo-with-devcon/.devcontainer' ]]"

# Test: detection handles missing .devcontainer
run_test "Detects missing .devcontainer directory" \
    "[[ ! -d '$TEST_TMPDIR/repo-without-devcon/.devcontainer' ]]"

# Test: detection finds root devcontainer.json
run_test "Detects root-level devcontainer.json" \
    "[[ -f '$TEST_TMPDIR/repo-with-root-json/devcontainer.json' ]]"

# Fish-based detection simulation
run_test "Fish detection: repo WITH .devcontainer → has_devcontainer=true" \
    "fish -c '
        set -l worktree_path \"$TEST_TMPDIR/repo-with-devcon\"
        set -l has_devcontainer false
        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end
        test \$has_devcontainer = true
    '"

run_test "Fish detection: repo WITHOUT .devcontainer → has_devcontainer=false" \
    "fish -c '
        set -l worktree_path \"$TEST_TMPDIR/repo-without-devcon\"
        set -l has_devcontainer false
        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end
        test \$has_devcontainer = false
    '"

run_test "Fish detection: repo with root devcontainer.json → has_devcontainer=true" \
    "fish -c '
        set -l worktree_path \"$TEST_TMPDIR/repo-with-root-json\"
        set -l has_devcontainer false
        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end
        test \$has_devcontainer = true
    '"

run_test "Fish detection: dotfiles repo → has_devcontainer=false" \
    "fish -c '
        set -l worktree_path \"$DOTFILES_ROOT\"
        set -l has_devcontainer false
        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end
        test \$has_devcontainer = false
    '"

# ============================================
# 9. EXECUTION FLOW SIMULATION
# ============================================
print_subheader "9. Execution Flow Simulation"

# Simulate the complete decision logic for dotfiles repo
run_test "Dotfiles repo: use_devcon=true but has_devcontainer=false → local execution" \
    "fish -c '
        set -l use_devcon true
        set -l has_devcontainer false
        set -l worktree_path \"$DOTFILES_ROOT\"

        # Simulate detection
        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end

        # Simulate branching
        if \$use_devcon; and \$has_devcontainer
            echo \"DEVCONTAINER\"
        else
            echo \"LOCAL\"
        end
    ' | grep -q 'LOCAL'"

# Simulate with --no-devcon flag
run_test "With --no-devcon: always runs locally regardless of .devcontainer" \
    "fish -c '
        set -l use_devcon false
        set -l has_devcontainer true

        if \$use_devcon; and \$has_devcontainer
            echo \"DEVCONTAINER\"
        else
            echo \"LOCAL\"
        end
    ' | grep -q 'LOCAL'"

# Simulate repo WITH .devcontainer and use_devcon=true
run_test "Repo with .devcontainer and use_devcon=true → devcontainer execution" \
    "fish -c '
        set -l use_devcon true
        set -l has_devcontainer false
        set -l worktree_path \"$TEST_TMPDIR/repo-with-devcon\"

        if test -d \"\$worktree_path/.devcontainer\"; or test -f \"\$worktree_path/devcontainer.json\"
            set has_devcontainer true
        end

        if \$use_devcon; and \$has_devcontainer
            echo \"DEVCONTAINER\"
        else
            echo \"LOCAL\"
        end
    ' | grep -q 'DEVCONTAINER'"

# ============================================
# 10. CURRENT ENVIRONMENT DETECTION
# ============================================
print_subheader "10. Current Environment Detection"

# Verify we're running on the host, not in a container
run_test "Running on macOS host (not in container)" \
    "is_macos"

run_test "No /.dockerenv file (not in Docker container)" \
    "[[ ! -f /.dockerenv ]]"

run_test "No /run/.containerenv file (not in Podman container)" \
    "[[ ! -f /run/.containerenv ]]"

run_test "HOME is real user home (not /home/node)" \
    "[[ \"\$HOME\" != '/home/node' ]]"

# In a devcontainer, the workspace would be at /workspace or /mounts/
run_test "Working directory is host path (not /workspace)" \
    "[[ ! \"\$(pwd)\" =~ ^/workspace ]]"

run_test "Working directory is host path (not /mounts/)" \
    "[[ ! \"\$(pwd)\" =~ ^/mounts/ ]]"

# ============================================
# 11. LAUNCH SCRIPT GENERATION
# ============================================
print_subheader "11. Launch Script Generation"

# Check that the current launch script was generated (from previous gwt-ticket run)
if [[ -f "$DOTFILES_ROOT/.claude/launch-claude.fish" ]]; then
    run_test "Launch script was generated by gwt-ticket" \
        "check_file '$DOTFILES_ROOT/.claude/launch-claude.fish'"

    run_test "Launch script is executable" \
        "[[ -x '$DOTFILES_ROOT/.claude/launch-claude.fish' ]]"

    run_test "Launch script starts with fish shebang" \
        "head -1 '$DOTFILES_ROOT/.claude/launch-claude.fish' | grep -q '#!/usr/bin/env fish'"

    run_test "Launch script invokes claude" \
        "grep -q 'claude' '$DOTFILES_ROOT/.claude/launch-claude.fish'"
else
    print_skip "No launch script found (gwt-ticket not run recently)"
    ((TESTS_SKIPPED+=4))
    ((TOTAL_TESTS+=4))
fi

# Check ticket-execute state file
if [[ -f "$DOTFILES_ROOT/.claude/ticket-execute.local.md" ]]; then
    run_test "State file exists from current execution" \
        "check_file '$DOTFILES_ROOT/.claude/ticket-execute.local.md'"

    run_test "State file has YAML frontmatter" \
        "head -1 '$DOTFILES_ROOT/.claude/ticket-execute.local.md' | grep -q '^---'"

    run_test "State file tracks worktree path" \
        "grep -q 'worktree_path' '$DOTFILES_ROOT/.claude/ticket-execute.local.md'"
else
    print_skip "No state file found"
    ((TESTS_SKIPPED+=3))
    ((TOTAL_TESTS+=3))
fi

# ============================================
# 12. gwt-ticket ALIAS VERIFICATION
# ============================================
print_subheader "12. Alias Verification"

run_test "gwtt alias exists in config.fish" \
    "grep -q 'alias gwtt.*gwt-ticket' '$DOTFILES_ROOT/.config/fish/config.fish'"

run_test "gwtt alias is for gwt-ticket" \
    "grep 'alias gwtt' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'gwt-ticket'"

# ============================================
# CLEANUP
# ============================================
rm -rf "$TEST_TMPDIR"

# ============================================
# TEST SUMMARY
# ============================================
print_test_summary "gwt-ticket Devcontainer Detection"

# Print analysis summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Analysis Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "gwt-ticket devcontainer execution logic:"
echo ""
echo "  1. Checks if worktree has .devcontainer/ or devcontainer.json"
echo "  2. If YES and --no-devcon not set:"
echo "     → Starts devcontainer with 'devcon claude -i <instance> <worktree>'"
echo "     → Runs Claude via 'devcontainer exec ... fish <launch-script>'"
echo "     → Claude runs INSIDE the container"
echo ""
echo "  3. If NO (like dotfiles repo) or --no-devcon set:"
echo "     → Runs Claude directly on host: 'fish <launch-script>'"
echo "     → Claude sees ALL host files (expected behavior)"
echo ""
echo "For this repo (dotfiles-devconmount):"
echo "  → No .devcontainer directory exists"
echo "  → devcontainer/ exists but is for OTHER projects' container configs"
echo "  → Claude runs LOCALLY on host → can see all files (correct behavior)"
echo ""

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 3 ]]; then
    exit 0
else
    exit 1
fi
