function opencode-local --description "Run OpenCode with local Ollama models"
    # Usage: opencode-local [opencode args...]
    # Ensures Ollama is running, then launches OpenCode.
    # OpenCode config at ~/.config/opencode/opencode.json defines the Ollama provider.

    if test "$argv[1]" = --help; or test "$argv[1]" = -h
        echo "Usage: opencode-local [opencode args...]"
        echo ""
        echo "Run OpenCode with local Ollama as the AI backend."
        echo "Ensures Ollama is running before launching OpenCode."
        echo "Model configured in ~/.config/opencode/opencode.json (default: qwen3-coder)."
        echo ""
        echo "Examples:"
        echo "  opencode-local                       # Start OpenCode with local model"
        echo "  opencode-local --help                # Show this help"
        echo ""
        echo "Related commands:"
        echo "  claude-local     Claude Code with local Ollama"
        echo "  llm-code         Quick coding queries"
        echo "  llm-status       Check Ollama status"
        return 0
    end

    # Check if opencode is installed
    if not command -q opencode
        echo "Error: opencode is not installed"
        echo "Install with: brew install leohenon/tap/ocv"
        return 1
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

    # Check if qwen3-coder is available (default model in opencode.json)
    if not ollama list 2>/dev/null | string match -qr '^qwen3-coder'
        echo "Default model qwen3-coder not found. Pulling..."
        ollama pull qwen3-coder
        or begin
            echo "Warning: Failed to pull qwen3-coder, OpenCode may prompt for model selection"
        end
    end

    echo "Starting OpenCode with local Ollama backend..."
    opencode $argv
end
