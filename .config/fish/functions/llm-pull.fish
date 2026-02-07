function llm-pull --description "Pull a new model for local LLM"
    # Usage: llm-pull <model>
    # Downloads a model from the Ollama registry.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"; or test (count $argv) -eq 0
        echo "Usage: llm-pull <model>"
        echo ""
        echo "Download a model from the Ollama registry."
        echo ""
        echo "Recommended models:"
        echo "  Coding:"
        echo "    qwen2.5-coder:7b       ~4GB   Fast coding assistant"
        echo "    deepseek-coder-v2:16b  ~9GB   Deep reasoning for code"
        echo "    qwen2.5-coder:32b      ~18GB  Premium coding (32GB+ RAM)"
        echo ""
        echo "  General:"
        echo "    llama3.1:8b            ~4GB   Fast general-purpose"
        echo "    mistral:7b             ~4GB   Balanced all-rounder"
        echo "    llama3.1:70b           ~40GB  Premium general (64GB+ RAM)"
        echo ""
        echo "  Specialized:"
        echo "    codellama:13b          ~7GB   Meta's coding model"
        echo "    phi3:14b               ~8GB   Microsoft's efficient model"
        echo "    gemma2:9b              ~5GB   Google's open model"
        echo ""
        echo "Browse all: https://ollama.com/library"
        return 0
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

    for model in $argv
        echo "Pulling $model..."
        ollama pull $model
    end
end
