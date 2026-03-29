function _codex_workspace_id --description "Resolve the effective Codex ChatGPT workspace pin"
    set -l accounts_dir "$HOME/.codex/accounts"
    set -l name $argv[1]

    if set -q CODEX_CHATGPT_WORKSPACE_ID; and test -n "$CODEX_CHATGPT_WORKSPACE_ID"
        echo "$CODEX_CHATGPT_WORKSPACE_ID"
        return 0
    end

    if test -n "$name"
        set -l account_file "$accounts_dir/$name/workspace_id"
        if test -f "$account_file"
            set -l value (string trim -- (cat "$account_file" 2>/dev/null))
            if test -n "$value"
                echo "$value"
                return 0
            end
        end
    end

    set -l global_file "$accounts_dir/.workspace-id"
    if test -f "$global_file"
        set -l value (string trim -- (cat "$global_file" 2>/dev/null))
        if test -n "$value"
            echo "$value"
            return 0
        end
    end
end
