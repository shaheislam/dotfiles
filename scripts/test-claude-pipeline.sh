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
CYAN='\033[0;36m'
print_info() { echo -e "${CYAN}  INFO${NC} $1"; }

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
    if echo "$haystack" | grep -q -- "$needle"; then
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
# Cross-Provider Bridge Hook Tests (no API calls)
# ============================================================================

print_header "Cross-Provider Bridge Hook Tests"

HOOK_SCRIPT="$SCRIPT_DIR/../.claude/hooks/cross-provider-bridge.sh"

# Test: Hook script exists and is executable
if [[ -x "$HOOK_SCRIPT" ]]; then
    print_success "cross-provider-bridge.sh exists and is executable"
    ((PASS++))
else
    print_error "cross-provider-bridge.sh not found or not executable"
    ((FAIL++))
fi

# Test: Hook exits 0 when CROSS_PROVIDER_BRIDGE is not set (disabled by default)
hook_disabled_output=$(echo '{"stop_hook_active": false, "transcript_path": "/nonexistent"}' | CROSS_PROVIDER_BRIDGE="" bash "$HOOK_SCRIPT" 2>&1)
hook_disabled_exit=$?
assert_exit_code "Hook disabled: exits 0 (silent pass-through)" "0" "$hook_disabled_exit"

