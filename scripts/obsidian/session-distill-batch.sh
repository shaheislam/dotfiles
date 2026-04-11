#!/usr/bin/env bash
#
# session-distill-batch.sh - Batch memory distillation for unprocessed Obsidian session files
#
# Scans ~/obsidian/Claude/Sessions/ for session files that haven't had memory
# extraction run yet, then invokes session-end-extract.py for each one by
# piping the session_id via stdin JSON (matching the SessionEnd hook interface).
#
# Frontmatter formats handled:
#   New (jfdi hook output): memories_extracted: false/true, session_id field
#   Old (pre-jfdi format):  memory_extracted: 0/1, id field
#
# Performance: uses grep -l for bulk "already extracted" detection and comm(1)
# to compute the unprocessed set — no per-file subshell forks during scanning.
#
# Usage:
#   session-distill-batch.sh [--limit N] [--dry-run] [--priority] [--verbose]
#
# Flags:
#   --limit N     Process at most N sessions (default: 10)
#   --dry-run     List files that would be processed, no side effects
#   --priority    Order by work_type: debugging > development > research > planning > general
#   --verbose     Show per-file detail

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
SESSIONS_DIR="$OBSIDIAN_VAULT/Claude/Sessions"
EXTRACTOR="$HOME/.claude/hooks/jfdi/session-end-extract.py"
LOG_DIR="$HOME/.claude/hooks/logs"
LOG_FILE="$LOG_DIR/distill-batch-$(date +%Y-%m-%d).log"

# ─── Defaults ────────────────────────────────────────────────────────────────

LIMIT=10
DRY_RUN=false
PRIORITY=false
VERBOSE=false

# ─── Argument Parsing ────────────────────────────────────────────────────────

show_help() {
    cat <<'EOF'
session-distill-batch.sh - Batch memory distillation for Obsidian sessions

USAGE:
  session-distill-batch.sh [OPTIONS]

OPTIONS:
  --limit N     Process at most N unprocessed sessions (default: 10)
  --dry-run     List files that would be processed, no extraction
  --priority    Order by work_type importance before processing
                  debugging > development > research > planning > general
  --verbose     Show per-file detail including session IDs
  --help, -h    Show this help

ENVIRONMENT:
  OBSIDIAN_VAULT  Path to Obsidian vault (default: ~/obsidian)

WHAT IT DOES:
  1. Scans via grep -l for extracted files (bulk, single pass — fast)
  2. Uses comm(1) to diff all non-synth .md vs extracted set
  3. Candidates = non-synth sessions not in extracted set
  4. Extracts session_id from frontmatter (new: session_id field, old: id field)
  5. Pipes {"session_id": "..."} JSON to session-end-extract.py stdin
  6. On clean exit (0), updates frontmatter to set memories_extracted: true
  7. Reports counts: processed / skipped (already done) / failed

LOG:
  ~/.claude/hooks/logs/distill-batch-YYYY-MM-DD.log
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --limit)
        LIMIT="$2"
        shift 2
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --priority)
        PRIORITY=true
        shift
        ;;
    --verbose)
        VERBOSE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    *)
        echo "Error: Unknown option: $1" >&2
        echo "Run with --help for usage." >&2
        exit 1
        ;;
    esac
done

# ─── Validation ──────────────────────────────────────────────────────────────

if [[ ! -d "$SESSIONS_DIR" ]]; then
    echo "Error: Sessions directory not found: $SESSIONS_DIR" >&2
    exit 1
fi

if [[ ! -f "$EXTRACTOR" ]]; then
    echo "Error: Extractor not found: $EXTRACTOR" >&2
    exit 1
fi

# ─── Logging ─────────────────────────────────────────────────────────────────

log() {
    local msg
    msg="[$(date '+%Y-%m-%dT%H:%M:%S')] $*"
    echo "$msg"
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$LOG_DIR"
        echo "$msg" >>"$LOG_FILE"
    fi
}

vlog() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "$@"
    fi
}

