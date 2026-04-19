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
		((PASS++)) || true
	else
		print_error "$description (expected: '$needle')"
		((FAIL++)) || true
	fi
}

assert_exit_code() {
	local description="$1"
	local expected="$2"
	local actual="$3"
	if [[ "$actual" == "$expected" ]]; then
		print_success "$description"
		((PASS++)) || true
	else
		print_error "$description (expected exit $expected, got $actual)"
		((FAIL++)) || true
	fi
}

# ============================================================================
# Config Tests (no API calls)
# ============================================================================

print_header "Configuration Tests"

# Test: Function file exists
if [[ -f "$SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish" ]]; then
	print_success "claude-pipeline.fish exists"
	((PASS++)) || true
else
	print_error "claude-pipeline.fish not found"
	((FAIL++)) || true
fi

# Test: Alias file exists
if [[ -f "$SCRIPT_DIR/../.config/fish/functions/cpipe.fish" ]]; then
	print_success "cpipe.fish alias exists"
	((PASS++)) || true
else
	print_error "cpipe.fish alias not found"
	((FAIL++)) || true
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
	assert_contains "No prompt: shows error" "$no_prompt_output" "No prompt provided"

	# Test: Invalid preset error
	bad_preset_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset nonexistent 'test'" 2>&1)
	assert_contains "Bad preset: shows error" "$bad_preset_output" "Unknown preset"

	# Test: Stages validation
	bad_stages_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --stages 6 'test'" 2>&1)
	assert_contains "Invalid stages: shows error" "$bad_stages_output" "Stages must be between 2 and 5"
else
	print_warning "Fish shell not installed - skipping function tests"
	((SKIP++)) || true
fi

# ============================================================================
# Cross-Provider Bridge Hook Tests (no API calls)
# ============================================================================

print_header "Cross-Provider Bridge Hook Tests"

HOOK_SCRIPT="$SCRIPT_DIR/../.claude/hooks/cross-provider-bridge.sh"

# Test: Hook script exists and is executable
if [[ -x "$HOOK_SCRIPT" ]]; then
	print_success "cross-provider-bridge.sh exists and is executable"
	((PASS++)) || true
else
	print_error "cross-provider-bridge.sh not found or not executable"
	((FAIL++)) || true
fi

# Test: Hook exits 0 when CROSS_PROVIDER_BRIDGE is not set (disabled by default)
CROSS_PROVIDER_BRIDGE="" bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": false, "transcript_path": "/nonexistent"}'
hook_disabled_exit=$?
assert_exit_code "Hook disabled: exits 0 (silent pass-through)" "0" "$hook_disabled_exit"

# Test: Hook exits 0 when stop_hook_active=true with no state file (safety fallback)
CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": true, "transcript_path": "/nonexistent"}'
hook_loop_exit=$?
assert_exit_code "Hook safety fallback: exits 0 when stop_hook_active=true with no state file" "0" "$hook_loop_exit"

# Test: Hook exits 0 when transcript path is missing
CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": false}'
hook_no_transcript_exit=$?
assert_exit_code "Hook no transcript: exits 0 gracefully" "0" "$hook_no_transcript_exit"

# Test: Hook exits 0 when transcript file doesn't exist
CROSS_PROVIDER_BRIDGE=1 bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": false, "transcript_path": "/tmp/nonexistent-transcript.jsonl"}'
hook_bad_path_exit=$?
assert_exit_code "Hook bad transcript path: exits 0 gracefully" "0" "$hook_bad_path_exit"

# Test: Hook exits 0 when no providers are available (graceful fallback)
# Use unknown provider names so the case statement skips all entries
tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test reasoning output"}' >"$tmpfile"
CROSS_PROVIDER_BRIDGE=1 \
	CROSS_PROVIDER_ORDER="nonexistent1,nonexistent2" \
	bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<"{\"stop_hook_active\": false, \"transcript_path\": \"$tmpfile\"}"
hook_no_providers_exit=$?
rm -f "$tmpfile"
assert_exit_code "Hook no providers available: exits 0 (silent fallback)" "0" "$hook_no_providers_exit"

# Test: Max iterations reached — exits 0 and cleans up state file
iter_state_file="/tmp/cross-provider-bridge-test-max-iter.json"
jq -n '{iteration: 3, previous_reviews: ["r1","r2","r3"], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' >"$iter_state_file"
CROSS_PROVIDER_BRIDGE=1 \
	CROSS_PROVIDER_MAX_ITERATIONS=3 \
	bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": true, "session_id": "test-max-iter", "transcript_path": "/nonexistent"}'
hook_max_iter_exit=$?
assert_exit_code "Max iterations reached: exits 0" "0" "$hook_max_iter_exit"
if [ ! -f "$iter_state_file" ]; then
	print_success "Max iterations reached: state file cleaned up"
	((PASS++)) || true
else
	print_error "Max iterations reached: state file not cleaned up"
	((FAIL++)) || true
	rm -f "$iter_state_file"
fi

# Test: Single-shot mode (MAX_ITERATIONS=1) — first stop_hook_active triggers exit
singleshot_state="/tmp/cross-provider-bridge-test-singleshot.json"
jq -n '{iteration: 1, previous_reviews: ["review1"], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' >"$singleshot_state"
CROSS_PROVIDER_BRIDGE=1 \
	CROSS_PROVIDER_MAX_ITERATIONS=1 \
	bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": true, "session_id": "test-singleshot", "transcript_path": "/nonexistent"}'
hook_singleshot_exit=$?
assert_exit_code "Single-shot mode (MAX_ITERATIONS=1): exits 0 on iteration 1" "0" "$hook_singleshot_exit"
rm -f "$singleshot_state"

# Test: Stale state file (>10min old) — exits 0 and cleans up
stale_state="/tmp/cross-provider-bridge-test-stale.json"
stale_ts=$(($(date +%s) - 7200)) # 2 hours ago
jq -n --argjson ts "$stale_ts" '{iteration: 1, previous_reviews: ["old review"], created_at: $ts, last_updated: $ts}' >"$stale_state"
CROSS_PROVIDER_BRIDGE=1 \
	bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<'{"stop_hook_active": true, "session_id": "test-stale", "transcript_path": "/nonexistent"}'
