function llm-chat --description "Interactive chat session with local LLM"
    # Usage: llm-chat [model]
    # Opens an interactive chat session. Ctrl+D to exit.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: llm-chat [model]"
        echo ""
        echo "Start an interactive chat session with a local LLM."
        echo "Defaults to llama3.1:8b. Use Ctrl+D or /bye to exit."
        echo ""
        echo "Examples:"
        echo "  llm-chat                       # Default model"
        echo "  llm-chat qwen2.5-coder:7b     # Coding model"
        echo "  llm-chat mistral:7b            # Mistral model"
        echo ""
        echo "Available models: run 'llm-status' to see installed models"
        return 0
    end

    set -l model $argv[1]
    if test -z "$model"
        set model (set -q LLM_DEFAULT_MODEL; and echo $LLM_DEFAULT_MODEL; or echo "llama3.1:8b")
    end

    # Check if Ollama is running
    if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
        echo "Ollama is not running. Starting..."
        if test -d "/Applications/Ollama.app"
            open -a Ollama
        else
            ollama serve &>/dev/null &
        end
        set -l attempts 0
        while not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
            sleep 1
            set attempts (math $attempts + 1)
            if test $attempts -ge 15
                echo "Error: Ollama failed to start"
                return 1
            end
        end
    end

    echo "Starting chat with $model (Ctrl+D or /bye to exit)"
    echo ""
    ollama run $model
end
