function claude-local --description "Run Claude Code with local Ollama models"
    # Usage: claude-local [--model MODEL] [claude args...]
    # Launches Claude Code pointed at the local Ollama API.
    # Default model: qwen3-coder (256K context, agentic coding)

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: claude-local [--model MODEL] [claude args...]"
        echo ""
        echo "Run Claude Code against local Ollama models."
        echo "Default model: qwen3-coder (set --model to override)."
        echo ""
        echo "Options:"
        echo "  --model MODEL   Ollama model to use (default: qwen3-coder)"
        echo "  All other args are passed through to claude."
        echo ""
        echo "Examples:"
        echo "  claude-local                         # Start with qwen3-coder"
        echo "  claude-local --model llama3.1:8b     # Use a different model"
        echo "  claude-local -p 'fix the bug'        # Pass prompt to claude"
        echo ""
        echo "Related commands:"
        echo "  opencode-local   OpenCode with local Ollama (primary)"
        echo "  llm-code         Quick coding queries"
        echo "  llm-status       Check Ollama status"
        return 0
    end

    # Parse --model flag
    set -l model "qwen3-coder"
    set -l claude_args

    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = "--model"; and test $i -lt (count $argv)
            set i (math $i + 1)
            set model $argv[$i]
        else
            set -a claude_args $argv[$i]
        end
        set i (math $i + 1)
    end

    # Ensure Ollama is running
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

    # Check if model is available
    if not ollama list 2>/dev/null | string match -qr "^$model"
        echo "Model '$model' not found locally. Pulling..."
        ollama pull $model
        or begin
            echo "Error: Failed to pull model '$model'"
            return 1
        end
    end

    # Launch Claude Code with Ollama backend
    echo "Starting Claude Code with local model: $model"
    ANTHROPIC_BASE_URL=http://localhost:11434 \
    ANTHROPIC_API_KEY=ollama \
    ANTHROPIC_MODEL=$model \
    claude $claude_args
end