# ─── Bulk Candidate Detection ─────────────────────────────────────────────────
#
# Strategy: compute candidates as a set difference using text stream tools.
#   all_non_synth  = ls | grep -v synth | sort
#   extracted      = grep -ril 'memories_extracted: true' + grep -ril 'memory_extracted: 1' | sort -u
#   candidates     = comm -23 all_non_synth extracted
#
# This avoids forking a subprocess per file — the whole scan is O(n) I/O
# with a handful of processes regardless of directory size.
#
# Temp files are used for comm (which requires seekable sorted input).
# They are cleaned up via a trap on EXIT.

_TMP_ALL=""
_TMP_EXTRACTED=""

cleanup_tmpfiles() {
    [[ -n "$_TMP_ALL" ]] && rm -f "$_TMP_ALL"
    [[ -n "$_TMP_EXTRACTED" ]] && rm -f "$_TMP_EXTRACTED"
}
trap cleanup_tmpfiles EXIT

build_file_sets() {
    _TMP_ALL=$(mktemp)
    _TMP_EXTRACTED=$(mktemp)

    # Choose search tool: rg is significantly faster than grep -ril on macOS HFS+.
    local search_cmd
    if command -v rg &>/dev/null; then
        search_cmd="rg_search"
    else
        search_cmd="grep_search"
    fi

    rg_search() {
        local pattern="$1"
        rg -l "$pattern" "$SESSIONS_DIR" --type md 2>/dev/null || true
    }

    grep_search() {
        local pattern="$1"
        grep -ril "$pattern" "$SESSIONS_DIR" --include='*.md' 2>/dev/null || true
    }

    # Run all three scans in parallel using background jobs to minimize wall time.
    # On a 2400-file HFS+ vault with rg: ~2-3s wall time vs ~14s sequential grep.

    # Job 1: all non-synth .md files, sorted
    # shellcheck disable=SC2012  # ls+grep is fine here; filenames are controlled
    (find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.md' ! -name '*-synth-*' 2>/dev/null | sort >"$_TMP_ALL") &
    local pid_all=$!

    # Job 2 & 3: extracted files, both format variants
    local _TMP_EX_NEW _TMP_EX_OLD
    _TMP_EX_NEW=$(mktemp)
    _TMP_EX_OLD=$(mktemp)
    ($search_cmd 'memories_extracted: true' >"$_TMP_EX_NEW") &
    local pid_new=$!
    ($search_cmd 'memory_extracted: 1' >"$_TMP_EX_OLD") &
    local pid_old=$!

    wait "$pid_all" "$pid_new" "$pid_old" || true

    # Merge extracted sets (sort -u deduplicates across both outputs)
    cat "$_TMP_EX_NEW" "$_TMP_EX_OLD" | sort -u >"$_TMP_EXTRACTED"
    rm -f "$_TMP_EX_NEW" "$_TMP_EX_OLD"
}

# Returns the count of lines in a file (without forking wc when avoidable).
file_line_count() {
    wc -l <"$1" | tr -d ' '
}

# ─── Frontmatter Parsing (per-file, only on candidates) ──────────────────────

# Extract a frontmatter field from a file using a single awk invocation.
# Handles: `field: value`, `field: "value"`, `field: 'value'`
get_frontmatter_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        /^---$/ { count++; if (count == 2) exit; next }
        count == 1 {
            if (substr($0, 1, length(field)+1) == field ":") {
                val = substr($0, length(field) + 3)
                gsub(/^[ \t"'"'"']+|[ \t"'"'"']+$/, "", val)
                print val
                exit
            }
        }
    ' "$file"
}

# Get session_id: tries new field (session_id:) then old field (id:).
get_session_id() {
    local file="$1"
    local sid

    sid=$(get_frontmatter_field "$file" "session_id")
    if [[ -n "$sid" ]]; then
        echo "$sid"
        return 0
    fi

    sid=$(get_frontmatter_field "$file" "id")
    if [[ -n "$sid" ]]; then
        echo "$sid"
        return 0
    fi

    return 1
}

