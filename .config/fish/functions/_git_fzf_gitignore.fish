# Gitignore Generator using gitignore.io
# Interactive template selector with preview

function _git_fzf_gitignore -d "Interactive gitignore generator using gitignore.io"
    # Fetch template list
    set -l templates (curl -sL "https://www.toptal.com/developers/gitignore/api/list" 2>/dev/null | tr ',' '\n')

    if test -z "$templates"
        echo "Failed to fetch gitignore templates (check internet connection)"
        return 1
    end

    set -l selected (
        printf '%s\n' $templates | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="📝 Gitignore Generator" \
            --header="TAB: multi-select | ENTER: generate .gitignore" \
            --preview="curl -sL 'https://www.toptal.com/developers/gitignore/api/{}' 2>/dev/null | bat -l gitignore --color=always --style=plain 2>/dev/null || cat" \
            --preview-window="right:60%:wrap"
    )

    if test -n "$selected"
        set -l joined (string join ',' $selected)
        set -l content (curl -sL "https://www.toptal.com/developers/gitignore/api/$joined" 2>/dev/null)

        if test -z "$content"
            echo "Failed to fetch gitignore content"
            return 1
        end

        if test -f .gitignore
            echo "Appending to existing .gitignore..."
            echo "" >> .gitignore
            echo "$content" >> .gitignore
        else
            echo "$content" > .gitignore
        end
        echo "Generated .gitignore with: $joined"
    end
end