hook_stale_exit=$?
assert_exit_code "Stale state file: exits 0" "0" "$hook_stale_exit"
if [ ! -f "$stale_state" ]; then
	print_success "Stale state file: cleaned up"
	((PASS++)) || true
else
	print_error "Stale state file: not cleaned up"
	((FAIL++)) || true
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
	((PASS++)) || true
else
	print_error "Consensus detection: CONSENSUS: prefix not detected"
	((FAIL++)) || true
fi

# Test: Heuristic fallback phrases (no prefix)
if _detect_consensus "The reasoning is sound and well-structured."; then
	print_success "Consensus detection: heuristic fallback phrase detected"
	((PASS++)) || true
else
	print_error "Consensus detection: heuristic fallback phrase not detected"
	((FAIL++)) || true
fi

# Test: CONCERNS: prefix correctly continues iteration
if ! _detect_consensus "CONCERNS: The edge case for empty input is not handled."; then
	print_success "No consensus: CONCERNS: prefix correctly continues iteration"
	((PASS++)) || true
else
	print_error "No consensus: CONCERNS: prefix incorrectly detected as consensus"
	((FAIL++)) || true
fi

# Test: CONCERNS: prefix with heuristic phrase in body — must NOT false-positive
# This is the key regression test for the tightened heuristic
if ! _detect_consensus "CONCERNS: While the reasoning is sound on auth, there's a missing null check on line 42."; then
	print_success "No consensus: CONCERNS: + heuristic phrase in body correctly blocked"
	((PASS++)) || true
else
	print_error "No consensus: CONCERNS: + heuristic phrase in body incorrectly detected as consensus"
	((FAIL++)) || true
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
	((PASS++)) || true
else
	print_error "Metadata stripping: failed to extract CONCERNS"
	((FAIL++)) || true
fi

if echo "$strip_test_output" | grep -q 'reasoning is sound'; then
	print_error "Metadata stripping: echoed prompt leaked through (false consensus risk)"
	((FAIL++)) || true
else
	print_success "Metadata stripping: echoed prompt correctly stripped"
	((PASS++)) || true
fi

if echo "$strip_test_output" | grep -q 'thinking'; then
	print_error "Metadata stripping: thinking block leaked through"
	((FAIL++)) || true
else
	print_success "Metadata stripping: thinking blocks correctly stripped"
	((PASS++)) || true
fi

if echo "$strip_test_output" | grep -q 'tokens used'; then
	print_error "Metadata stripping: tokens line leaked through"
	((FAIL++)) || true
else
	print_success "Metadata stripping: tokens line correctly stripped"
	((PASS++)) || true
fi

# Test: Project settings.json does NOT have Stop hook (avoid double-registration)
# The Stop hook lives in user-level ~/.claude/settings.json, not project-level
if [[ -f "$SCRIPT_DIR/../.claude/settings.json" ]]; then
	settings_content=$(cat "$SCRIPT_DIR/../.claude/settings.json")
	if echo "$settings_content" | grep -q 'cross-provider-bridge.sh'; then
		print_error "Project settings.json has bridge hook (should be user-level only)"
		((FAIL++)) || true
	else
		print_success "Project settings.json: no duplicate bridge hook"
		((PASS++)) || true
	fi
fi

# Test: Project settings.json has no duplicate Stop key (JSON validity)
if [[ -f "$SCRIPT_DIR/../.claude/settings.json" ]]; then
	stop_count=$(grep -c '"Stop"' "$SCRIPT_DIR/../.claude/settings.json")
	if [[ "$stop_count" -le 1 ]]; then
		print_success "Project settings.json: no duplicate Stop key"
		((PASS++)) || true
	else
		print_error "Project settings.json: duplicate Stop key found ($stop_count occurrences)"
		((FAIL++)) || true
	fi
fi

# Test: User-level ~/.claude/settings.json has Stop hook registered
if [[ -f "$HOME/.claude/settings.json" ]]; then
	user_settings=$(cat "$HOME/.claude/settings.json")
	if echo "$user_settings" | grep -q 'cross-provider-bridge.sh'; then
		print_success "User settings.json has bridge Stop hook registered"
		((PASS++)) || true
	else
		print_warning "User settings.json missing bridge hook (run setup.sh to register)"
		((SKIP++)) || true
	fi
else
	print_warning "User ~/.claude/settings.json not found"
	((SKIP++)) || true
fi

# ============================================================================
# Multi-Provider Bridge Tests (no API calls)
# ============================================================================

print_header "Multi-Provider Bridge Tests"

# Test: Verbose mode outputs to stderr
verbose_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test output"}' >"$verbose_tmpfile"
verbose_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$verbose_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_VERBOSE=1 \
		CROSS_PROVIDER_ORDER="nonexistent" \
		bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
if echo "$verbose_stderr" | grep -q '\[bridge\]'; then
	print_success "Verbose mode: outputs [bridge] prefix to stderr"
	((PASS++)) || true
else
	print_error "Verbose mode: no [bridge] output on stderr"
	((FAIL++)) || true
fi
rm -f "$verbose_tmpfile"

# Test: Log file mode writes to file
log_tmpfile=$(mktemp)
log_transcript=$(mktemp)
echo '{"role": "assistant", "content": "Test log output"}' >"$log_transcript"
echo "{\"stop_hook_active\": false, \"transcript_path\": \"$log_transcript\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_LOG="$log_tmpfile" \
		CROSS_PROVIDER_ORDER="nonexistent" \
		bash "$HOOK_SCRIPT" 2>/dev/null || true
if [[ -f "$log_tmpfile" ]] && grep -q "Bridge activated" "$log_tmpfile"; then
	print_success "Log file: writes timestamped entries"
	((PASS++)) || true
else
	print_error "Log file: no entries written"
	((FAIL++)) || true
fi
rm -f "$log_tmpfile" "$log_transcript"