# Get work_type for priority sorting.
get_work_type() {
    local file="$1"
    local wt
    wt=$(get_frontmatter_field "$file" "work_type")
    echo "${wt:-general}"
}

# ─── Priority Sort ───────────────────────────────────────────────────────────

work_type_priority() {
    local wt="$1"
    case "$wt" in
    debugging) echo 1 ;;
    development) echo 2 ;;
    research) echo 3 ;;
    planning) echo 4 ;;
    *) echo 5 ;;
    esac
}

# Sort a file of newline-separated paths by work_type priority.
# Uses gawk with getline to open each file inline — single gawk process,
# no per-file bash subshells. Falls back to BSD awk order if gawk absent.
# Input: path to file containing one candidate path per line.
# Output: sorted paths on stdout (highest priority first = debugging first).
sort_candidates_by_priority() {
    local candidates_file="$1"
    local gawk_bin
    gawk_bin=$(command -v gawk 2>/dev/null || true)

    if [[ -z "$gawk_bin" ]]; then
        # gawk not available: emit unsorted (correct but unordered)
        cat "$candidates_file"
        return 0
    fi

    # gawk reads each filepath from stdin and uses getline to open the file
    # and extract work_type from its YAML frontmatter block. Single process.
    # shellcheck disable=SC2016  # single quotes intentional; awk has own vars
    "$gawk_bin" '
        BEGIN {
            prio["debugging"]   = 1
            prio["development"] = 2
            prio["research"]    = 3
            prio["planning"]    = 4
        }
        {
            filepath = $0
            wt = "general"
            fm_count = 0
            in_fm = 0
            while ((getline line < filepath) > 0) {
                if (line ~ /^---$/) {
                    fm_count++
                    if (fm_count == 1) { in_fm = 1; continue }
                    if (fm_count == 2) { break }
                }
                if (in_fm && line ~ /^work_type:/) {
                    val = substr(line, 12)
                    gsub(/^[ \t"'"'"']+|[ \t"'"'"']+$/, "", val)
                    wt = val
                }
            }
            close(filepath)
            p = (wt in prio) ? prio[wt] : 5
            print p " " filepath
        }
    ' <"$candidates_file" | sort -k1,1n -k2,2 | cut -d' ' -f2-
}

# ─── Update Frontmatter ──────────────────────────────────────────────────────

# Mark a session file as extracted.
# - If memories_extracted: exists → rewrites it to true
# - Otherwise → injects memories_extracted: true before closing ---
mark_extracted() {
    local file="$1"
    local tmp
    tmp=$(mktemp)

    awk '
        BEGIN { fm_count=0; found=0 }
        /^---$/ {
            fm_count++
            if (fm_count == 1) { print; next }
            if (fm_count == 2) {
                if (!found) { print "memories_extracted: true" }
                print; next
            }
        }
        fm_count == 1 && /^memories_extracted:/ {
            print "memories_extracted: true"
            found=1
            next
        }
        { print }
    ' "$file" >"$tmp"

    mv -f "$tmp" "$file"
}

# ─── Invoke Extractor ────────────────────────────────────────────────────────

