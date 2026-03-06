#!/usr/bin/env bash
#
# analyze.sh - AI Gateway: Static analysis bridge for AI agents
#
# Runs static analysis tools (semgrep, tree-sitter, LSP diagnostics) on
# changed files and formats findings into structured context that AI agents
# can consume for automated fixes.
#
# Usage:
#   analyze.sh [options] [files...]
#
#   Options:
#     --staged          Analyze git staged files (default: changed files)
#     --all             Analyze all files in repo
#     --format json     Output format: json (default), sarif, prompt
#     --severity min    Minimum severity: info, warning, error (default: warning)
#     --tool TOOL       Run specific tool only: semgrep, shellcheck, ruff
#     --agent-context   Format output as agent-injectable context
#     --benchmark       Measure and report analysis latency per tool
#     --help            Show this help
#
# Exit codes:
#   0 - Analysis complete, findings reported
#   1 - Error (bad args, missing tools)
#   2 - No files to analyze

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/semgrep-agent-rules.yaml"

# Defaults
FORMAT="json"
MIN_SEVERITY="warning"
TARGET_TOOL=""
BENCHMARK=false
FILE_MODE="changed"
FILES=()

# Colors (used in error output)
RED='\033[0;31m'
NC='\033[0m'

# ─── Argument Parsing ───────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
    --staged)
        FILE_MODE="staged"
        shift
        ;;
    --all)
        FILE_MODE="all"
        shift
        ;;
    --format)
        FORMAT="$2"
        shift 2
        ;;
    --severity)
        MIN_SEVERITY="$2"
        shift 2
        ;;
    --tool)
        TARGET_TOOL="$2"
        shift 2
        ;;
    --agent-context)
        FORMAT="prompt"
        shift
        ;;
    --benchmark)
        BENCHMARK=true
        shift
        ;;
    --help | -h)
        head -25 "$0" | tail -20
        exit 0
        ;;
    -*)
        echo -e "${RED}Unknown option: $1${NC}" >&2
        exit 1
        ;;
    *)
        FILES+=("$1")
        shift
        ;;
    esac
done

# ─── File Discovery ─────────────────────────────

discover_files() {
    if [[ ${#FILES[@]} -gt 0 ]]; then
        printf '%s\n' "${FILES[@]}"
        return
    fi

    case "$FILE_MODE" in
    staged)
        git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
        ;;
    changed)
        git diff --name-only --diff-filter=ACMR 2>/dev/null
        git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
        ;;
    all)
        git ls-files 2>/dev/null
        ;;
    esac | sort -u
}

# ─── Benchmark Helper ────────────────────────────

bench_start() {
    if [[ "$BENCHMARK" == "true" ]]; then
        date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))'
    fi
}

bench_end() {
    local tool="$1" start_ns="$2"
    if [[ "$BENCHMARK" == "true" && -n "$start_ns" ]]; then
        local end_ns
        end_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
        local elapsed_ms=$(((end_ns - start_ns) / 1000000))
        echo "[benchmark] $tool: ${elapsed_ms}ms" >&2
    fi
}

# Print benchmark methodology context so numbers are interpretable
bench_report_context() {
    if [[ "$BENCHMARK" != "true" ]]; then return; fi
    local file_count="$1"
    local total_bytes=0
    for f in "${FILES[@]+"${FILES[@]}"}"; do
        if [[ -f "$f" ]]; then
            total_bytes=$((total_bytes + $(wc -c <"$f")))
        fi
    done
    cat >&2 <<BENCH
[benchmark] --- methodology ---
[benchmark] file_count: $file_count
[benchmark] total_bytes: $total_bytes
[benchmark] file_mode: $FILE_MODE
[benchmark] target_tool: ${TARGET_TOOL:-all}
[benchmark] min_severity: $MIN_SEVERITY
[benchmark] platform: $(uname -sm)
[benchmark] cache: unknown (run twice; second run is warm)
[benchmark] timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
[benchmark] WARNING: Numbers are single-run, not averaged.
[benchmark]   Do not use for architectural defaults without
[benchmark]   repeated measurement across representative files.
[benchmark] -----------------------
BENCH
}

# ─── Tool Runners ───────────────────────────────

run_semgrep() {
    local files=("$@")
    if ! command -v semgrep >/dev/null 2>&1; then
        echo '{"tool":"semgrep","status":"unavailable","reason":"not installed"}' >&2
        return 0
    fi

    # Use custom rules if available, otherwise use auto config
    local rule_args=()
    if [[ -f "$RULES_FILE" ]]; then
        rule_args=(--config "$RULES_FILE")
    fi
    rule_args+=(--config "auto")

    local tmp_out
    tmp_out=$(mktemp)
    # Run semgrep with JSON output, suppressing errors from broken installs
    if semgrep scan "${rule_args[@]}" --json --quiet \
        --severity "$MIN_SEVERITY" \
        "${files[@]}" >"$tmp_out" 2>/dev/null; then
        cat "$tmp_out"
    else
        # Semgrep failed (possibly broken install), return empty results
        echo '{"results":[],"errors":[{"message":"semgrep execution failed"}]}'
    fi
    rm -f "$tmp_out"
}