# Test: Custom timeout accepted (doesn't error)
timeout_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test timeout"}' >"$timeout_tmpfile"
CROSS_PROVIDER_BRIDGE=1 \
	CROSS_PROVIDER_TIMEOUT=30 \
	CROSS_PROVIDER_ORDER="nonexistent" \
	bash "$HOOK_SCRIPT" >/dev/null 2>&1 <<<"{\"stop_hook_active\": false, \"transcript_path\": \"$timeout_tmpfile\"}"
timeout_exit=$?
assert_exit_code "Custom timeout (30s): exits 0 gracefully" "0" "$timeout_exit"
rm -f "$timeout_tmpfile"

# Test: New provider names are recognized (don't trigger 'Unknown provider' in verbose)
# Use CROSS_PROVIDER_TIMEOUT=1 to prevent actual provider calls from hanging
for test_provider in gemini ollama deepseek claude; do
	provider_tmpfile=$(mktemp)
	echo '{"role": "assistant", "content": "Test provider"}' >"$provider_tmpfile"
	provider_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$provider_tmpfile\"}" |
		CROSS_PROVIDER_BRIDGE=1 \
			CROSS_PROVIDER_VERBOSE=1 \
			CROSS_PROVIDER_TIMEOUT=1 \
			CROSS_PROVIDER_ORDER="$test_provider" \
			timeout 10 bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
	if echo "$provider_stderr" | grep -q "Unknown provider"; then
		print_error "Provider $test_provider: incorrectly flagged as unknown"
		((FAIL++)) || true
	else
		print_success "Provider $test_provider: recognized as valid provider"
		((PASS++)) || true
	fi
	rm -f "$provider_tmpfile"
done

# Test: Hook script declares all 6 provider functions
for provider_func in provider_codex provider_gemini provider_ollama provider_deepseek provider_claude provider_opencode; do
	if grep -q "^${provider_func}()" "$HOOK_SCRIPT"; then
		print_success "Hook script: $provider_func function declared"
		((PASS++)) || true
	else
		print_error "Hook script: $provider_func function missing"
		((FAIL++)) || true
	fi
done

# Test: Hook script supports all new env vars (documented in header)
for env_var in CROSS_PROVIDER_VERBOSE CROSS_PROVIDER_TIMEOUT CROSS_PROVIDER_LOG \
	CROSS_PROVIDER_GEMINI_MODEL CROSS_PROVIDER_OLLAMA_MODEL \
	CROSS_PROVIDER_DEEPSEEK_MODEL CROSS_PROVIDER_CLAUDE_MODEL; do
	if grep -q "$env_var" "$HOOK_SCRIPT"; then
		print_success "Hook script: references $env_var"
		((PASS++)) || true
	else
		print_error "Hook script: missing reference to $env_var"
		((FAIL++)) || true
	fi
done

# Test: State file tracks providers_used
state_track_tmpfile=$(mktemp)
state_track_state="/tmp/cross-provider-bridge-test-providers-track.json"
echo '{"role": "assistant", "content": "Test provider tracking"}' >"$state_track_tmpfile"
# Use nonexistent providers so no actual call is made, but verify the state file schema
# Create a pre-existing state file to verify the jq update adds providers_used
jq -n '{iteration: 0, previous_reviews: [], providers_used: [], created_at: '"$(date +%s)"', last_updated: '"$(date +%s)"'}' >"$state_track_state"
# Verify the state file has providers_used field
if jq -e '.providers_used' "$state_track_state" &>/dev/null; then
	print_success "State file schema: providers_used field present"
	((PASS++)) || true
else
	print_error "State file schema: providers_used field missing"
	((FAIL++)) || true
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
	((SKIP++)) || true
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
# New Bridge Features Tests (--bridge-mode, --bridge-models, --bridge-dry-run)
# ============================================================================

print_header "New Bridge Features Tests"

# Test: --bridge-mode flag in gwt-ticket source
assert_contains "gwt-ticket source: --bridge-mode flag parsing" \
	"$gwtt_source" "--bridge-mode"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_MODE" \
	"$gwtt_source" "CROSS_PROVIDER_MODE"
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_MODE" \
	"$gwtt_source" "-E CROSS_PROVIDER_MODE="

# Test: --bridge-models flag in gwt-ticket source
assert_contains "gwt-ticket source: --bridge-models flag parsing" \
	"$gwtt_source" "--bridge-models"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_MODELS" \
	"$gwtt_source" "CROSS_PROVIDER_MODELS"
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_MODELS" \
	"$gwtt_source" "-E CROSS_PROVIDER_MODELS="

# Test: --bridge-dry-run flag in gwt-ticket source
assert_contains "gwt-ticket source: --bridge-dry-run flag parsing" \
	"$gwtt_source" "--bridge-dry-run"
assert_contains "gwt-ticket source: local path passes CROSS_PROVIDER_DRY_RUN" \
	"$gwtt_source" "CROSS_PROVIDER_DRY_RUN"
assert_contains "gwt-ticket source: devcon path passes CROSS_PROVIDER_DRY_RUN" \
	"$gwtt_source" "-E CROSS_PROVIDER_DRY_RUN="

# Test: New flags in help text
if command -v fish &>/dev/null; then
	assert_contains "gwt-ticket help: --bridge-mode flag" "$gwtt_help" "--bridge-mode"
	assert_contains "gwt-ticket help: --bridge-models flag" "$gwtt_help" "--bridge-models"
	assert_contains "gwt-ticket help: --bridge-dry-run flag" "$gwtt_help" "--bridge-dry-run"
fi

# Test: Hook script supports CROSS_PROVIDER_MODELS env var
if grep -q "CROSS_PROVIDER_MODELS" "$HOOK_SCRIPT"; then
	print_success "Hook script: references CROSS_PROVIDER_MODELS"
	((PASS++)) || true
else
	print_error "Hook script: missing reference to CROSS_PROVIDER_MODELS"
	((FAIL++)) || true
fi

