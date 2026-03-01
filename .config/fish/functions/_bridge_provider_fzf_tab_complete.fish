function _bridge_provider_fzf_tab_complete -d "FZF multiselect picker for bridge providers"
    set -l token (commandline --current-token)

    # Known providers with descriptions (space-padded for alignment)
    set -l entries
    set -a entries (printf '%-10s  %s' codex "OpenAI Codex CLI (default first provider)")
    set -a entries (printf '%-10s  %s' gemini "Google Gemini")
    set -a entries (printf '%-10s  %s' ollama "Local Ollama models")
    set -a entries (printf '%-10s  %s' deepseek "DeepSeek API")
    set -a entries (printf '%-10s  %s' claude "Claude via subscription rotation")
    set -a entries (printf '%-10s  %s' opencode "OpenCode CLI")

    set -l results (printf '%s\n' $entries \
        | fzf \
            --multi \
            --exit-0 \
            --prompt='bridge providers ❯ ' \
            --header='Select providers (TAB toggle, Enter confirm) — order matters' \
            --query="$token")

    if test -n "$results"
        # Extract first word from each selected line, join with commas
        set -l names
        for line in $results
            set -a names (string match -r '^\S+' -- "$line")
        end
        set -l selected (string join ',' -- $names)
        # Insert --bridge-providers flag+value (--bridge is already on the command line)
        commandline --replace --current-token -- "--bridge-providers $selected"
        commandline --insert ' '
    end
    commandline --function repaint
end