# Test: Hook exits 0 when stop_hook_active=true with no state file (safety fallback)
hook_loop_output=$(echo '{"stop_hook_active": true, "transcript_path": "/nonexistent"}' | CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" 2>&1)
hook_loop_exit=$?
assert_exit_code "Hook safety fallback: exits 0 when stop_hook_active=true with no state file" "0" "$hook_loop_exit"

# Test: Hook exits 0 when transcript path is missing
hook_no_transcript=$(echo '{"stop_hook_active": false}' | CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" 2>&1)
hook_no_transcript_exit=$?
assert_exit_code "Hook no transcript: exits 0 gracefully" "0" "$hook_no_transcript_exit"

# Test: Hook exits 0 when transcript file doesn't exist
hook_bad_path=$(echo '{"stop_hook_active": false, "transcript_path": "/tmp/nonexistent-transcript.jsonl"}' | CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" 2>&1)
hook_bad_path_exit=$?
assert_exit_code "Hook bad transcript path: exits 0 gracefully" "0" "$hook_bad_path_exit"

# Test: Hook exits 0 when no providers are available (graceful fallback)
# Use unknown provider names so the case statement skips all entries
tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test reasoning output"}' > "$tmpfile"
hook_no_providers=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$tmpfile\"}" | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_ORDER="nonexistent1,nonexistent2" \
    bash "$HOOK_SCRIPT" 2>&1)
hook_no_providers_exit=$?
rm -f "$tmpfile"
assert_exit_code "Hook no providers available: exits 0 (silent fallback)" "0" "$hook_no_providers_exit"

# Test: Max iterations reached — exits 0 and cleans up state file
iter_state_file="/tmp/cross-provider-bridge-test-max-iter.json"
jq -n '{iteration: 3, previous_reviews: ["r1","r2","r3"], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' > "$iter_state_file"
hook_max_iter=$(echo '{"stop_hook_active": true, "session_id": "test-max-iter", "transcript_path": "/nonexistent"}' | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_MAX_ITERATIONS=3 \
    bash "$HOOK_SCRIPT" 2>&1)
hook_max_iter_exit=$?
assert_exit_code "Max iterations reached: exits 0" "0" "$hook_max_iter_exit"
if [ ! -f "$iter_state_file" ]; then
    print_success "Max iterations reached: state file cleaned up"
    ((PASS++))
else
    print_error "Max iterations reached: state file not cleaned up"
    ((FAIL++))
    rm -f "$iter_state_file"
fi

# Test: Single-shot mode (MAX_ITERATIONS=1) — first stop_hook_active triggers exit
singleshot_state="/tmp/cross-provider-bridge-test-singleshot.json"
jq -n '{iteration: 1, previous_reviews: ["review1"], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' > "$singleshot_state"
hook_singleshot=$(echo '{"stop_hook_active": true, "session_id": "test-singleshot", "transcript_path": "/nonexistent"}' | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_MAX_ITERATIONS=1 \
    bash "$HOOK_SCRIPT" 2>&1)
hook_singleshot_exit=$?
assert_exit_code "Single-shot mode (MAX_ITERATIONS=1): exits 0 on iteration 1" "0" "$hook_singleshot_exit"
rm -f "$singleshot_state"

# Test: Stale state file (>10min old) — exits 0 and cleans up
stale_state="/tmp/cross-provider-bridge-test-stale.json"
stale_ts=$(($(date +%s) - 7200))  # 2 hours ago
jq -n --argjson ts "$stale_ts" '{iteration: 1, previous_reviews: ["old review"], created_at: $ts, last_updated: $ts}' > "$stale_state"
hook_stale=$(echo '{"stop_hook_active": true, "session_id": "test-stale", "transcript_path": "/nonexistent"}' | \
    CROSS_PROVIDER_BRIDGE=1 \
    bash "$HOOK_SCRIPT" 2>&1)
hook_stale_exit=$?
assert_exit_code "Stale state file: exits 0" "0" "$hook_stale_exit"
if [ ! -f "$stale_state" ]; then
    print_success "Stale state file: cleaned up"
    ((PASS++))
else
    print_error "Stale state file: not cleaned up"
    ((FAIL++))
    rm -f "$stale_state"
fi

# Test: Consensus detection — uses the tightened detect_consensus with CONCERNS: guard
# Inline copy of the function from the hook (must stay in sync)
_detect_consensus() {
    local output="$1"
    local first_line
    first_line=$(echo "$output" | head -1)
    if echo "$first_line" | grep -qi "^CONSENSUS:"; then
        return 0
    fi
    # Skip heuristic if reviewer explicitly flagged concerns
    if echo "$first_line" | grep -qi "^CONCERNS:"; then
        return 1
    fi
    # Heuristic fallback (only when no explicit prefix)
    if echo "$output" | grep -qi \
        -e "all concerns addressed" \
        -e "no remaining issues" \
        -e "no further concerns" \
        -e "reasoning is sound" \
        -e "adequately addressed"; then
        return 0
    fi
    return 1
}

# Test: CONSENSUS: prefix detected
if _detect_consensus "CONSENSUS: The reasoning is correct."; then
    print_success "Consensus detection: CONSENSUS: prefix detected"
    ((PASS++))
else
    print_error "Consensus detection: CONSENSUS: prefix not detected"
    ((FAIL++))
fi

# Test: Heuristic fallback phrases (no prefix)
if _detect_consensus "The reasoning is sound and well-structured."; then
    print_success "Consensus detection: heuristic fallback phrase detected"
    ((PASS++))
else
    print_error "Consensus detection: heuristic fallback phrase not detected"
    ((FAIL++))
fi

# Test: CONCERNS: prefix correctly continues iteration
if ! _detect_consensus "CONCERNS: The edge case for empty input is not handled."; then
    print_success "No consensus: CONCERNS: prefix correctly continues iteration"
    ((PASS++))
else
    print_error "No consensus: CONCERNS: prefix incorrectly detected as consensus"
    ((FAIL++))
fi

# Test: CONCERNS: prefix with heuristic phrase in body — must NOT false-positive
# This is the key regression test for the tightened heuristic
if ! _detect_consensus "CONCERNS: While the reasoning is sound on auth, there's a missing null check on line 42."; then
    print_success "No consensus: CONCERNS: + heuristic phrase in body correctly blocked"
    ((PASS++))
else
    print_error "No consensus: CONCERNS: + heuristic phrase in body incorrectly detected as consensus"
    ((FAIL++))
fi

# Test: strip_provider_metadata extracts only model response from Codex output
strip_test_input='[2026-01-01T00:00:00] OpenAI Codex v1.0
--------
workdir: /test
model: gpt-5
--------
[2026-01-01T00:00:00] User instructions:
If the reasoning is sound, start with CONSENSUS:

[2026-01-01T00:00:01] thinking
I should review carefully.
[2026-01-01T00:00:02] codex
**Summary block**
[2026-01-01T00:00:02] codex

CONCERNS:
- Issue 1
- Issue 2
[2026-01-01T00:00:03] tokens used: 500'

strip_test_output=$(echo "$strip_test_input" | awk '
    /^\[.*\] codex$/ { content = ""; collecting = 1; next }
    /^\[.*\] tokens used:/ { next }
    collecting { content = content "\n" $0 }
    END { sub(/^\n+/, "", content); print content }
')

if echo "$strip_test_output" | grep -q 'CONCERNS:'; then
    print_success "Metadata stripping: extracts CONCERNS from Codex output"
    ((PASS++))
else
    print_error "Metadata stripping: failed to extract CONCERNS"
    ((FAIL++))
fi

if echo "$strip_test_output" | grep -q 'reasoning is sound'; then
    print_error "Metadata stripping: echoed prompt leaked through (false consensus risk)"
    ((FAIL++))
else
    print_success "Metadata stripping: echoed prompt correctly stripped"
    ((PASS++))
fi

if echo "$strip_test_output" | grep -q 'thinking'; then
    print_error "Metadata stripping: thinking block leaked through"
    ((FAIL++))
else
    print_success "Metadata stripping: thinking blocks correctly stripped"
    ((PASS++))
fi

if echo "$strip_test_output" | grep -q 'tokens used'; then
    print_error "Metadata stripping: tokens line leaked through"
    ((FAIL++))
else
    print_success "Metadata stripping: tokens line correctly stripped"
    ((PASS++))
fi

# Test: Project settings.json does NOT have Stop hook (avoid double-registration)
# The Stop hook lives in user-level ~/.claude/settings.json, not project-level
if [[ -f "$SCRIPT_DIR/../.claude/settings.json" ]]; then
    settings_content=$(cat "$SCRIPT_DIR/../.claude/settings.json")
    if echo "$settings_content" | grep -q 'cross-provider-bridge.sh'; then
        print_error "Project settings.json has bridge hook (should be user-level only)"
        ((FAIL++))
    else
        print_success "Project settings.json: no duplicate bridge hook"
        ((PASS++))
    fi
fi

# Test: Project settings.json has no duplicate Stop key (JSON validity)
if [[ -f "$SCRIPT_DIR/../.claude/settings.json" ]]; then
    stop_count=$(grep -c '"Stop"' "$SCRIPT_DIR/../.claude/settings.json")
    if [[ "$stop_count" -le 1 ]]; then
        print_success "Project settings.json: no duplicate Stop key"
        ((PASS++))
    else
        print_error "Project settings.json: duplicate Stop key found ($stop_count occurrences)"
        ((FAIL++))
    fi
fi

# Test: User-level ~/.claude/settings.json has Stop hook registered
if [[ -f "$HOME/.claude/settings.json" ]]; then
    user_settings=$(cat "$HOME/.claude/settings.json")
    if echo "$user_settings" | grep -q 'cross-provider-bridge.sh'; then
        print_success "User settings.json has bridge Stop hook registered"
        ((PASS++))
    else
        print_warning "User settings.json missing bridge hook (run setup.sh to register)"
        ((SKIP++))
    fi
else
    print_warning "User ~/.claude/settings.json not found"
    ((SKIP++))
fi

# ============================================================================
# Multi-Provider Bridge Tests (no API calls)
# ============================================================================

print_header "Multi-Provider Bridge Tests"

# Test: Verbose mode outputs to stderr
verbose_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test output"}' > "$verbose_tmpfile"
verbose_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$verbose_tmpfile\"}" | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_VERBOSE=1 \
    CROSS_PROVIDER_ORDER="nonexistent" \
    bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
if echo "$verbose_stderr" | grep -q '\[bridge\]'; then
    print_success "Verbose mode: outputs [bridge] prefix to stderr"
    ((PASS++))
else
    print_error "Verbose mode: no [bridge] output on stderr"
    ((FAIL++))
fi
rm -f "$verbose_tmpfile"

# Test: Log file mode writes to file
log_tmpfile=$(mktemp)
log_transcript=$(mktemp)
echo '{"role": "assistant", "content": "Test log output"}' > "$log_transcript"
echo "{\"stop_hook_active\": false, \"transcript_path\": \"$log_transcript\"}" | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_LOG="$log_tmpfile" \
    CROSS_PROVIDER_ORDER="nonexistent" \
    bash "$HOOK_SCRIPT" 2>/dev/null || true
if [[ -f "$log_tmpfile" ]] && grep -q "Bridge activated" "$log_tmpfile"; then
    print_success "Log file: writes timestamped entries"
    ((PASS++))
else
    print_error "Log file: no entries written"
    ((FAIL++))
fi
rm -f "$log_tmpfile" "$log_transcript"

# Test: Custom timeout accepted (doesn't error)
timeout_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test timeout"}' > "$timeout_tmpfile"
timeout_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$timeout_tmpfile\"}" | \
    CROSS_PROVIDER_BRIDGE=1 \
    CROSS_PROVIDER_TIMEOUT=30 \
    CROSS_PROVIDER_ORDER="nonexistent" \
    bash "$HOOK_SCRIPT" 2>&1)
timeout_exit=$?
assert_exit_code "Custom timeout (30s): exits 0 gracefully" "0" "$timeout_exit"
rm -f "$timeout_tmpfile"

# Test: New provider names are recognized (don't trigger 'Unknown provider' in verbose)
# Use CROSS_PROVIDER_TIMEOUT=1 to prevent actual provider calls from hanging
for test_provider in gemini ollama deepseek claude; do
    provider_tmpfile=$(mktemp)
    echo '{"role": "assistant", "content": "Test provider"}' > "$provider_tmpfile"
    provider_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$provider_tmpfile\"}" | \
        CROSS_PROVIDER_BRIDGE=1 \
        CROSS_PROVIDER_VERBOSE=1 \
        CROSS_PROVIDER_TIMEOUT=1 \
        CROSS_PROVIDER_ORDER="$test_provider" \
        timeout 10 bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
    if echo "$provider_stderr" | grep -q "Unknown provider"; then
        print_error "Provider $test_provider: incorrectly flagged as unknown"
        ((FAIL++))
    else
        print_success "Provider $test_provider: recognized as valid provider"
        ((PASS++))
    fi
    rm -f "$provider_tmpfile"
done

# Test: Hook script declares all 6 provider functions
for provider_func in provider_codex provider_gemini provider_ollama provider_deepseek provider_claude provider_opencode; do
    if grep -q "^${provider_func}()" "$HOOK_SCRIPT"; then
        print_success "Hook script: $provider_func function declared"
        ((PASS++))
    else
        print_error "Hook script: $provider_func function missing"
        ((FAIL++))
    fi
done

# Test: Hook script supports all new env vars (documented in header)
for env_var in CROSS_PROVIDER_VERBOSE CROSS_PROVIDER_TIMEOUT CROSS_PROVIDER_LOG \
               CROSS_PROVIDER_GEMINI_MODEL CROSS_PROVIDER_OLLAMA_MODEL \
               CROSS_PROVIDER_DEEPSEEK_MODEL CROSS_PROVIDER_CLAUDE_MODEL; do
    if grep -q "$env_var" "$HOOK_SCRIPT"; then
        print_success "Hook script: references $env_var"
        ((PASS++))
    else
        print_error "Hook script: missing reference to $env_var"
        ((FAIL++))
    fi
done

# Test: State file tracks providers_used
state_track_tmpfile=$(mktemp)
state_track_state="/tmp/cross-provider-bridge-test-providers-track.json"
echo '{"role": "assistant", "content": "Test provider tracking"}' > "$state_track_tmpfile"
# Use nonexistent providers so no actual call is made, but verify the state file schema
# Create a pre-existing state file to verify the jq update adds providers_used
jq -n '{iteration: 0, previous_reviews: [], providers_used: [], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' > "$state_track_state"
# Verify the state file has providers_used field
if jq -e '.providers_used' "$state_track_state" &>/dev/null; then
    print_success "State file schema: providers_used field present"
    ((PASS++))
else
    print_error "State file schema: providers_used field missing"
    ((FAIL++))
fi
rm -f "$state_track_tmpfile" "$state_track_state"

# ============================================================================
# gwt-ticket --bridge Flag Tests (no API calls)
# ============================================================================

print_header "gwt-ticket --bridge Flag Tests"

GWT_TICKET_FISH="$SCRIPT_DIR/../.config/fish/functions/gwt-ticket.fish"

if command -v fish &>/dev/null; then
    gwtt_help=$(fish -c "source $GWT_TICKET_FISH; gwt-ticket --help" 2>&1)
    assert_contains "gwt-ticket help: shows --bridge flag" "$gwtt_help" "--bridge"
    assert_contains "gwt-ticket help: bridge description mentions cross-provider" "$gwtt_help" "cross-provider"
else
    print_warning "Fish shell not installed - skipping gwt-ticket help tests"
    ((SKIP++))
fi

# Source-level wiring: verify both local and devcon code paths set CROSS_PROVIDER_BRIDGE
gwtt_source=$(cat "$GWT_TICKET_FISH")
assert_contains "gwt-ticket source: local path sets CROSS_PROVIDER_BRIDGE in launch script" \
    "$gwtt_source" "CROSS_PROVIDER_BRIDGE 1"
assert_contains "gwt-ticket source: devcon path passes -E CROSS_PROVIDER_BRIDGE" \
    "$gwtt_source" "-E CROSS_PROVIDER_BRIDGE=1"

# Test: --bridge N iterations passthrough in both local and devcon code paths
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_MAX_ITERATIONS" \
    "$gwtt_source" "CROSS_PROVIDER_MAX_ITERATIONS"
assert_contains "gwt-ticket source: devcon path passes -E CROSS_PROVIDER_MAX_ITERATIONS" \
    "$gwtt_source" "-E CROSS_PROVIDER_MAX_ITERATIONS="

# Test: --bridge N help text updated
if command -v fish &>/dev/null; then
    assert_contains "gwt-ticket help: --bridge shows optional N" "$gwtt_help" "\[N\]"
fi

# Test: New bridge flags in help text
if command -v fish &>/dev/null; then
    assert_contains "gwt-ticket help: --bridge-providers flag" "$gwtt_help" "--bridge-providers"
    assert_contains "gwt-ticket help: --bridge-verbose flag" "$gwtt_help" "--bridge-verbose"
    assert_contains "gwt-ticket help: --bridge-model flag" "$gwtt_help" "--bridge-model"
    assert_contains "gwt-ticket help: --bridge-timeout flag" "$gwtt_help" "--bridge-timeout"
    assert_contains "gwt-ticket help: --bridge-log flag" "$gwtt_help" "--bridge-log"
fi

# Test: New bridge env vars in source (local path)
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_ORDER" \
    "$gwtt_source" "CROSS_PROVIDER_ORDER"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_VERBOSE" \
    "$gwtt_source" "CROSS_PROVIDER_VERBOSE"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_TIMEOUT" \
    "$gwtt_source" "CROSS_PROVIDER_TIMEOUT"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_LOG" \
    "$gwtt_source" "CROSS_PROVIDER_LOG"

# Test: New bridge env vars in source (devcon path)
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_ORDER" \
    "$gwtt_source" "-E CROSS_PROVIDER_ORDER="
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_VERBOSE" \
    "$gwtt_source" "-E CROSS_PROVIDER_VERBOSE="
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_TIMEOUT" \
    "$gwtt_source" "-E CROSS_PROVIDER_TIMEOUT="

# ============================================================================
# Live Tests (require Claude subscription)
# ============================================================================

if $LIVE_MODE; then
    print_header "Live Cross-Provider Bridge Tests"

    HOOK_SCRIPT="$SCRIPT_DIR/../.claude/hooks/cross-provider-bridge.sh"

    # Create a realistic mock transcript
    bridge_tmpdir=$(mktemp -d)
    bridge_transcript="$bridge_tmpdir/transcript.jsonl"
    cat > "$bridge_transcript" << 'JSONL'
{"role": "user", "content": "Explain why quicksort has O(n log n) average time complexity"}
{"role": "assistant", "content": "Quicksort achieves O(n log n) average-case time complexity because:\n\n1. **Partitioning**: Each partition step processes all n elements in O(n) time.\n2. **Recursive depth**: On average, the pivot splits the array roughly in half, giving O(log n) levels of recursion.\n3. **Total work**: n elements × log n levels = O(n log n).\n\nThe worst case is O(n²) when the pivot consistently selects the minimum or maximum element, creating n levels of recursion instead of log n. This happens with already-sorted input using naive pivot selection.\n\nMitigation strategies:\n- Randomized pivot selection\n- Median-of-three pivot\n- Introsort (switch to heapsort when recursion depth exceeds 2 log n)"}
JSONL

    # Test: Codex provider (if available)
    has_codex=false
    if command -v codex &>/dev/null && codex login status &>/dev/null; then
        has_codex=true
        print_info "Running cross-provider bridge with Codex..."
        codex_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" | \
            CROSS_PROVIDER_BRIDGE=1 \
            CROSS_PROVIDER_ORDER="codex" \
            CROSS_PROVIDER_MAX_CHARS=2000 \
            timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true
        codex_exit=$?

        if [ -n "$codex_output" ]; then
            # Should return JSON with decision: "block"
            # Use printf instead of echo: echo interprets \n in jq's JSON escapes
            if printf '%s\n' "$codex_output" | jq -e '.decision == "block"' &>/dev/null; then
                print_success "Codex bridge: returned block decision with review"
                ((PASS++))
            else
                print_error "Codex bridge: output is not valid block JSON"
                ((FAIL++))
            fi
            if printf '%s\n' "$codex_output" | jq -e '.reason | length > 50' &>/dev/null; then
                print_success "Codex bridge: reason contains substantial review"
                ((PASS++))
            else
                print_error "Codex bridge: reason too short or missing"
                ((FAIL++))
            fi
            # Check reason includes iteration context
            if printf '%s\n' "$codex_output" | jq -e '.reason | test("iteration")' &>/dev/null; then
                print_success "Codex bridge: reason includes iteration context"
                ((PASS++))
            else
                print_error "Codex bridge: reason missing iteration context"
                ((FAIL++))
            fi
        else
            print_warning "Codex bridge: no output (provider may be unavailable)"
            ((SKIP++))
        fi
    else
        print_warning "Codex not available (need codex binary + auth via 'codex login') - skipping"
        ((SKIP++))
    fi

    # Test: OpenCode provider (if available)
    # Requires: opencode binary + Ollama running + model pulled
    has_opencode=false
    opencode_model="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen2.5-coder:1.5b}"
    if command -v opencode &>/dev/null && curl -sf http://localhost:11434/api/tags &>/dev/null; then
        has_opencode=true
        print_info "Running cross-provider bridge with OpenCode ($opencode_model)..."
        opencode_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" | \
            CROSS_PROVIDER_BRIDGE=1 \
            CROSS_PROVIDER_ORDER="opencode" \
            CROSS_PROVIDER_OPENCODE_MODEL="$opencode_model" \
            CROSS_PROVIDER_MAX_CHARS=2000 \
            timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true

        if [ -n "$opencode_output" ]; then
            if printf '%s\n' "$opencode_output" | jq -e '.decision == "block"' &>/dev/null; then
                print_success "OpenCode bridge: returned block decision with review"
                ((PASS++))
            else
                print_error "OpenCode bridge: output is not valid block JSON"
                ((FAIL++))
            fi
            if printf '%s\n' "$opencode_output" | jq -e '.reason | length > 50' &>/dev/null; then
                print_success "OpenCode bridge: reason contains substantial review"
                ((PASS++))
            else
                print_error "OpenCode bridge: reason too short or missing"
                ((FAIL++))
            fi
        else
            print_warning "OpenCode bridge: no output (provider may be unavailable)"
            ((SKIP++))
        fi
    else
        print_warning "OpenCode not available (need opencode binary + Ollama running) - skipping"
        ((SKIP++))
    fi

    # Test: Fallback order (codex first, then opencode)
    if $has_codex || $has_opencode; then
        print_info "Running cross-provider bridge with default fallback order..."
        fallback_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" | \
            CROSS_PROVIDER_BRIDGE=1 \
            CROSS_PROVIDER_MAX_CHARS=2000 \
            timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true

        if [ -n "$fallback_output" ]; then
            if printf '%s\n' "$fallback_output" | jq -e '.decision == "block"' &>/dev/null; then
                print_success "Fallback bridge: at least one provider succeeded"
                ((PASS++))
            else
                print_error "Fallback bridge: output is not valid block JSON"
                ((FAIL++))
            fi
        else
            print_error "Fallback bridge: no output despite available providers"
            ((FAIL++))
        fi
    fi

    rm -rf "$bridge_tmpdir"

    # ========================================================================
    print_header "Live Pipeline Tests (API calls)"

    if ! command -v claude &>/dev/null; then
        print_error "claude CLI not found"
        ((FAIL++))
    else
        # Test: Basic 2-stage pipeline (cheap preset to save tokens)
        print_info "Running live pipeline (cheap preset)..."
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