run_shellcheck() {
    local files=("$@")
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo '{"tool":"shellcheck","status":"unavailable"}' >&2
        return 0
    fi

    # Filter to shell files only
    local shell_files=()
    for f in "${files[@]}"; do
        case "$f" in
        *.sh | *.bash) shell_files+=("$f") ;;
        *)
            # Check shebang for files without extension
            if [[ -f "$f" ]] && head -1 "$f" 2>/dev/null | grep -qE '^#!.*\b(bash|sh)\b'; then
                shell_files+=("$f")
            fi
            ;;
        esac
    done

    if [[ ${#shell_files[@]} -eq 0 ]]; then
        echo '[]'
        return 0
    fi

    shellcheck --format=json "${shell_files[@]}" 2>/dev/null || echo '[]'
}

run_ruff() {
    local files=("$@")
    if ! command -v ruff >/dev/null 2>&1; then
        echo '{"tool":"ruff","status":"unavailable"}' >&2
        return 0
    fi

    # Filter to Python files only
    local py_files=()
    for f in "${files[@]}"; do
        case "$f" in
        *.py | *.pyi) py_files+=("$f") ;;
        esac
    done

    if [[ ${#py_files[@]} -eq 0 ]]; then
        echo '[]'
        return 0
    fi

    ruff check --output-format=json "${py_files[@]}" 2>/dev/null || echo '[]'
}

# ─── Output Formatters ──────────────────────────

# Convert tool-specific JSON to unified finding format
normalize_findings() {
    local tool="$1"
    local raw_json="$2"

    case "$tool" in
    semgrep)
        echo "$raw_json" | jq -r '
            [(.results // [])[] | {
                tool: "semgrep",
                rule: .check_id,
                file: .path,
                line: .start.line,
                end_line: .end.line,
                severity: .extra.severity,
                message: .extra.message,
                code_snippet: .extra.lines,
                fix: (.extra.fix // null),
                metadata: (.extra.metadata // {}),
                tool_native: {
                    dataflow_trace: (.extra.dataflow_trace // null),
                    metavars: (.extra.metavars // null),
                    engine_kind: (.extra.engine_kind // null)
                }
            }]' 2>/dev/null || echo '[]'
        ;;
    shellcheck)
        echo "$raw_json" | jq -r '
            [.[] | {
                tool: "shellcheck",
                rule: ("SC" + (.code | tostring)),
                file: .file,
                line: .line,
                end_line: .endLine,
                severity: (if .level == "style" then "info" else .level end),
                message: .message,
                code_snippet: null,
                fix: (.fix.replacements // null),
                metadata: {column: .column, wiki: ("https://www.shellcheck.net/wiki/SC" + (.code | tostring))},
                tool_native: {original_level: .level, fix: (.fix // null)}
            }]' 2>/dev/null || echo '[]'
        ;;
    ruff)
        echo "$raw_json" | jq -r '
            [.[] | {
                tool: "ruff",
                rule: .code,
                file: .filename,
                line: .location.row,
                end_line: .end_location.row,
                severity: (if .code | startswith("E") then "error" elif .code | startswith("W") then "warning" else "info" end),
                message: .message,
                code_snippet: null,
                fix: (.fix // null),
                metadata: {url: .url},
                tool_native: {
                    noqa_row: (.noqa_row // null),
                    cell: (.cell // null)
                }
            }]' 2>/dev/null || echo '[]'
        ;;
    esac
}

# ─── Deduplication ───────────────────────────────
#
# Identity key: file + line
# When multiple tools report the same file+line, keep the finding with
# higher severity. On tie, prefer the language-specific tool.
#
# Precedence: error > warning > info; on same severity, first tool wins.

dedup_findings() {
    local findings_json="$1"
    echo "$findings_json" | jq '
        def sev_rank:
            if .severity == "error" or .severity == "ERROR" then 0
            elif .severity == "warning" or .severity == "WARNING" then 1
            else 2 end;

        # Group by file:line identity key
        group_by("\(.file):\(.line)") |
        map(
            sort_by(sev_rank) |
            .[0] + {
                dedup_key: "\(.[0].file):\(.[0].line)",
                duplicates_removed: (length - 1)
            }
        )
    '
}

# Format findings as agent-injectable prompt context
format_as_prompt() {
    local findings_json="$1"

    local count
    count=$(echo "$findings_json" | jq 'length')

    if [[ "$count" == "0" ]]; then
        echo "Static analysis: no issues found."
        return 0
    fi

    echo "# Static Analysis Findings ($count issues)"
    echo ""

    # Group by file
    echo "$findings_json" | jq -r '
        group_by(.file) | .[] |
        "## " + .[0].file + " (" + (length | tostring) + " issues)\n" +
        ([.[] |
            "- **" + .severity + "** [" + .tool + "/" + .rule + "] line " + (.line | tostring) + ": " + .message +
            (if .metadata.agent_guidance then "\n  Agent guidance: " + .metadata.agent_guidance else "" end) +
            (if .fix then "\n  Auto-fix available" else "" end)
        ] | join("\n")) + "\n"
    ' 2>/dev/null
}

# ─── Main ────────────────────────────────────────

main() {
    local files_list
    files_list=$(discover_files)

    if [[ -z "$files_list" ]]; then
        if [[ "$FORMAT" == "json" ]]; then
            echo '{"findings":[],"summary":{"total":0}}'
        else
            echo "No files to analyze."
        fi
        exit 2
    fi

    # Convert to array
    local files=()
    while IFS= read -r f; do
        [[ -f "$f" ]] && files+=("$f")
    done <<<"$files_list"

    if [[ ${#files[@]} -eq 0 ]]; then
        echo '{"findings":[],"summary":{"total":0}}'
        exit 2
    fi

    # Report benchmark context before running tools
    bench_report_context "${#files[@]}"

    # Run selected tools
    local all_findings="[]"

    if [[ -z "$TARGET_TOOL" || "$TARGET_TOOL" == "semgrep" ]]; then
        local t0
        t0=$(bench_start)
        local semgrep_raw
        semgrep_raw=$(run_semgrep "${files[@]}")
        bench_end "semgrep" "$t0"
        local semgrep_findings
        semgrep_findings=$(normalize_findings "semgrep" "$semgrep_raw")
        all_findings=$(echo "$all_findings" "$semgrep_findings" | jq -s 'add')
    fi

    if [[ -z "$TARGET_TOOL" || "$TARGET_TOOL" == "shellcheck" ]]; then
        local t0
        t0=$(bench_start)
        local sc_raw
        sc_raw=$(run_shellcheck "${files[@]}")
        bench_end "shellcheck" "$t0"
        local sc_findings
        sc_findings=$(normalize_findings "shellcheck" "$sc_raw")
        all_findings=$(echo "$all_findings" "$sc_findings" | jq -s 'add')
    fi

    if [[ -z "$TARGET_TOOL" || "$TARGET_TOOL" == "ruff" ]]; then
        local t0
        t0=$(bench_start)
        local ruff_raw
        ruff_raw=$(run_ruff "${files[@]}")
        bench_end "ruff" "$t0"
        local ruff_findings
        ruff_findings=$(normalize_findings "ruff" "$ruff_raw")
        all_findings=$(echo "$all_findings" "$ruff_findings" | jq -s 'add')
    fi

    # Deduplicate cross-tool findings
    all_findings=$(dedup_findings "$all_findings")

    # Output
    case "$FORMAT" in
    json)
        local total
        total=$(echo "$all_findings" | jq 'length')
        local by_severity
        by_severity=$(echo "$all_findings" | jq '{
            error: [.[] | select(.severity == "error" or .severity == "ERROR")] | length,
            warning: [.[] | select(.severity == "warning" or .severity == "WARNING")] | length,
            info: [.[] | select(.severity == "info" or .severity == "INFO")] | length
        }')
        jq -n --argjson findings "$all_findings" \
            --argjson summary "{\"total\":$total}" \
            --argjson by_severity "$by_severity" \
            '{findings: $findings, summary: ($summary + {by_severity: $by_severity})}'
        ;;
    prompt)
        format_as_prompt "$all_findings"
        ;;
    sarif)
        # SARIF 2.1.0 output for GitHub/SonarQube interop
        echo "$all_findings" | jq '{
            "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
            version: "2.1.0",
            runs: [{
                tool: {driver: {name: "aigateway", version: "0.1.0"}},
                results: [.[] | {
                    ruleId: .rule,
                    level: (if .severity == "error" or .severity == "ERROR" then "error"
                            elif .severity == "warning" or .severity == "WARNING" then "warning"
                            else "note" end),
                    message: {text: .message},
                    locations: [{
                        physicalLocation: {
                            artifactLocation: {uri: .file},
                            region: {startLine: .line, endLine: .end_line}
                        }
                    }]
                }]
            }]
        }'
        ;;
    esac
}

main
