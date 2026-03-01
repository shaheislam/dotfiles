function _bridge_provider_fzf_tab_complete -d "FZF multiselect picker for --bridge-providers"
    set -l token (commandline --current-token)

    # Known providers with descriptions
    set -l entries \
        "codex\tOpenAI Codex CLI (default first provider)" \
        "gemini\tGoogle Gemini" \
        "ollama\tLocal Ollama models" \
        "deepseek\tDeepSeek API" \
        "claude\tClaude via subscription rotation" \
        "opencode\tOpenCode CLI"

    set -l results (printf '%s\n' $entries \
        | fzf \
            --multi \
            --exit-0 \
            -d '\t' \
            --with-nth=1.. \
            --prompt='bridge providers ❯ ' \
            --header='Select providers (TAB toggle, Enter confirm) — order matters' \
            --query="$token" \
        | cut -f1)

    if test -n "$results"
        # Join with commas for --bridge-providers format
        set -l selected (string join ',' -- $results)
        commandline --replace --current-token -- "$selected"
        commandline --insert ' '
    end
    commandline --function repaint
end
