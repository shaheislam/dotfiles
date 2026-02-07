function llm --description "Quick LLM query using local Ollama"
    # Usage: llm <prompt>
    # Uses the default general model for quick queries.
    # For coding tasks, use llm-code instead.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: llm <prompt>"
        echo ""
        echo "Send a quick query to the local Ollama instance."
        echo "Uses llama3.1:8b by default (set LLM_DEFAULT_MODEL to override)."
        echo ""
        echo "Examples:"
        echo "  llm 'explain kubernetes pod lifecycle'"
        echo "  llm 'write a bash one-liner to find large files'"
        echo "  echo 'some text' | llm 'summarize this'"
        echo ""
        echo "Related commands:"
        echo "  llm-code     Code-focused queries (uses coding model)"
        echo "  llm-chat     Interactive chat session"
        echo "  llm-status   Check Ollama status and models"
        echo "  llm-pull     Pull a new model"
        echo "  llm-web      Launch Open WebUI"
        return 0
    end

    set -l model (set -q LLM_DEFAULT_MODEL; and echo $LLM_DEFAULT_MODEL; or echo "llama3.1:8b")

    # Check if Ollama is running
    if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
        echo "Ollama is not running. Starting..."
        if test -d "/Applications/Ollama.app"
            open -a Ollama
        else
            ollama serve &>/dev/null &
        end
        # Wait for startup
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
        # Check for piped input
        if not isatty stdin
            set -l input (cat)
            ollama run $model "$input"
        else
            echo "Usage: llm <prompt>"
            echo "  or:  echo 'text' | llm 'instruction'"
            return 1
        end
    else
        set -l prompt (string join " " $argv)

        # Check for piped input to prepend as context
        if not isatty stdin
            set -l input (cat)
            ollama run $model "Context:\n$input\n\nInstruction: $prompt"
        else
            ollama run $model "$prompt"
        end
    end
end
