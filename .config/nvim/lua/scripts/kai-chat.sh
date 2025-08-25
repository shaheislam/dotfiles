#!/bin/bash

# Enhanced Kai Chat Script with streaming and tool use support
# Usage: kai-chat.sh <mode> <context_file> <prompt>

MODE="$1"  # "chat" or "quick"
CONTEXT_FILE="$2"
PROMPT="$3"

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "Error: Claude CLI not found. Please install it first."
    exit 1
fi

if [ "$MODE" == "chat" ]; then
    # Chat mode - more conversational, shows tool use
    FULL_PROMPT="You are Claude, an AI assistant having a conversation with a user in Neovim.

CONTEXT FROM EDITOR:
$(cat "$CONTEXT_FILE")

Please provide helpful, conversational responses. When showing code, use markdown code blocks with language tags.
Show your reasoning when it would be helpful. Be concise but thorough.

User: $PROMPT"

    # Stream response with tool use visibility
    # Use a temp file to avoid shell escaping issues
    TEMP_PROMPT=$(mktemp)
    echo "$FULL_PROMPT" > "$TEMP_PROMPT"
    claude < "$TEMP_PROMPT" 2>&1
    rm -f "$TEMP_PROMPT"

elif [ "$MODE" == "quick" ]; then
    # Quick mode - the original kai-neovim behavior
    FULL_PROMPT="You are an AI assistant integrated into Neovim.

CURRENT EDITING CONTEXT:
$(cat "$CONTEXT_FILE")

CRITICAL: INTELLIGENT ACTION DETECTION
You must analyze the user's instruction to determine what they want:

1. If they say things like \"replace with\", \"change to\", \"rewrite as\", \"make this\", \"convert to\" → REPLACE the selected text
2. If they say things like \"write something like this\", \"create a note about\", \"add after\", \"insert\" → INSERT new content (don't replace)
3. If they say things like \"improve\", \"enhance\", \"fix\", \"correct\" → REPLACE with improved version
4. If they say things like \"explain this\", \"what is this\", \"analyze\", \"tell me about\", \"show me\", \"list\", \"count\", \"find\" → DISPLAY information (don't modify file)

RESPONSE FORMAT:
You must start your response with ONE of these action markers on its own line:
[ACTION:REPLACE]
[ACTION:INSERT_AFTER]
[ACTION:INSERT_BEFORE]
[ACTION:DISPLAY]

Then on the next line, provide the content:
- For REPLACE/INSERT actions: provide ONLY the text to insert (no explanations)
- For DISPLAY actions: provide the analysis/information to show the user

User instruction: $PROMPT"

    # Get response without streaming for parsing
    TEMP_FILE=$(mktemp)
    echo "$FULL_PROMPT" > "$TEMP_FILE"
    claude < "$TEMP_FILE" 2>/dev/null
    rm -f "$TEMP_FILE"
    
else
    echo "Error: Invalid mode. Use 'chat' or 'quick'"
    exit 1
fi

exit $?