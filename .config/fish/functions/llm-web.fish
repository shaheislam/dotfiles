function llm-web --description "Launch Open WebUI for local LLM chat"
    # Usage: llm-web
    # Starts Open WebUI and opens it in the browser.

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: llm-web [--stop]"
        echo ""
        echo "Launch Open WebUI browser interface for chatting with local LLMs."
        echo "Provides a ChatGPT/Claude-like interface for your local models."
        echo ""
        echo "Options:"
        echo "  --stop    Stop running Open WebUI server"
        return 0
    end

    set -l port (set -q OPEN_WEBUI_PORT; and echo $OPEN_WEBUI_PORT; or echo "8080")

    if test "$argv[1]" = "--stop"
        pkill -f "open-webui" 2>/dev/null
        echo "Open WebUI stopped"
        return 0
    end

    # Check if already running
    if curl -sf "http://localhost:$port" >/dev/null 2>&1
        echo "Open WebUI already running at http://localhost:$port"
        open "http://localhost:$port"
        return 0
    end

    # Ensure Ollama is running first
    if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
        echo "Starting Ollama..."
        if test -d "/Applications/Ollama.app"
            open -a Ollama
        else
            ollama serve &>/dev/null &
        end
        sleep 3
    end

    # Check if open-webui is installed
    if not command -q open-webui
        echo "Open WebUI is not installed."
        echo "Install with: pipx install open-webui"
        return 1
    end

    echo "Starting Open WebUI on port $port..."
    open-webui serve --port $port &>/dev/null &
    disown

    # Wait for startup
    set -l attempts 0
    while not curl -sf "http://localhost:$port" >/dev/null 2>&1
        sleep 1
        set attempts (math $attempts + 1)
        if test $attempts -ge 20
            echo "Warning: Open WebUI taking longer than expected to start"
            echo "Check with: curl http://localhost:$port"
            return 0
        end
    end

    echo "Open WebUI running at http://localhost:$port"
    open "http://localhost:$port"
end