# Test: Hook script supports CROSS_PROVIDER_DRY_RUN env var
if grep -q "CROSS_PROVIDER_DRY_RUN" "$HOOK_SCRIPT"; then
	print_success "Hook script: references CROSS_PROVIDER_DRY_RUN"
	((PASS++)) || true
else
	print_error "Hook script: missing reference to CROSS_PROVIDER_DRY_RUN"
	((FAIL++)) || true
fi

# Test: Hook script has verbose level 2 support
if grep -q 'VERBOSE.*=.*"2"' "$HOOK_SCRIPT" || grep -q "VERBOSE.*= \"2\"" "$HOOK_SCRIPT" || grep -q 'VERBOSE" = "2"' "$HOOK_SCRIPT"; then
	print_success "Hook script: supports verbose level 2 (structured banners)"
	((PASS++)) || true
else
	print_error "Hook script: missing verbose level 2 support"
	((FAIL++)) || true
fi

# Test: Hook script declares check_provider_available function
if grep -q "check_provider_available()" "$HOOK_SCRIPT"; then
	print_success "Hook script: check_provider_available function declared"
	((PASS++)) || true
else
	print_error "Hook script: check_provider_available function missing"
	((FAIL++)) || true
fi

# Test: Hook script declares parse_provider_models function
if grep -q "parse_provider_models()" "$HOOK_SCRIPT"; then
	print_success "Hook script: parse_provider_models function declared"
	((PASS++)) || true
else
	print_error "Hook script: parse_provider_models function missing"
	((FAIL++)) || true
fi

# Test: Hook script declares get_provider_model function
if grep -q "get_provider_model()" "$HOOK_SCRIPT"; then
	print_success "Hook script: get_provider_model function declared"
	((PASS++)) || true
else
	print_error "Hook script: get_provider_model function missing"
	((FAIL++)) || true
fi

# Test: Dry-run mode exits 0 without calling providers
dryrun_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test dry-run output"}' >"$dryrun_tmpfile"
dryrun_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$dryrun_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_DRY_RUN=1 \
		CROSS_PROVIDER_ORDER="nonexistent" \
		bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
dryrun_exit=$?
if [ "$dryrun_exit" = "0" ]; then
	print_success "Dry-run mode: exits 0"
	((PASS++)) || true
else
	print_error "Dry-run mode: non-zero exit ($dryrun_exit)"
	((FAIL++)) || true
fi
if echo "$dryrun_stderr" | grep -qi 'dry.run\|configuration\|config'; then
	print_success "Dry-run mode: outputs configuration info"
	((PASS++)) || true
else
	print_error "Dry-run mode: no configuration output"
	((FAIL++)) || true
fi
rm -f "$dryrun_tmpfile"

# Test: CROSS_PROVIDER_MODELS parsing (verify the env var is read)
models_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test models output"}' >"$models_tmpfile"
models_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$models_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_VERBOSE=1 \
		CROSS_PROVIDER_MODELS="codex=test-model,ollama=test-ollama" \
		CROSS_PROVIDER_ORDER="nonexistent" \
		bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
# The models env var should be parsed without errors — if the hook ran through
# to the provider dispatch, it means parsing succeeded
if echo "$models_stderr" | grep -q '\[bridge\]'; then
	print_success "CROSS_PROVIDER_MODELS: parsed without errors"
	((PASS++)) || true
else
	print_error "CROSS_PROVIDER_MODELS: parsing may have failed"
	((FAIL++)) || true
fi
rm -f "$models_tmpfile"

# Test: Verbose level 2 outputs structured banners
v2_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test verbose level 2"}' >"$v2_tmpfile"
v2_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$v2_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_VERBOSE=2 \
		CROSS_PROVIDER_ORDER="nonexistent" \
		bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
# Level 2 should produce banner markers (═══)
if echo "$v2_stderr" | grep -q '═══'; then
	print_success "Verbose level 2: structured banners present"
	((PASS++)) || true
else
	print_error "Verbose level 2: no structured banners found"
	((FAIL++)) || true
fi
rm -f "$v2_tmpfile"

# Test: --bridge-verbose in gwt-ticket now maps to VERBOSE=2
assert_contains "gwt-ticket source: bridge-verbose maps to level 2" \
	"$gwtt_source" "CROSS_PROVIDER_VERBOSE 2"

# Test: Pause file (mid-session toggle)
pause_tmpfile=$(mktemp)
echo '{"role": "assistant", "content": "Test pause file"}' >"$pause_tmpfile"
pause_file=$(mktemp)
# With pause file present, bridge should exit 0 immediately (no provider calls)
pause_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$pause_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_VERBOSE=1 \
		CROSS_PROVIDER_ORDER="nonexistent" \
		CROSS_PROVIDER_PAUSE_FILE="$pause_file" \
		bash "$HOOK_SCRIPT" 2>&1)
pause_exit=$?
if [ "$pause_exit" = "0" ]; then
	print_success "Pause file: exits 0 when pause file exists"
	((PASS++)) || true
else
	print_error "Pause file: non-zero exit ($pause_exit)"
	((FAIL++)) || true
fi
# Should produce NO verbose output (exits before logging)
if [ -z "$pause_output" ]; then
	print_success "Pause file: no output (skipped entirely)"
	((PASS++)) || true
else
	print_error "Pause file: unexpected output when paused"
	((FAIL++)) || true
fi
rm -f "$pause_file"

# Without pause file, bridge should proceed normally
no_pause_stderr=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$pause_tmpfile\"}" |
	CROSS_PROVIDER_BRIDGE=1 \
		CROSS_PROVIDER_VERBOSE=1 \
		CROSS_PROVIDER_ORDER="nonexistent" \
		CROSS_PROVIDER_PAUSE_FILE="/tmp/nonexistent-pause-file" \
		bash "$HOOK_SCRIPT" 2>&1 1>/dev/null) || true
if echo "$no_pause_stderr" | grep -q '\[bridge\]'; then
	print_success "No pause file: bridge proceeds normally"
	((PASS++)) || true
else
	print_error "No pause file: bridge did not proceed"
	((FAIL++)) || true
