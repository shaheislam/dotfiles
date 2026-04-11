---
name: diagram
description: Create visual diagrams with live preview, saving to Obsidian vault
argument-hint: "description [--embed note.md]"
---

# Diagram Creation Workflow

Create a visual diagram based on: $ARGUMENTS

## Step 0: Parse Arguments

Extract the diagram description and optional embed target:

```bash
EMBED_TARGET=""
DIAGRAM_DESC="$ARGUMENTS"

# Extract --embed flag (handles quoted paths)
if [[ "$ARGUMENTS" =~ --embed[[:space:]]+(\"[^\"]+\"|[^[:space:]]+) ]]; then
    EMBED_TARGET="${BASH_REMATCH[1]//\"/}"
    DIAGRAM_DESC=$(echo "$ARGUMENTS" | sed -E 's/--embed[[:space:]]+(\"[^\"]+\"|\S+)//g' | xargs)
fi

echo "Diagram: $DIAGRAM_DESC"
[[ -n "$EMBED_TARGET" ]] && echo "Embed in: $EMBED_TARGET"
```

## Step 1: Start Canvas Server

```bash
if ! curl -s http://localhost:3000/health >/dev/null 2>&1; then
    echo "Starting Excalidraw canvas server..."
    cd ~/tools/mcp_excalidraw && npm run dev &
    sleep 5
    echo "Canvas server started"
fi
open http://localhost:3000
```

## Step 2: Create the Diagram

Clear existing elements, then batch create via REST API:

```bash
# Clear existing
curl -s http://localhost:3000/api/elements | jq -r '.elements[].id' | while read id; do
  curl -s -X DELETE "http://localhost:3000/api/elements/$id" > /dev/null
done

# Batch create
curl -s -X POST http://localhost:3000/api/elements/batch \
  -H "Content-Type: application/json" \
  -d '{"elements": [...]}'
```

### Element Schema

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | Yes | rectangle, ellipse, diamond, text, line, arrow |
| x, y | number | Yes | Position coordinates |
| width, height | number | For shapes | Dimensions |
| text | string | For text | Text content |
| fontSize | number | For text | Font size (default 14) |
| backgroundColor | string | No | Fill color (hex) |
| strokeColor | string | No | Border/text color (hex) |
| strokeWidth | number | No | Border width |

### Color Palette (Tokyo Night theme)
- **Blue tier:** bg=#e3f2fd, stroke=#1976d2, accent=#1565c0
- **Orange tier:** bg=#fff3e0, stroke=#ff9800, accent=#ef6c00
- **Green tier:** bg=#e8f5e9, stroke=#388e3c, accent=#2e7d32
- **Purple:** bg=#e1bee7, stroke=#7b1fa2
- **Gray:** bg=#f5f5f5, stroke=#9e9e9e
- **Text:** #333333

## Step 3: Save to Obsidian

```bash
FILENAME=$(echo "$DIAGRAM_DESC" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

curl -s -X POST http://localhost:3000/api/obsidian/save \
  -H "Content-Type: application/json" \
  -d "{\"filename\": \"$FILENAME\"}" | jq .
```

Saved to: `~/obsidian/Excalidraw/${FILENAME}.excalidraw.md`

## Step 4: Embed in Target Note (if --embed specified)

If `--embed` flag was provided, find the note and add embed link:

```bash
if [[ -n "$EMBED_TARGET" ]]; then
    VAULT_ROOT="$HOME/obsidian"

    # Resolve target note path
    if [[ "$EMBED_TARGET" == *"/"* ]]; then
        # Path provided - use directly
        TARGET_NOTE="${VAULT_ROOT}/${EMBED_TARGET}"
        [[ ! "$TARGET_NOTE" == *.md ]] && TARGET_NOTE="${TARGET_NOTE}.md"
    else
        # Filename only - search vault
        SEARCH_TERM="${EMBED_TARGET%.md}"
        MATCHES=$(find "$VAULT_ROOT" -name "*${SEARCH_TERM}*.md" -type f ! -path "*/.*" ! -name "*.excalidraw.md" 2>/dev/null)
        MATCH_COUNT=$(echo "$MATCHES" | grep -c . || echo 0)

        if [[ $MATCH_COUNT -eq 0 ]]; then
            echo "ERROR: No notes found matching '$SEARCH_TERM'"
            echo "Try: --embed 'path/to/note.md'"
        elif [[ $MATCH_COUNT -eq 1 ]]; then
            TARGET_NOTE="$MATCHES"
        else
            echo "Multiple matches for '$SEARCH_TERM':"
            echo "$MATCHES" | sed "s|$VAULT_ROOT/||"
            echo ""
            echo "Specify full path: --embed 'path/to/note.md'"
        fi
    fi

    # Insert embed if note found
    if [[ -f "$TARGET_NOTE" ]]; then
        # Check for existing embed
        if grep -q "!\[\[${FILENAME}\.excalidraw\]\]" "$TARGET_NOTE" 2>/dev/null; then
            echo "Already embedded in $(basename "$TARGET_NOTE")"
        else
            # Add ## Diagrams section if not present
            echo "" >> "$TARGET_NOTE"
            if ! grep -q "^## Diagrams" "$TARGET_NOTE"; then
                echo "## Diagrams" >> "$TARGET_NOTE"
                echo "" >> "$TARGET_NOTE"
            fi
            echo "![[${FILENAME}.excalidraw]]" >> "$TARGET_NOTE"
            echo "Embedded in: $(echo "$TARGET_NOTE" | sed "s|$VAULT_ROOT/||")"
        fi
    fi
fi
```

## Step 5: Open in Neovim (best-effort)

Open the saved diagram in the Neovim pane if running in tmux:

```bash
bash ~/dotfiles/scripts/nvim-open-file.sh ~/obsidian/Excalidraw/${FILENAME}.excalidraw.md
```

Or if `--embed` was used, open the target note instead:

```bash
bash ~/dotfiles/scripts/nvim-open-file.sh "$TARGET_NOTE"
```

This is best-effort — if not in tmux or no nvim pane exists, the script exits silently.
