# Clipboard fix - remove unwanted line breaks from copied text
# Fixes the common issue where copying from Claude Code (or other TUIs)
# introduces line breaks at terminal wrap points.
#
# Usage:
#   cfx              Join all lines into one (best for commands)
#   cfx -p           Preserve paragraph breaks (double newlines)
#   cfx -t           Trim trailing whitespace only (keep structure)
#   cfx -v           Show before/after diff
#   echo "text" | cfx   Also works with piped input

function cfx -d "Fix clipboard line breaks from terminal copy"
    argparse p/paragraphs t/trim-only v/verbose h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "cfx - Fix clipboard line breaks from terminal copy"
        echo ""
        echo "Usage:"
        echo "  cfx          Join all lines into one (for commands)"
        echo "  cfx -p       Preserve paragraph breaks (double newlines)"
        echo "  cfx -t       Trim trailing whitespace only"
        echo "  cfx -v       Show before/after preview"
        echo "  echo 'x' | cfx   Works with piped input"
        return 0
    end

    # Read input preserving newlines (read -z reads null-terminated, gets full content)
    set -l input_file (mktemp)
    if not isatty stdin
        cat >$input_file
    else
        pbpaste >$input_file
    end

    if test ! -s $input_file
        echo "cfx: clipboard is empty" >&2
        rm -f $input_file
        return 1
    end

    set -l result_file (mktemp)

    if set -q _flag_trim_only
        # Just trim trailing whitespace from each line
        sed 's/[[:space:]]*$//' <$input_file >$result_file
    else if set -q _flag_paragraphs
        # Preserve paragraph breaks (empty lines) but join wrapped lines
        awk '
            BEGIN { para = "" }
            /^[[:space:]]*$/ {
                if (para != "") { print para; print ""; para = "" }
                next
            }
            {
                sub(/[[:space:]]+$/, "")
                if (para == "") { para = $0 }
                else { para = para " " $0 }
            }
            END { if (para != "") print para }
        ' <$input_file >$result_file
    else
        # Default: join all lines into one (best for commands)
        tr '\n' ' ' <$input_file | sed 's/  */ /g; s/^ *//; s/ *$//' >$result_file
    end

    if set -q _flag_verbose
        echo "--- Before ---"
        cat $input_file
        echo "--- After ---"
        cat $result_file
        echo ---
    end

    # Output to clipboard or stdout
    if not isatty stdin
        cat $result_file
    else
        pbcopy <$result_file
        echo "cfx: clipboard updated ("(wc -c <$result_file | tr -d ' ')" bytes)"
    end

    rm -f $input_file $result_file
end