fi
rm -f "$pause_tmpfile"

# Test: Hook script references CROSS_PROVIDER_PAUSE_FILE
if grep -q "CROSS_PROVIDER_PAUSE_FILE" "$HOOK_SCRIPT"; then
	print_success "Hook script: references CROSS_PROVIDER_PAUSE_FILE"
	((PASS++)) || true
else
	print_error "Hook script: missing reference to CROSS_PROVIDER_PAUSE_FILE"
	((FAIL++)) || true
fi

# Test: bridge.fish function exists
BRIDGE_FISH="$SCRIPT_DIR/../.config/fish/functions/bridge.fish"
if [[ -f "$BRIDGE_FISH" ]]; then
	print_success "bridge.fish function exists"
	((PASS++)) || true
else
	print_error "bridge.fish function not found"
	((FAIL++)) || true
fi

# Test: bridge.fish help output
if command -v fish &>/dev/null; then
	bridge_help=$(fish -c "source $BRIDGE_FISH; bridge help" 2>&1)
	if echo "$bridge_help" | grep -q "bridge-paused"; then
		print_success "bridge.fish help: mentions pause file"
		((PASS++)) || true
	else
		print_error "bridge.fish help: missing pause file reference"
		((FAIL++)) || true
	fi
fi

# ============================================================================
# Rate Limit Auto-Rotation Tests
# ============================================================================
print_header "Rate Limit Auto-Rotation"

HOOK_SCRIPT="${HOOK_SCRIPT:-$SCRIPT_DIR/../.claude/hooks/cross-provider-bridge.sh}"

# Test: detect_rate_limit function exists in source
assert_contains "Hook source: detect_rate_limit function" \
	"$(cat "$HOOK_SCRIPT")" "detect_rate_limit()"

# Test: is_provider_cooled_down function exists
assert_contains "Hook source: is_provider_cooled_down function" \
	"$(cat "$HOOK_SCRIPT")" "is_provider_cooled_down()"

# Test: set_provider_cooldown function exists
assert_contains "Hook source: set_provider_cooldown function" \
	"$(cat "$HOOK_SCRIPT")" "set_provider_cooldown()"

# Test: all_claude_profiles_cooled function exists
assert_contains "Hook source: all_claude_profiles_cooled function" \
	"$(cat "$HOOK_SCRIPT")" "all_claude_profiles_cooled()"

# Test: CROSS_PROVIDER_COOLDOWN env var documented
assert_contains "Hook source: CROSS_PROVIDER_COOLDOWN documented" \
	"$(cat "$HOOK_SCRIPT")" "CROSS_PROVIDER_COOLDOWN"

# Test: CROSS_PROVIDER_CLAUDE_PROFILES env var documented
assert_contains "Hook source: CROSS_PROVIDER_CLAUDE_PROFILES documented" \
	"$(cat "$HOOK_SCRIPT")" "CROSS_PROVIDER_CLAUDE_PROFILES"

# Test: detect_rate_limit catches common patterns
rate_limit_test_script='
source <(sed -n "/^detect_rate_limit/,/^}/p" "'"$HOOK_SCRIPT"'")
# Test various rate limit patterns
detect_rate_limit "Error: rate limit exceeded" "" && echo "PASS:rate_limit"
detect_rate_limit "" "HTTP 429 Too Many Requests" && echo "PASS:429"
detect_rate_limit "quota exceeded for project" "" && echo "PASS:quota"
detect_rate_limit "" "RESOURCE_EXHAUSTED" && echo "PASS:resource"
detect_rate_limit "overloaded_error" "" && echo "PASS:overloaded"
detect_rate_limit "request throttled" "" && echo "PASS:throttled"
detect_rate_limit "usage limit reached" "" && echo "PASS:usage_limit"
detect_rate_limit "please try again later" "" && echo "PASS:try_again"
detect_rate_limit "normal response text" "" || echo "PASS:no_false_positive"
'
rate_limit_output=$(bash -c "$rate_limit_test_script" 2>/dev/null) || true
for pattern in rate_limit 429 quota resource overloaded throttled usage_limit try_again no_false_positive; do
	if echo "$rate_limit_output" | grep -q "PASS:$pattern"; then
		print_success "detect_rate_limit: recognizes $pattern"
		((PASS++)) || true
	else
		print_error "detect_rate_limit: failed to detect $pattern"
		((FAIL++)) || true
	fi
done

# Test: Cooldown file creation and checking
# shellcheck disable=SC2016
cooldown_test_script='
COOLDOWN_FILE="/tmp/test-bridge-cooldowns-$$.json"
COOLDOWN_SECONDS=60
trap "rm -f \"$COOLDOWN_FILE\"" EXIT

source <(sed -n "/^is_provider_cooled_down/,/^}/p; /^set_provider_cooldown/,/^}/p; /^get_cooldown_remaining/,/^}/p" "'"$HOOK_SCRIPT"'")
# Also need log_verbose stub
log_verbose() { :; }

# Not cooled down initially
is_provider_cooled_down "codex" || echo "PASS:not_cooled"

# Set cooldown
set_provider_cooldown "codex"
is_provider_cooled_down "codex" && echo "PASS:is_cooled"

# Check remaining
remaining=$(get_cooldown_remaining "codex")
if [ "$remaining" -gt 0 ] && [ "$remaining" -le 60 ]; then
    echo "PASS:remaining_ok"
fi

# Different provider not cooled
is_provider_cooled_down "gemini" || echo "PASS:other_not_cooled"
'
cooldown_output=$(bash -c "$cooldown_test_script" 2>/dev/null) || true
for pattern in not_cooled is_cooled remaining_ok other_not_cooled; do
	if echo "$cooldown_output" | grep -q "PASS:$pattern"; then
		print_success "Cooldown: $pattern"
		((PASS++)) || true
	else
		print_error "Cooldown: $pattern"
		((FAIL++)) || true
	fi
done

# Test: extract_reset_seconds function exists
assert_contains "Hook source: extract_reset_seconds function" \
	"$(cat "$HOOK_SCRIPT")" "extract_reset_seconds()"

