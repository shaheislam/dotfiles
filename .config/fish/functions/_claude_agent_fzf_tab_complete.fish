function _claude_agent_fzf_tab_complete -d "FZF-powered --agent tab completion with preview"
    set -l token (commandline --current-token)

    # Collect agents: name<TAB>model<TAB>description<TAB>filepath
    set -l entries
    set -l seen_names

    # 1. Project-level agents (.claude/agents/*.md relative to git root)
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$git_root"
        for agent_file in $git_root/.claude/agents/*.md
            if test -f "$agent_file"
                set -l parsed (_claude_agent_parse_frontmatter "$agent_file")
                set -l name $parsed[1]
                set -l model $parsed[2]
                set -l desc $parsed[3]
                if test -n "$name"; and not contains -- "$name" $seen_names
                    set -a entries (printf '%s\t%s\t%s\t%s' "$name" "$model" "$desc" "$agent_file")
                    set -a seen_names $name
                end
            end
        end
    end

    # 2. User-level agents (~/.claude/agents/*.md)
    for agent_file in ~/.claude/agents/*.md
        if test -f "$agent_file"
            set -l parsed (_claude_agent_parse_frontmatter "$agent_file")
            set -l name $parsed[1]
            set -l model $parsed[2]
            set -l desc $parsed[3]
            if test -n "$name"; and not contains -- "$name" $seen_names
                set -a entries (printf '%s\t%s\t%s\t%s' "$name" "$model" "$desc" "$agent_file")
                set -a seen_names $name
            end
        end
    end

    if test (count $entries) -eq 0
        commandline --function repaint
        return
    end

    # FZF with preview of the agent .md file
    # Display columns 1-3 (name, model, description); column 4 is the file path for preview
    set -l result (printf '%s\n' $entries \
        | fzf \
            --exit-0 \
            --no-multi \
            -d '\t' \
            --with-nth=1,2,3 \
            --prompt='agent ❯ ' \
            --header='name / model / description' \
            --preview='cat {4}' \
            --preview-window=right:50%:wrap \
            --bind='ctrl-/:toggle-preview' \
            --query="$token" \
        | cut -f1)

    if test -n "$result"
        commandline --replace --current-token -- "$result"
        commandline --insert ' '
    end
    commandline --function repaint
end

function _claude_agent_parse_frontmatter -d "Extract name, model, description from agent .md frontmatter"
    # Returns 3 values: name model description
    set -l name ""
    set -l model ""
    set -l desc ""
    set -l in_frontmatter false
    set -l reading_desc false
    set -l line_num 0

    while read -l line
        set line_num (math $line_num + 1)
        if test $line_num -gt 30
            break
        end
        if test $line_num -eq 1
            if test "$line" = ---
                set in_frontmatter true
                continue
            else
                break
            end
        end
        if $in_frontmatter
            if test "$line" = ---
                break
            end
            # Continue reading multi-line description
            if $reading_desc
                if string match -qr '^\s+\S' "$line"
                    set -l continuation (string trim -- "$line")
                    set desc "$desc $continuation"
                    continue
                else
                    set reading_desc false
                end
            end
            # Parse name
            if string match -qr '^name:\s+(.+)' "$line"
                set name (string replace -r '^name:\s+' '' -- "$line" | string trim -c '"' | string trim -c "'")
            end
            # Parse model
            if string match -qr '^model:\s+(.+)' "$line"
                set model (string replace -r '^model:\s+' '' -- "$line" | string trim -c '"' | string trim -c "'")
            end
            # Parse description (single-line)
            if string match -qr '^description:\s+(.+)' "$line"
                set desc (string replace -r '^description:\s+' '' -- "$line" | string trim -c '"' | string trim -c "'")
            end
            # Parse description (multi-line start)
            if string match -qr '^description:\s*$' "$line"
                set reading_desc true
            end
        end
    end <$argv[1]

    # Fallback: derive name from filename
    if test -z "$name"
        set name (basename $argv[1] .md)
    end
    if test -z "$model"
        set model inherit
    end
    set desc (string trim -- "$desc")
    if test -z "$desc"
        set desc "(no description)"
    end
    # Truncate long descriptions
    if test (string length -- "$desc") -gt 60
        set desc (string sub -l 57 -- "$desc")"..."
    end

    echo $name
    echo $model
    echo $desc
end
