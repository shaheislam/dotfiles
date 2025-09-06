# Auto-load 1Password secrets globally in Fish
# This runs once when Fish starts

if status is-interactive
    # Only load if 1Password CLI is available and authenticated
    if command -v op >/dev/null; and op account get >/dev/null 2>&1
        # Load common secrets
        set -gx LINEAR_API_KEY (op read "op://Personal/Linear/api_key" 2>/dev/null)
        set -gx GITHUB_TOKEN (op read "op://Personal/GitHub/token" 2>/dev/null)
        set -gx OPENAI_API_KEY (op read "op://Personal/OpenAI/api_key" 2>/dev/null)
        set -gx ANTHROPIC_API_KEY (op read "op://Personal/Anthropic/api_key" 2>/dev/null)
        
        # Silently fail if any are missing - don't break shell startup
    end
end