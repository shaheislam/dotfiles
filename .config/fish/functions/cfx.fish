# Clipboard fix - remove unwanted line breaks from copied text
# Fixes the common issue where copying from Claude Code (or other TUIs)
# introduces line breaks at terminal wrap points.
#
# Usage:
#   cfx              Join all lines into one (best for commands)
#   cfx -p           Preserve paragraph breaks (double newlines)
#   cfx -t           Trim trailing whitespace only (keep structure)
#   cfx -v           Show before/after diff
#   cfx -n           Dry-run: preview result without modifying clipboard
#   echo "text" | cfx   Also works with piped input

function cfx -d "Fix clipboard line breaks from terminal copy"
    argparse p/paragraphs t/trim-only v/verbose n/dry-run h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "cfx - Fix clipboard line breaks from terminal copy"
        echo ""
        echo "Usage:"
        echo "  cfx          Join all lines into one (for commands)"
        echo "  cfx -p       Preserve paragraph breaks (double newlines)"
        echo "  cfx -t       Trim trailing whitespace only"
        echo "  cfx -v       Show before/after preview"
        echo "  cfx -n       Dry-run (preview only, don't modify clipboard)"
        echo "  echo 'x' | cfx   Works with piped input"
        echo ""
        echo "Notes:"
        echo "  Join mode preserves backslash line continuations."
        echo "  Paragraph mode preserves indented lines and list items."
        return 0
    end

    # Read input preserving newlines via temp file
    set -l input_file (mktemp)
    if not isatty stdin
        cat >$input_file
    else
        pbpaste >$input_file
    end

    # Guard: empty input
    if test ! -s $input_file
        echo "cfx: clipboard is empty" >&2
        rm -f $input_file
        return 1
    end

    # Guard: binary content (check for null bytes)
    if command grep -cP '\\x00' $input_file >/dev/null 2>&1
        echo "cfx: clipboard contains binary data, skipping" >&2
        rm -f $input_file
        return 1
    end

    set -l result_file (mktemp)

    if set -q _flag_trim_only
        # Just trim trailing whitespace from each line
        sed 's/[[:space:]]*$//' <$input_file >$result_file
    else if set -q _flag_paragraphs
        # Preserve paragraph breaks (empty lines), indented lines, and list items
        # but join wrapped lines within paragraphs.
        # Lines starting with whitespace, list markers, or numbered items
        # begin new logical blocks.
        # NOTE: Fish single quotes escape \\ → \, so awk needs \\\\ for literal \\
        awk '
            BEGIN { para = ""; was_special = 0 }
            /^[[:space:]]*$/ {
                if (para != "") { print para; print ""; para = "" }
                was_special = 0
                next
            }
            /^[[:space:]]/ || /^[-*+>]/ || /^[0-9]+[.)]/ {
                if (para != "") print para
                sub(/[[:space:]]+$/, "")
                para = $0
                was_special = 1
                next
            }
            {
                sub(/[[:space:]]+$/, "")
                if (para == "" || was_special) {
                    if (para != "") print para
                    para = $0
                } else {
                    para = para " " $0
                }
                was_special = 0
            }
            END { if (para != "") print para }
        ' <$input_file >$result_file
    else
        # Default: join all lines into one (best for commands)
        # Preserves backslash line continuations (lines ending with \)
        # NOTE: Fish single quotes escape \\ → \, so awk needs \\\\ for literal \\
        awk '
            {
                sub(/[[:space:]]+$/, "")
                if (NR == 1) {
                    sub(/^[[:space:]]+/, "")
                    buf = $0
                } else if (prev_had_backslash) {
                    buf = buf "\\n" $0
                } else {
                    sub(/^[[:space:]]+/, "")
                    buf = buf " " $0
                }
                prev_had_backslash = /\\\\$/
            }
            END { print buf }
        ' <$input_file >$result_file
    end

    if set -q _flag_verbose; or set -q _flag_dry_run
        echo "--- Before ---"
        command cat $input_file
        echo "--- After ---"
        command cat $result_file
        echo ---
    end

    # Output to clipboard or stdout
    if not isatty stdin
        if set -q _flag_dry_run
            # Dry-run in pipe mode: still output to stdout but add notice to stderr
            command cat $result_file
            echo "cfx: dry-run preview" >&2
        else
            command cat $result_file
        end
    else if set -q _flag_dry_run
        echo "cfx: dry-run, clipboard unchanged"
    else
        pbcopy <$result_file
        echo "cfx: clipboard updated ("(wc -c <$result_file | tr -d ' ')" bytes)"
    end

    rm -f $input_file $result_file
end
