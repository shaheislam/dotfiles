function _git_fzf_gitattributes -d "Interactive gitattributes generator"
    # Local cache directory for gitattributes repo
    set -l cache_dir "$HOME/.cache/forgit/gitattributes"
    set -l repo_url "https://github.com/gitattributes/gitattributes"

    # Clone or update the repo
    if not test -d "$cache_dir"
        echo "Cloning gitattributes templates..."
        git clone --depth=1 "$repo_url" "$cache_dir" 2>/dev/null
        or begin
            echo "Failed to clone gitattributes repository"
            return 1
        end
    else
        # Update if older than 7 days
        set -l repo_age (math (date +%s) - (stat -f %m "$cache_dir/.git/FETCH_HEAD" 2>/dev/null || echo 0))
        if test $repo_age -gt 604800
            echo "Updating gitattributes templates..."
            git -C "$cache_dir" pull --ff-only 2>/dev/null
        end
    end

    # Find all .gitattributes files and extract template names
    set -l templates (find "$cache_dir" -name "*.gitattributes" -type f 2>/dev/null | \
        sed "s|$cache_dir/||" | sed 's/.gitattributes$//' | sort)

    if test -z "$templates"
        echo "No gitattributes templates found"
        return 1
    end

    set -l selected (
        printf '%s\n' $templates | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="📋 Gitattributes Generator" \
            --header="TAB: multi-select | ENTER: generate .gitattributes" \
            --preview="bat -l gitattributes --color=always --style=plain '$cache_dir/{}.gitattributes' 2>/dev/null || cat '$cache_dir/{}.gitattributes'" \
            --preview-window="right:60%:wrap"
    )

    if test -n "$selected"
        set -l output ""
        for template in $selected
            set -l file "$cache_dir/$template.gitattributes"
            if test -f "$file"
                set output "$output\n### $template\n"(cat "$file")"\n"
            end
        end

        if test -f .gitattributes
            echo "Appending to existing .gitattributes..."
            echo "" >> .gitattributes
            printf "%b" "$output" >> .gitattributes
        else
            printf "%b" "$output" > .gitattributes
        end
        echo "Generated .gitattributes with:" (string join ', ' $selected)
    end
end