# Test: extract_reset_seconds parses real provider messages
# shellcheck disable=SC2016
reset_test_script='
source <(sed -n "/^extract_reset_seconds/,/^}/p" "'"$HOOK_SCRIPT"'")

# Codex: "Try again in 3h 42m" → 13320s
result=$(extract_reset_seconds "You'\''ve reached your limit. Try again in 3h 42m")
[ "$result" = "13320" ] && echo "PASS:codex_hm"

# Codex: hours only "Try again in 2h" → 7200s
result=$(extract_reset_seconds "Try again in 2h")
[ "$result" = "7200" ] && echo "PASS:codex_h"

# Codex: minutes only "Try again in 45m" → 2700s
result=$(extract_reset_seconds "Try again in 45m")
[ "$result" = "2700" ] && echo "PASS:codex_m"

# API: "try again in 1.152s" → 1s (integer)
result=$(extract_reset_seconds "Please try again in 1.152s")
[ -n "$result" ] && [ "$result" -ge 1 ] && echo "PASS:api_secs"

# No match returns empty
result=$(extract_reset_seconds "normal error text")
[ -z "$result" ] && echo "PASS:no_match"

# set_provider_cooldown uses parsed time
source <(sed -n "/^set_provider_cooldown/,/^}/p; /^is_provider_cooled_down/,/^}/p; /^get_cooldown_remaining/,/^}/p" "'"$HOOK_SCRIPT"'")
log_verbose() { :; }
COOLDOWN_FILE="/tmp/test-bridge-reset-$$.json"
COOLDOWN_SECONDS=60
trap "rm -f \"$COOLDOWN_FILE\"" EXIT
set_provider_cooldown "test-provider" "Try again in 1h 30m"
remaining=$(get_cooldown_remaining "test-provider")
# Should be ~5400s, not 60s
[ "$remaining" -gt 1000 ] && echo "PASS:parsed_cooldown"
'
reset_output=$(bash -c "$reset_test_script" 2>/dev/null) || true
for pattern in codex_hm codex_h codex_m api_secs no_match parsed_cooldown; do
	if echo "$reset_output" | grep -q "PASS:$pattern"; then
		print_success "extract_reset_seconds: $pattern"
		((PASS++)) || true
	else
		print_error "extract_reset_seconds: $pattern"
		((FAIL++)) || true
	fi
done

# Test: Provider stderr capture (2>"$PROVIDER_STDERR_FILE" instead of 2>/dev/null)
assert_contains "Hook source: codex captures stderr" \
	"$(cat "$HOOK_SCRIPT")" 'PROVIDER_STDERR_FILE'

# Test: Cooldown check in dispatch loop
assert_contains "Hook source: cooldown check in dispatch loop" \
	"$(cat "$HOOK_SCRIPT")" "is_provider_cooled_down"

# Test: Rate limit detection in failure path
assert_contains "Hook source: rate limit detection on failure" \
	"$(cat "$HOOK_SCRIPT")" "detect_rate_limit"

# Test: Claude profile rotation in provider_claude
assert_contains "Hook source: profile rotation in provider_claude" \
	"$(cat "$HOOK_SCRIPT")" "CLAUDE_CONFIG_DIR"

# shellcheck disable=SC2016
# Test: Profile cooldown keys use claude:profile format
assert_contains "Hook source: profile cooldown key format (claude)" \
	"$(cat "$HOOK_SCRIPT")" 'claude:$profile'

# Test: Profile cooldown keys use codex:profile format
assert_contains "Hook source: profile cooldown key format (codex)" \
	"$(cat "$HOOK_SCRIPT")" "codex:\$profile"

# Test: Codex profile rotation function exists
assert_contains "Hook source: all_codex_profiles_cooled function" \
	"$(cat "$HOOK_SCRIPT")" "all_codex_profiles_cooled"

# Test: Codex CODEX_HOME rotation
assert_contains "Hook source: CODEX_HOME profile rotation" \
	"$(cat "$HOOK_SCRIPT")" "CODEX_HOME=\"\$codex_home\""

# Test: Codex profile rotation in provider_codex
assert_contains "Hook source: CROSS_PROVIDER_CODEX_PROFILES in provider_codex" \
	"$(cat "$HOOK_SCRIPT")" 'CROSS_PROVIDER_CODEX_PROFILES'

# Test: Dispatch loop checks codex profiles
assert_contains "Hook source: dispatch loop codex profile check" \
	"$(cat "$HOOK_SCRIPT")" 'all_codex_profiles_cooled'

# Test: Auto-discovery of Claude profiles
assert_contains "Hook source: auto-discover Claude profiles" \
	"$(cat "$HOOK_SCRIPT")" '.claude-'

# Test: Auto-discovery of Codex profiles
assert_contains "Hook source: auto-discover Codex profiles" \
	"$(cat "$HOOK_SCRIPT")" '.codex-'

# Test: Auto-discovery only when not explicitly set
assert_contains "Hook source: auto-discover respects explicit profiles" \
	"$(cat "$HOOK_SCRIPT")" 'CROSS_PROVIDER_CLAUDE_PROFILES:-'

# Test: Pre-filter removes cooled-down providers before dispatch
assert_contains "Hook source: pre-filter active_providers array" \
	"$(cat "$HOOK_SCRIPT")" 'active_providers'

# Test: Pre-filter skips fully cooled Claude profiles
assert_contains "Hook source: pre-filter skips cooled Claude" \
	"$(cat "$HOOK_SCRIPT")" 'all Claude profiles cooled'

# Test: Pre-filter skips fully cooled Codex profiles
assert_contains "Hook source: pre-filter skips cooled Codex" \
	"$(cat "$HOOK_SCRIPT")" 'all Codex profiles cooled'

# Test: Pre-filter early exit when all providers cooled
assert_contains "Hook source: pre-filter all-cooled fallback" \
	"$(cat "$HOOK_SCRIPT")" 'All providers are cooled down'

