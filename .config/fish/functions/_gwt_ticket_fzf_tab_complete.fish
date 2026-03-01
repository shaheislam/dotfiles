function _gwt_ticket_fzf_tab_complete -d "FZF-powered gwt-ticket tab completion with multiselect skill picker"
    set -l cmd (commandline -opc)
    set -l token (commandline --current-token)

    # Detect if the previous token is --skill (or we're mid-skill selection)
    # --skill consumes all following non-flag args, so show picker when:
    #   1. Previous token is --skill
    #   2. We're after --skill and haven't hit another flag yet
    set -l after_skill false
    set -l i (count $cmd)
    while test $i -ge 2
        set -l arg $cmd[$i]
        if test "$arg" = --skill
            set after_skill true
            break
        end
        # Stop scanning if we hit a different flag
        if string match -q -- '--*' "$arg"
            break
        end
        set i (math $i - 1)
    end

    if not $after_skill
        # Not in --skill context, fall back to fifc for standard completion
        _fifc
        return
    end

    # Discover skills from all sources
    # Each entry: "skill-name<TAB>(source) description"
    set -l skill_entries
    set -l skill_names

    # 1. Project-level skills: .claude/skills/*/SKILL.md (relative to git root)
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$git_root"
        for skill_dir in $git_root/.claude/skills/*/
            set -l skill_file "$skill_dir/SKILL.md"
            if test -f "$skill_file"
                set -l name (basename $skill_dir)
                set -l desc (_gwt_skill_description "$skill_file")
                set -a skill_entries (printf '%s\t(project) %s' "$name" "$desc")
                set -a skill_names $name
            end
        end
    end

    # 2. User-level skills: ~/.claude/skills/*/SKILL.md
    for skill_dir in ~/.claude/skills/*/
        set -l skill_file "$skill_dir/SKILL.md"
        if test -f "$skill_file"
            set -l name (basename $skill_dir)
            # Skip duplicates (project skills take precedence)
            if not contains -- $name $skill_names
                set -l desc (_gwt_skill_description "$skill_file")
                set -a skill_entries (printf '%s\t(user) %s' "$name" "$desc")
                set -a skill_names $name
            end
        end
    end

    # 3. Plugin skills from installed plugin marketplaces
    for marketplace_dir in ~/.claude/installed-plugins/*/
        for plugin_dir in $marketplace_dir/*/
            if test -d "$plugin_dir/skills"
                for skill_dir in $plugin_dir/skills/*/
                    set -l skill_file "$skill_dir/SKILL.md"
                    if test -f "$skill_file"
                        set -l name (basename $skill_dir)
                        set -l plugin_name (basename $plugin_dir)
                        set -l qualified "$plugin_name:$name"
                        set -l desc (_gwt_skill_description "$skill_file")
                        set -a skill_entries (printf '%s\t(plugin) %s' "$qualified" "$desc")
                        set -a skill_names $qualified
                    end
                end
            end
        end
    end

    if test (count $skill_entries) -eq 0
        commandline --function repaint
        return
    end

    # Collect already-selected skills to exclude from picker
    set -l already_selected
    set -l j (count $cmd)
    while test $j -ge 2
        set -l arg $cmd[$j]
        if test "$arg" = --skill
            break
        end
        if not string match -q -- '--*' "$arg"
            set -a already_selected $arg
        end
        set j (math $j - 1)
    end

    # Filter out already-selected skills
    set -l filtered_entries
    for entry in $skill_entries
        set -l entry_name (printf '%s' "$entry" | cut -f1)
        if not contains -- "$entry_name" $already_selected
            set -a filtered_entries "$entry"
        end
    end

    if test (count $filtered_entries) -eq 0
        commandline --function repaint
        return
    end

    # Launch FZF with multiselect
    set -l results (printf '%s\n' $filtered_entries \
        | fzf \
            --multi \
            --exit-0 \
            -d '\t' \
            --with-nth=1.. \
            --prompt='skill ❯ ' \
            --header='Select skills (TAB to toggle, Enter to confirm)' \
            --preview-window=right:50%:wrap \
            --query="$token" \
        | cut -f1)

    if test -n "$results"
        # Join selected skills with spaces and insert
        set -l selected (string join ' ' -- $results)
        commandline --replace --current-token -- "$selected"
        # Add trailing space so user can continue typing
        commandline --insert ' '
    end
    commandline --function repaint
end

function _gwt_skill_description -d "Extract description from SKILL.md frontmatter"
    # Extract description from YAML frontmatter, handling:
    # - Single-line: description: some text
    # - Multi-line:  description:\n  indented continuation
    # - No frontmatter: fall back to first # heading
    set -l desc ""
    set -l in_frontmatter false
    set -l reading_multiline false
    set -l first_heading ""
    set -l line_num 0
    while read -l line
        set line_num (math $line_num + 1)
        if test $line_num -gt 20
            break
        end
        if test $line_num -eq 1
            if test "$line" = ---
                set in_frontmatter true
                continue
            end
        end
        if $in_frontmatter
            if test "$line" = ---
                break
            end
            # Continue reading multi-line description (indented lines)
            if $reading_multiline
                if string match -qr '^\s+\S' "$line"
                    set -l continuation (string trim -- "$line")
                    set desc "$desc $continuation"
                    continue
                else
                    break
                end
            end
            # Match "description: text" (single-line) or "description:" (multi-line start)
            if string match -qr '^description:\s*$' "$line"
                set reading_multiline true
                continue
            end
            if string match -qr '^description:\s+(.+)' "$line"
                set desc (string replace -r '^description:\s+' '' -- "$line" | string trim -c '"' | string trim -c "'")
                break
            end
        else
            # No frontmatter: grab first heading as fallback
            if test -z "$first_heading"
                if string match -qr '^#\s+(.+)' "$line"
                    set first_heading (string replace -r '^#\s+' '' -- "$line")
                end
            end
        end
    end <$argv[1]
    set desc (string trim -- "$desc")
    if test -z "$desc"
        if test -n "$first_heading"
            set desc $first_heading
        else
            set desc "(no description)"
        end
    end
    # Truncate long descriptions for display
    if test (string length -- "$desc") -gt 80
        set desc (string sub -l 77 -- "$desc")"..."
    end
    echo $desc
end