# Pipe {"hook_type":"SessionEnd","session_id":"..."} JSON to the extractor.
# The extractor already handles "session JSONL not found" gracefully (exits 0,
# returns {"continue":true}). We mark as processed on any clean exit to avoid
# re-scanning sessions whose JSONL no longer exists.
run_extractor() {
    local session_id="$1"
    local input_json
    input_json=$(printf '{"hook_type":"SessionEnd","session_id":"%s","cwd":"%s"}' \
        "$session_id" "${PWD}")

    vlog "  Invoking extractor: session_id=${session_id:0:8}..."

    local output exit_code
    exit_code=0
    output=$(echo "$input_json" | python3 "$EXTRACTOR" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        vlog "  Extractor exit=$exit_code output=$output"
        return 1
    fi

    vlog "  Extractor output: $output"
    return 0
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    log "=== session-distill-batch starting ==="
    log "Sessions dir: $SESSIONS_DIR"
    log "Limit: $LIMIT | Priority: $PRIORITY | Dry-run: $DRY_RUN"

    # Build sorted file sets (fast bulk scan)
    vlog "Building file sets (bulk grep + comm)..."
    build_file_sets

    local count_all count_extracted count_candidates
    count_all=$(file_line_count "$_TMP_ALL")
    count_extracted=$(file_line_count "$_TMP_EXTRACTED")

    # Candidates = all non-synth minus extracted
    local _TMP_CANDIDATES
    _TMP_CANDIDATES=$(mktemp)
    comm -23 "$_TMP_ALL" "$_TMP_EXTRACTED" >"$_TMP_CANDIDATES"
    count_candidates=$(file_line_count "$_TMP_CANDIDATES")

    log "Total non-synth sessions:  $count_all"
    log "Already processed (skip):  $count_extracted"
    log "Unprocessed candidates:    $count_candidates"

    # Optional priority sort: single gawk pass over all candidate files.
    # Applied before dry-run listing too so --dry-run --priority shows correct order.
    local _TMP_SORTED
    _TMP_SORTED=$(mktemp)
    if [[ "$PRIORITY" == "true" ]]; then
        vlog "Sorting candidates by work_type priority (single gawk pass)..."
        sort_candidates_by_priority "$_TMP_CANDIDATES" >"$_TMP_SORTED"
    else
        cp "$_TMP_CANDIDATES" "$_TMP_SORTED"
    fi
    rm -f "$_TMP_CANDIDATES"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=== DRY RUN: would process (up to $LIMIT of $count_candidates unprocessed) ==="
        local shown=0
        while IFS= read -r file; do
            if [[ $shown -ge $LIMIT ]]; then
                break
            fi
            [[ -n "$file" ]] || continue
            local sid wt
            sid=$(get_session_id "$file" 2>/dev/null || echo "(no session_id)")
            wt=$(get_work_type "$file" 2>/dev/null || echo "unknown")
            echo "  [$(basename "$file")] session_id=${sid:0:16} work_type=$wt"
            shown=$((shown + 1))
        done <"$_TMP_SORTED"
        if [[ $count_candidates -gt $LIMIT ]]; then
            echo "  ... and $((count_candidates - LIMIT)) more"
        fi
        echo ""
        echo "Summary: $count_candidates unprocessed, $count_extracted already done, limit=$LIMIT"
        rm -f "$_TMP_SORTED"
        return 0
    fi

    # Process up to LIMIT files
    local count_processed=0
    local count_failed=0
    local count_no_id=0
    local processed_count=0

    while IFS= read -r file; do
        if [[ $processed_count -ge $LIMIT ]]; then
            break
        fi
        [[ -n "$file" ]] || continue

        local sid wt
        sid=$(get_session_id "$file" 2>/dev/null || true)
        wt=$(get_work_type "$file")

        if [[ -z "$sid" ]]; then
            log "SKIP (no session_id): $(basename "$file")"
            count_no_id=$((count_no_id + 1))
            processed_count=$((processed_count + 1))
            continue
        fi

        vlog "Processing: $(basename "$file") | session_id=${sid:0:8} | work_type=$wt"

        if run_extractor "$sid"; then
            if mark_extracted "$file"; then
                log "OK: $(basename "$file") | session_id=${sid:0:8}"
                count_processed=$((count_processed + 1))
            else
                log "FAIL (frontmatter update): $(basename "$file")"
                count_failed=$((count_failed + 1))
            fi
        else
            log "FAIL (extractor): $(basename "$file") | session_id=${sid:0:8}"
            count_failed=$((count_failed + 1))
        fi

        processed_count=$((processed_count + 1))
    done <"$_TMP_SORTED"
    rm -f "$_TMP_SORTED"

    local remaining=$((count_candidates - processed_count))

    echo ""
    log "=== session-distill-batch complete ==="
    log "  Processed:          $count_processed"
    log "  Skipped (done):     $count_extracted"
    log "  No session_id:      $count_no_id"
    log "  Failed:             $count_failed"
    log "  Remaining (unrun):  $remaining"
}

main
