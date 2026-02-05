function llm-code --description "Code-focused LLM query using local Ollama"
    # Usage: llm-code <prompt>
    # Uses a coding-optimized model for development tasks.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: llm-code <prompt>"
        echo ""
        echo "Send a coding-focused query to the local Ollama instance."
        echo "Uses qwen2.5-coder:7b by default (set LLM_CODE_MODEL to override)."
        echo ""
        echo "Examples:"
        echo "  llm-code 'write a Python function to parse CSV files'"
        echo "  cat main.py | llm-code 'review this code for bugs'"
        echo "  git diff | llm-code 'write a commit message for these changes'"
        echo "  llm-code 'explain this error: connection refused on port 5432'"
        return 0
    end

    set -l model (set -q LLM_CODE_MODEL; and echo $LLM_CODE_MODEL; or echo "qwen2.5-coder:7b")

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

    if test (count $argv) -eq 0
        if not isatty stdin
            set -l input (cat)
            ollama run $model "$input"
        else
            echo "Usage: llm-code <prompt>"
            return 1
        end
    else
        set -l prompt (string join " " $argv)

        if not isatty stdin
            set -l input (cat)
            ollama run $model "Context:\n$input\n\nInstruction: $prompt"
        else
            ollama run $model "$prompt"
        end
    end
end
