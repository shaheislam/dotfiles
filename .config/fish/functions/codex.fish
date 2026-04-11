function codex --description "Run codex with automatic account rotation"
    if functions -q codex-rotate
        codex-rotate $argv
    else
        command codex $argv
    end
end
