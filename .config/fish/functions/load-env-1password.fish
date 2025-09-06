function load-env-1password --description "Load environment variables from 1Password"
    # Check if op is installed
    if not command -v op >/dev/null
        echo "Error: 1Password CLI not installed"
        return 1
    end

    # Check if authenticated
    if not op account get >/dev/null 2>&1
        echo "⚠️  Not authenticated with 1Password. Run: op-auth"
        return 1
    end

    echo "Loading environment variables from 1Password..."

    # Function to safely load a secret from 1Password
    function _load_secret
        set -l item_name $argv[1]
        set -l var_name $argv[2]
        set -l field_name $argv[3]
        
        # Default field is notesPlain for your setup
        if test -z "$field_name"
            set field_name "notesPlain"
        end
        
        # Try to get the item
        set -l value (op item get "$item_name" --fields "label=$field_name" 2>/dev/null)
        if test $status -eq 0; and test -n "$value"
            set -gx $var_name $value
            echo "  ✓ Loaded $var_name"
        else
            # Try alternate method for items that exist
            set -l value (op item get "$item_name" --fields "$field_name" 2>/dev/null)
            if test $status -eq 0; and test -n "$value"
                set -gx $var_name $value
                echo "  ✓ Loaded $var_name"
            else
                echo "  ⚠️  Failed to load $var_name (item: $item_name)"
            end
        end
    end

    # Load API keys using actual item names in your 1Password
    _load_secret "LINEAR_API_KEY" LINEAR_API_KEY notesPlain
    _load_secret "Claude API Key" ANTHROPIC_API_KEY password
    
    # Try to load others if they exist (you'll need to create these in 1Password)
    _load_secret "GitHub Token" GITHUB_TOKEN notesPlain
    _load_secret "OpenAI API Key" OPENAI_API_KEY notesPlain
    _load_secret "OpenRouter API Key" OPENROUTER_API_KEY notesPlain
    _load_secret "DeepSeek API Key" DEEPSEEK_API_KEY notesPlain
    _load_secret "Gemini API Key" GEMINI_API_KEY notesPlain
    _load_secret "Exa API Key" EXA_API_KEY notesPlain
    
    # Set other environment variables
    set -gx EDITOR nvim
    set -gx PAGER less
    
    echo "✅ Environment loaded from 1Password"
end