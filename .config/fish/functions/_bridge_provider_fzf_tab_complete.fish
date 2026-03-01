function _bridge_provider_fzf_tab_complete -d "FZF multiselect picker for bridge providers"
    set -l token (commandline --current-token)

    # Known providers with descriptions (tab-separated via printf)
    set -l entries
    set -a entries (printf '%s\t%s' codex "OpenAI Codex CLI (default first provider)")
    set -a entries (printf '%s\t%s' gemini "Google Gemini")
    set -a entries (printf '%s\t%s' ollama "Local Ollama models")
    set -a entries (printf '%s\t%s' deepseek "DeepSeek API")
    set -a entries (printf '%s\t%s' claude "Claude via subscription rotation")
    set -a entries (printf '%s\t%s' opencode "OpenCode CLI")

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
        set -l selected (string join ',' -- $results)
        # Insert --bridge-providers flag+value (--bridge is already on the command line)
        commandline --replace --current-token -- "--bridge-providers $selected"
        commandline --insert ' '
    end
    commandline --function repaint
end
