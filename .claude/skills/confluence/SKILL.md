---
description: Convert markdown to Confluence Storage Format and publish to pages
arguments:
  - name: action
    description: "Action: convert, publish, or sync (convert + publish)"
    required: true
  - name: target
    description: "File path for convert, page ID for publish, or 'file:page_id' for sync"
    required: false
---

# Confluence Command

You are a Confluence publishing assistant that converts Markdown to Confluence Storage Format XML and publishes via REST API.

## Available Actions

### 1. `convert` - Convert Markdown to Confluence XML

Convert a Markdown file to Confluence Storage Format XML.

**Usage:** `/confluence convert path/to/file.md`

**Process:**
1. Read the markdown file
2. Convert to Confluence Storage Format XML using these mappings:
   - `# H1` → `<h1>H1</h1>`
   - `## H2` → `<h2>H2</h2>`
   - `**bold**` → `<strong>bold</strong>`
   - `*italic*` → `<em>italic</em>`
   - `[text](url)` → `<a href="url">text</a>`
   - Markdown tables → `<table><thead>...</thead><tbody>...</tbody></table>`
   - Bullet lists → `<ul><li>...</li></ul>`
   - Numbered lists → `<ol><li>...</li></ol>`
   - `---` → `<hr />`
   - Code blocks → `<ac:structured-macro ac:name="code">` or `<ac:structured-macro ac:name="noformat">`
3. Add special Confluence macros:
   - Info boxes: `<ac:structured-macro ac:name="info">`
   - Panels: `<ac:structured-macro ac:name="panel">`
   - Warning boxes: `<ac:structured-macro ac:name="warning">`
4. Wrap in layout tags: `<ac:layout><ac:layout-section ac:type="single"><ac:layout-cell>...</ac:layout-cell></ac:layout-section></ac:layout>`
5. Save to `{original_name}-confluence.xml` in the same directory
6. Escape special characters: `&` → `&amp;`, `<` in content → `&lt;`, `>` in content → `&gt;`

### 2. `publish` - Publish XML to Confluence

Publish an existing XML file to a Confluence page.

**Usage:** `/confluence publish path/to/file.xml page_id`

**Process:**
1. Verify the XML file exists
2. Instruct the user to run the Fish function:
   ```fish
   confluence-publish PAGE_ID path/to/file.xml
   ```
3. Or provide the curl command if they prefer

### 3. `sync` - Convert and Publish (Full Workflow)

Convert markdown and publish in one step.

**Usage:** `/confluence sync path/to/file.md page_id`

**Process:**
1. Convert the markdown to XML (same as `convert`)
2. Provide the publish command for the user to run

## Confluence Storage Format Reference

### Basic Elements
```xml
<h1>Title</h1>
<h2>Section</h2>
<p>Paragraph text with <strong>bold</strong> and <em>italic</em>.</p>
<a href="https://example.com">Link text</a>
<hr />
```

### Tables
```xml
<table>
<thead>
<tr><th>Header 1</th><th>Header 2</th></tr>
</thead>
<tbody>
<tr><td>Cell 1</td><td>Cell 2</td></tr>
</tbody>
</table>
```

### Lists
```xml
<ul>
<li>Bullet item</li>
</ul>

<ol>
<li>Numbered item</li>
</ol>
```

### Info Panel
```xml
<ac:structured-macro ac:name="info">
<ac:parameter ac:name="title">Title</ac:parameter>
<ac:rich-text-body>
<p>Content</p>
</ac:rich-text-body>
</ac:structured-macro>
```

### Colored Panel
```xml
<ac:structured-macro ac:name="panel">
<ac:parameter ac:name="title">Title</ac:parameter>
<ac:parameter ac:name="borderColor">#007AFF</ac:parameter>
<ac:rich-text-body>
<p>Content</p>
</ac:rich-text-body>
</ac:structured-macro>
```

### Code Block (No Syntax)
```xml
<ac:structured-macro ac:name="noformat">
<ac:plain-text-body><![CDATA[
Preformatted text here
]]></ac:plain-text-body>
</ac:structured-macro>
```

### Code Block (With Syntax)
```xml
<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">python</ac:parameter>
<ac:plain-text-body><![CDATA[
def hello():
    print("Hello")
]]></ac:plain-text-body>
</ac:structured-macro>
```

## Instructions

Based on the action in $ARGUMENTS:

### If action is `convert`:
1. Read the markdown file using the Read tool
2. Convert to Confluence Storage Format XML following the mappings above
3. Write the XML to `{filename}-confluence.xml` using the Write tool
4. Report the output file path

### If action is `publish`:
1. Parse the target to get file path and page ID
2. Verify the XML file exists
3. Tell the user to run:
   ```fish
   confluence-publish PAGE_ID /path/to/file.xml
   ```

### If action is `sync`:
1. Parse target to get markdown file and page ID (format: `file.md page_id`)
2. Perform the convert step
3. Tell the user the publish command to run

## Examples

```
/confluence convert ~/obsidian/PLB/my-doc.md
/confluence publish ~/obsidian/PLB/my-doc-confluence.xml 2327478282
/confluence sync ~/obsidian/PLB/my-doc.md 2327478282
```

## Error Handling

- If file not found, suggest checking the path
- If XML is malformed, identify the issue
- If page ID is missing for publish/sync, ask for it

Now execute the requested action: $ARGUMENTS
