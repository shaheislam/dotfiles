#!/bin/bash
# File Modification Hook
# Logs file modifications and can trigger additional actions

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name and file path using jq or python
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json, sys; print(json.load(sys.stdin).get('tool_name', ''))")
FILE_PATH=$(echo "$INPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('tool_input', {}).get('file_path', ''))")

# Log the modification
echo "📝 [File Modified Hook]"
echo "   Tool: $TOOL_NAME"
echo "   File: $FILE_PATH"
echo "   Time: $(date '+%Y-%m-%d %H:%M:%S')"

# If it's a Python file, could run a quick syntax check
if [[ "$FILE_PATH" == *.py ]]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
            echo "   ✅ Python syntax: Valid"
        else
            echo "   ❌ Python syntax: Invalid"
        fi
    fi
fi

# If it's a JSON file, validate it
if [[ "$FILE_PATH" == *.json ]]; then
    if command -v jq >/dev/null 2>&1; then
        if jq . "$FILE_PATH" >/dev/null 2>&1; then
            echo "   ✅ JSON syntax: Valid"
        else
            echo "   ❌ JSON syntax: Invalid"
        fi
    fi
fi

# Check file size
if [ -f "$FILE_PATH" ]; then
    SIZE=$(ls -lh "$FILE_PATH" | awk '{print $5}')
    echo "   📏 Size: $SIZE"
fi

echo ""  # Blank line for readability

# Always exit 0 to not block the operation
exit 0