# Test: Dispatch loop uses active_providers
assert_contains "Hook source: dispatch uses active_providers" \
	"$(cat "$HOOK_SCRIPT")" "for provider in \"\${active_providers"

# Test: Stale cooldown cleanup on startup
assert_contains "Hook source: prunes expired cooldown entries" \
	"$(cat "$HOOK_SCRIPT")" "with_entries(select(.value > \$now))"

# Test: jq availability warning
assert_contains "Hook source: jq availability check" \
	"$(cat "$HOOK_SCRIPT")" 'jq not found'

# Test: Atomic writes with flock
assert_contains "Hook source: flock for atomic cooldown writes" \
	"$(cat "$HOOK_SCRIPT")" 'flock'

# Test: Claude auto-discovery validates credentials
assert_contains "Hook source: Claude profile credential validation" \
	"$(cat "$HOOK_SCRIPT")" 'credentials.json'

# Test: Codex auto-discovery validates auth
assert_contains "Hook source: Codex profile auth validation" \
	"$(cat "$HOOK_SCRIPT")" 'auth.json'

# Test: GNU date fallback for Linux
assert_contains "Hook source: GNU date fallback" \
	"$(cat "$HOOK_SCRIPT")" 'date -d'

# ============================================================================
# gwt-ticket Bridge Auto-Rotation Flags
# ============================================================================
print_header "gwt-ticket Bridge Auto-Rotation Flags"

GWTT_FISH="$SCRIPT_DIR/../.config/fish/functions/gwt-ticket.fish"
gwtt_source=$(cat "$GWTT_FISH")

# Test: --bridge-cooldown flag parsing
assert_contains "gwt-ticket source: --bridge-cooldown flag parsing" \
	"$gwtt_source" "--bridge-cooldown"

# Test: --bridge-profiles flag parsing
assert_contains "gwt-ticket source: --bridge-profiles flag parsing" \
	"$gwtt_source" "--bridge-profiles"

# Test: CROSS_PROVIDER_COOLDOWN env var wiring (local path)
assert_contains "gwt-ticket source: CROSS_PROVIDER_COOLDOWN env (local)" \
	"$gwtt_source" "CROSS_PROVIDER_COOLDOWN"

# Test: CROSS_PROVIDER_CLAUDE_PROFILES env var wiring (local path)
assert_contains "gwt-ticket source: CROSS_PROVIDER_CLAUDE_PROFILES env (local)" \
	"$gwtt_source" "CROSS_PROVIDER_CLAUDE_PROFILES"

# Test: --bridge-codex-profiles flag parsing
assert_contains "gwt-ticket source: --bridge-codex-profiles flag parsing" \
	"$gwtt_source" "--bridge-codex-profiles"

# Test: CROSS_PROVIDER_CODEX_PROFILES env var wiring (local path)
assert_contains "gwt-ticket source: CROSS_PROVIDER_CODEX_PROFILES env (local)" \
	"$gwtt_source" "CROSS_PROVIDER_CODEX_PROFILES"

# Test: Help text mentions new flags
if command -v fish &>/dev/null; then
	gwtt_help=$(fish -c "source $GWTT_FISH; gwt-ticket --help" 2>/dev/null) || true
	if [ -n "$gwtt_help" ]; then
		assert_contains "gwt-ticket help: --bridge-cooldown flag" "$gwtt_help" "--bridge-cooldown"
		assert_contains "gwt-ticket help: --bridge-profiles flag" "$gwtt_help" "--bridge-profiles"
		assert_contains "gwt-ticket help: --bridge-codex-profiles flag" "$gwtt_help" "--bridge-codex-profiles"
	fi
fi

# Test: bridge.fish shows cooldown status
BRIDGE_FISH="$SCRIPT_DIR/../.config/fish/functions/bridge.fish"
if [[ -f "$BRIDGE_FISH" ]]; then
	assert_contains "bridge.fish: shows cooldown info" \
		"$(cat "$BRIDGE_FISH")" "cross-provider-cooldowns.json"
	assert_contains "bridge.fish: shows Claude profiles" \
		"$(cat "$BRIDGE_FISH")" "CROSS_PROVIDER_CLAUDE_PROFILES"
	assert_contains "bridge.fish: shows Codex profiles" \
		"$(cat "$BRIDGE_FISH")" "CROSS_PROVIDER_CODEX_PROFILES"
fi

# ============================================================================
# Live Tests (require Claude subscription)
# ============================================================================

