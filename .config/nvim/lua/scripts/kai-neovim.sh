#!/bin/bash

# Kai Neovim Enhancement Script with Intelligent Action Detection
# Usage: kai-neovim.sh <context_file> <prompt>

CONTEXT_FILE="$1"
PROMPT="$2"

# Check if claude CLI is available (we use it to communicate with Kai)
if ! command -v claude &> /dev/null; then
    echo "Error: Claude CLI not found. Please install it first."
    exit 1
fi

# Regular text enhancement request - let Kai determine the action
FULL_PROMPT="You are an AI assistant integrated into Neovim.

CURRENT EDITING CONTEXT:
$(cat "$CONTEXT_FILE")

CRITICAL: INTELLIGENT ACTION DETECTION
You must analyze the user's instruction to determine what they want:

1. If they say things like \"replace with\", \"change to\", \"rewrite as\", \"make this\", \"convert to\" → REPLACE the selected text
2. If they say things like \"write something like this\", \"create a note about\", \"add after\", \"insert\" → INSERT new content (don't replace)
3. If they say things like \"improve\", \"enhance\", \"fix\", \"correct\" → REPLACE with improved version
4. If they say things like \"explain this\", \"what is this\", \"analyze\", \"tell me about\", \"show me\", \"list\", \"count\", \"find\" → DISPLAY information (don't modify file)

IMPORTANT: When working with selected text, focus on that specific text within the context of the entire buffer. When working without selection, make targeted changes at the cursor location.

RESPONSE FORMAT:
You must start your response with ONE of these action markers on its own line:
[ACTION:REPLACE]
[ACTION:INSERT_AFTER]
[ACTION:INSERT_BEFORE]
[ACTION:DISPLAY]

Then on the next line, provide the content:
- For REPLACE/INSERT actions: provide ONLY the text to insert (no explanations)
- For DISPLAY actions: provide the analysis/information to show the user

IMPORTANT INSTRUCTIONS:
- First line must be the action marker
- Follow ALL formatting rules from CLAUDE.md
- Maintain the code style and conventions of the file
- Consider the context when generating content
- You are Kai, the AI assistant integrated into Neovim

User instruction: $PROMPT"

# Get the response with action marker
# Using a temporary file to avoid shell escaping issues
TEMP_PROMPT_FILE=$(mktemp)
echo "$FULL_PROMPT" > "$TEMP_PROMPT_FILE"
RESPONSE=$(claude < "$TEMP_PROMPT_FILE" 2>/dev/null)
rm -f "$TEMP_PROMPT_FILE"

# Output the response
echo "$RESPONSE"

# Exit with the command's exit code
exit $?