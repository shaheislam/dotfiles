function llm-status --description "Check local LLM status and installed models"
    # Usage: llm-status
    # Shows Ollama server status, installed models, and resource usage.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: llm-status"
        echo ""
        echo "Display the status of the local LLM stack:"
        echo "  - Ollama server status"
        echo "  - Installed models and sizes"
        echo "  - Currently running models"
        echo "  - Open WebUI status"
        return 0
    end

    echo "=== Local LLM Status ==="
    echo ""

    # Ollama server status
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
        echo "Ollama Server:  running (localhost:11434)"
    else
        echo "Ollama Server:  stopped"
        echo ""
        echo "Start with: ollama serve (or open Ollama.app on macOS)"
        return 0
    end

    # Currently running models
    echo ""
    echo "Running Models:"
    set -l running (ollama ps 2>/dev/null)
    if test -n "$running"
        echo "$running"
    else
        echo "  (none)"
    end

    # Installed models
    echo ""
    echo "Installed Models:"
    ollama list 2>/dev/null

    # Open WebUI status
    echo ""
    set -l webui_port (set -q OPEN_WEBUI_PORT; and echo $OPEN_WEBUI_PORT; or echo "8080")
    if curl -sf "http://localhost:$webui_port" >/dev/null 2>&1
        echo "Open WebUI:     running (localhost:$webui_port)"
    else
        echo "Open WebUI:     not running"
        echo "  Start with: open-webui serve"
    end

    # Disk usage
    echo ""
    if test -d "$HOME/.ollama"
        echo "Model Storage:"
        du -sh "$HOME/.ollama" 2>/dev/null | awk '{print "  " $1 " total"}'
    end
end