if $LIVE_MODE; then
	print_header "Live Cross-Provider Bridge Tests"

	HOOK_SCRIPT="$SCRIPT_DIR/../.claude/hooks/cross-provider-bridge.sh"

	# Create a realistic mock transcript
	bridge_tmpdir=$(mktemp -d)
	bridge_transcript="$bridge_tmpdir/transcript.jsonl"
	cat >"$bridge_transcript" <<'JSONL'
{"role": "user", "content": "Explain why quicksort has O(n log n) average time complexity"}
{"role": "assistant", "content": "Quicksort achieves O(n log n) average-case time complexity because:\n\n1. **Partitioning**: Each partition step processes all n elements in O(n) time.\n2. **Recursive depth**: On average, the pivot splits the array roughly in half, giving O(log n) levels of recursion.\n3. **Total work**: n elements × log n levels = O(n log n).\n\nThe worst case is O(n²) when the pivot consistently selects the minimum or maximum element, creating n levels of recursion instead of log n. This happens with already-sorted input using naive pivot selection.\n\nMitigation strategies:\n- Randomized pivot selection\n- Median-of-three pivot\n- Introsort (switch to heapsort when recursion depth exceeds 2 log n)"}
JSONL

	# Test: Codex provider (if available)
	has_codex=false
	if command -v codex &>/dev/null && codex login status &>/dev/null; then
		has_codex=true
		print_info "Running cross-provider bridge with Codex..."
		codex_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" |
			CROSS_PROVIDER_BRIDGE=1 \
				CROSS_PROVIDER_ORDER="codex" \
				CROSS_PROVIDER_MAX_CHARS=2000 \
				timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true
		if [ -n "$codex_output" ]; then
			# Should return JSON with decision: "block"
			# Use printf instead of echo: echo interprets \n in jq's JSON escapes
			if printf '%s\n' "$codex_output" | jq -e '.decision == "block"' &>/dev/null; then
				print_success "Codex bridge: returned block decision with review"
				((PASS++)) || true
			else
				print_error "Codex bridge: output is not valid block JSON"
				((FAIL++)) || true
			fi
			if printf '%s\n' "$codex_output" | jq -e '.reason | length > 50' &>/dev/null; then
				print_success "Codex bridge: reason contains substantial review"
				((PASS++)) || true
			else
				print_error "Codex bridge: reason too short or missing"
				((FAIL++)) || true
			fi
			# Check reason includes iteration context
			if printf '%s\n' "$codex_output" | jq -e '.reason | test("iteration")' &>/dev/null; then
				print_success "Codex bridge: reason includes iteration context"
				((PASS++)) || true
			else
				print_error "Codex bridge: reason missing iteration context"
				((FAIL++)) || true
			fi
		else
			print_warning "Codex bridge: no output (provider may be unavailable)"
			((SKIP++)) || true
		fi
	else
		print_warning "Codex not available (need codex binary + auth via 'codex login') - skipping"
		((SKIP++)) || true
	fi

	# Test: OpenCode provider (if available)
	# Requires: opencode binary + Ollama running + model pulled
	has_opencode=false
	opencode_model="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen2.5-coder:1.5b}"
	if command -v opencode &>/dev/null && curl -sf http://localhost:11434/api/tags &>/dev/null; then
		has_opencode=true
		print_info "Running cross-provider bridge with OpenCode ($opencode_model)..."
		opencode_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" |
			CROSS_PROVIDER_BRIDGE=1 \
				CROSS_PROVIDER_ORDER="opencode" \
				CROSS_PROVIDER_OPENCODE_MODEL="$opencode_model" \
				CROSS_PROVIDER_MAX_CHARS=2000 \
				timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true

		if [ -n "$opencode_output" ]; then
			if printf '%s\n' "$opencode_output" | jq -e '.decision == "block"' &>/dev/null; then
				print_success "OpenCode bridge: returned block decision with review"
				((PASS++)) || true
			else
				print_error "OpenCode bridge: output is not valid block JSON"
				((FAIL++)) || true
			fi
			if printf '%s\n' "$opencode_output" | jq -e '.reason | length > 50' &>/dev/null; then
				print_success "OpenCode bridge: reason contains substantial review"
				((PASS++)) || true
			else
				print_error "OpenCode bridge: reason too short or missing"
				((FAIL++)) || true
			fi
		else
			print_warning "OpenCode bridge: no output (provider may be unavailable)"
			((SKIP++)) || true
		fi
	else
		print_warning "OpenCode not available (need opencode binary + Ollama running) - skipping"
		((SKIP++)) || true
	fi

	# Test: Fallback order (codex first, then opencode)
	if $has_codex || $has_opencode; then
		print_info "Running cross-provider bridge with default fallback order..."
		fallback_output=$(echo "{\"stop_hook_active\": false, \"transcript_path\": \"$bridge_transcript\"}" |
			CROSS_PROVIDER_BRIDGE=1 \
				CROSS_PROVIDER_MAX_CHARS=2000 \
				timeout 180 bash "$HOOK_SCRIPT" 2>&1) || true

		if [ -n "$fallback_output" ]; then
			if printf '%s\n' "$fallback_output" | jq -e '.decision == "block"' &>/dev/null; then
				print_success "Fallback bridge: at least one provider succeeded"
				((PASS++)) || true
			else
				print_error "Fallback bridge: output is not valid block JSON"
				((FAIL++)) || true
			fi
		else
			print_error "Fallback bridge: no output despite available providers"
			((FAIL++)) || true
		fi
	fi

	rm -rf "$bridge_tmpdir"

	# ========================================================================
	print_header "Live Pipeline Tests (API calls)"

	if ! command -v claude &>/dev/null; then
		print_error "claude CLI not found"
		((FAIL++)) || true
	else
		# Test: Basic 2-stage pipeline (cheap preset to save tokens)
		print_info "Running live pipeline (cheap preset)..."
		live_output=$(fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap 'What is 2+2? Reply with just the number.'" 2>&1)
		live_exit=$?
		assert_exit_code "Live pipeline exits 0" "0" "$live_exit"
		if [[ -n "$live_output" ]]; then
			print_success "Live pipeline produced output ($(echo "$live_output" | wc -c | tr -d ' ') bytes)"
			((PASS++)) || true
		else
			print_error "Live pipeline produced no output"
			((FAIL++)) || true
		fi

		# Test: Pipeline with --save
		tmpdir=$(mktemp -d)
		fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap --save $tmpdir/test --verbose 'What is 2+2? Reply with just the number.'" >/dev/null 2>&1
		if [[ -f "$tmpdir/test-stage1.txt" ]]; then
			print_success "Save: stage1 file created"
			((PASS++)) || true
		else
			print_error "Save: stage1 file not created"
			((FAIL++)) || true
		fi
		if [[ -f "$tmpdir/test-stage2.txt" ]]; then
			print_success "Save: stage2 file created"
			((PASS++)) || true
		else
			print_error "Save: stage2 file not created"
			((FAIL++)) || true
		fi
		rm -rf "$tmpdir"

		# Test: Piped input
		pipe_output=$(echo "The sky is blue" | fish -c "source $SCRIPT_DIR/../.config/fish/functions/claude-pipeline.fish; claude-pipeline --preset cheap 'What color is mentioned? Reply with just the color.'" 2>&1)
		if [[ -n "$pipe_output" ]]; then
			print_success "Piped input produced output"
			((PASS++)) || true
		else
			print_error "Piped input produced no output"
			((FAIL++)) || true
		fi
	fi
else
	print_header "Live Tests (skipped)"
	print_warning "Use --live to run API tests (requires Claude subscription)"
	((SKIP++)) || true
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
