---
name: youtube
description: Fetch YouTube transcript, summarize key points with AI, save to Obsidian vault, and emit chain data for downstream skills (e.g., /gap-analysis). Supports single URL or batch (multiple URLs or --file).
argument-hint: "<youtube-url> [youtube-url...] [--file urls.txt] [--folder subfolder] [--timestamps] [--no-summary]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion, WebFetch
---

# YouTube Transcript to Obsidian Workflow

Process the YouTube video(s) from: $ARGUMENTS

## Step 1: Parse Arguments

Extract URLs and optional flags:

```
URLS = all positional arguments that are valid YouTube URLs/video IDs
FILE = value after --file flag (path to file with one URL per line)
FOLDER = value after --folder flag (if provided)
TIMESTAMPS = true if --timestamps flag present
NO_SUMMARY = true if --no-summary flag present
```

**URL collection logic:**
- If `--file` is provided, read URLs from that file (one per line, skip blank lines and comments starting with `#`)
- Positional arguments that are valid YouTube URLs/video IDs are added to the URL list
- Combine both sources into a single `URLS` list
- Skip duplicate URLs

**Batch detection:**
- If `len(URLS) > 1` OR `--file` was used: run in **batch mode**
- If `len(URLS) == 1`: run in **single mode** (original behavior)
- If no valid URLs provided, ask for at least one

## Batch Mode

When processing multiple URLs, modify the workflow as follows:

### Shared Settings
- `--folder`, `--timestamps`, and `--no-summary` flags apply to ALL videos in the batch
- Folder selection (Step 6) happens ONCE before processing begins, not per video

### Per-URL Execution Loop
For each URL in the batch, run Steps 2–9. **Continue on failure** — if one URL fails (no transcript, fetch error, etc.), report the error and move to the next. Process all URLs, then report a batch summary.

### Folder Selection in Batch Mode
- If `--folder` was specified: use it for all videos
- If `--folder` was NOT specified: default to root (`~/obsidian/Career/Videos/`) — do NOT prompt interactively per video
- Pro tip: use `--folder` to organize batch output into a subfolder

### Batch Progress
During processing, report brief progress:
```
[1/3] Processing: {TITLE} ({URL})
  -> Saved: {FILE_PATH}
[2/3] Processing: {TITLE} ({URL})
  -> SKIPPED: No transcript available
[3/3] Processing: {TITLE} ({URL})
  -> Saved: {FILE_PATH}
```

### Batch Summary (after all URLs processed)
Report:
- Total URLs attempted
- Success count
- Failures (with reason per URL)
- List of all saved file paths

### Batch Chain Data
Emit a combined chain data block containing entries for all successfully processed videos:

```
<!-- CHAIN:youtube -->
```yaml
batch: true
videos:
  - file: {SAVED_FILE_PATH}
    title: "{TITLE}"
    source: {YOUTUBE_URL}
    urls: [...]
    tools: [...]
    topics: [...]
    tags: [...]
  - file: {SAVED_FILE_PATH}
    title: "{TITLE}"
    source: {YOUTUBE_URL}
    ...
```
<!-- /CHAIN:youtube -->
```

## Single Mode (original behavior)

Follow Steps 2–9 below for a single URL.

## Step 2: Fetch Transcript

Run the transcript fetcher script:

```bash
python3 ~/dotfiles/scripts/youtube/yt-transcript.py "<URL>" --json
```

This returns JSON with `video_id`, `url`, `text`, and `segments` (timestamped).

If the script fails (no transcript available), report the error and suggest alternatives:
- Try a different language: the video may have transcripts in other languages
- The video may not have captions enabled

## Step 3: Get Video Title

Use WebFetch on the YouTube URL to extract the video title. Look for the `<title>` tag or og:title meta tag.

If WebFetch fails, use the video ID as a fallback title.

## Step 4: Summarize with AI (unless --no-summary)

Using the raw transcript text, generate:

1. **Summary** (2-3 paragraphs): Distill the core message, main arguments, and conclusions. Strip out:
   - Sponsor segments and ads
   - "Like and subscribe" calls to action
   - Filler phrases, repetition, verbal tics
   - Entertainment-only dialogue that doesn't convey information

2. **Key Takeaways** (5-10 bullet points): The most actionable or informative points

3. **Topics Mentioned**: List of specific technologies, concepts, people, or tools discussed

4. **Discoverable References**: From the transcript text, extract:
   - Any URLs mentioned verbatim (GitHub repos, documentation sites, tool homepages)
   - For each tool/technology/framework/library named in Topics Mentioned, classify as: `tool`, `framework`, `library`, `platform`, `practice`, or `concept`
   - Do NOT web-search at this stage — just extract what is explicitly mentioned or commonly known

## Step 5: Generate Tags

Based on the video content, generate relevant tags:

**Always include first**: `youtube`, `transcript`

**Content-based tags**: Extract 2-4 additional tags from the key technologies, concepts, or frameworks discussed in the video. Use the Topics Mentioned from Step 4.

## Step 6: Select Subfolder

Check existing subfolders:

```bash
ls ~/obsidian/Career/Videos/ 2>/dev/null
```

**If `--folder` was specified**: Use that folder (create if needed)

**In batch mode without `--folder`**: Default to root (`~/obsidian/Career/Videos/`) — skip interactive prompt

**In single mode without `--folder`**: Use AskUserQuestion to ask which folder:
- List existing folders as options
- Include "Create new folder" option
- Include "Root (no subfolder)" option
- Auto-suggest based on primary tag matching folder name

## Step 7: Create Obsidian Note

Generate the file at `~/obsidian/Career/Videos/{FOLDER}/{FILENAME}.md`:

Filename format: `{YYYY-MM-DD}-{slugified-title}.md`

```markdown
---
category: "[[Clippings]]"
title: "{TITLE}"
source: {YOUTUBE_URL}
clipped: {TODAY in YYYY-MM-DD}
type: youtube-transcript
channel: "{CHANNEL_NAME if available}"
tags:
  - youtube
  - transcript
  - {tag1}
  - {tag2}
aliases: []
---

# {TITLE}

**Source:** {YOUTUBE_URL}
**Channel:** {CHANNEL_NAME}
**Transcribed:** {TODAY}

## Summary

{AI_SUMMARY}

## Key Takeaways

- {TAKEAWAY_1}
- {TAKEAWAY_2}
- ...

## Topics Mentioned

{TOPICS_LIST}

## Full Transcript

{TRANSCRIPT_TEXT - use timestamped version if --timestamps was set}
```

**Notes:**
- If channel is unknown, omit the `channel` frontmatter field and the Channel line
- Ensure the summary is concise and focuses on informational content
- `aliases` is always an empty array
- `id` is not needed (differs from article skill)

## Step 8: Confirm

Report:
- File path created
- Title
- Tags applied
- Summary length (word count)
- Number of key takeaways extracted
- Source URL

In batch mode, defer per-video confirmation to the batch summary.

## Step 8.5: Open in Neovim (best-effort)

Open the saved file in the Neovim pane if running in tmux:

```bash
bash ~/dotfiles/scripts/nvim-open-file.sh "{SAVED_FILE_PATH}"
```

This is best-effort — if not in tmux or no nvim pane exists, the script exits silently and the workflow continues.

In batch mode: only open the LAST successfully saved file (skip per-video opens).

## Step 9: Emit Chain Data (for downstream skills)

After confirmation, output a structured chain data block that downstream skills (e.g., `/gap-analysis`) can detect in conversation context. This block is always emitted — it is harmless when no downstream skill is listening.

**Single mode** — output:

```
<!-- CHAIN:youtube -->
```yaml
file: {SAVED_FILE_PATH}
title: "{TITLE}"
source: {YOUTUBE_URL}
urls:
  - {URL_1 from Discoverable References, if any}
  - {URL_2}
tools:
  - name: "{TOOL_NAME}"
    type: {tool|framework|library|platform|practice|concept}
  - ...
topics:
  - {content-based tags, excluding "youtube" and "transcript"}
tags:
  - {all generated tags}
```
<!-- /CHAIN:youtube -->
```

**Batch mode** — use the combined format described in the Batch Mode section.

**Rules for chain data:**
- `urls`: Only include URLs that were explicitly mentioned in the transcript or are well-known canonical URLs for tools discussed. If no URLs are discoverable, omit the `urls` key entirely.
- `tools`: Include every specific tool, framework, library, or platform from Topics Mentioned. Also include notable practices (e.g., "Test-Driven Development") with type `practice`.
- `topics`: The content-based tags (exclude the fixed "youtube" and "transcript" tags).
- `tags`: All tags including "youtube" and "transcript".
- If no tools or URLs were found, still emit the block with just `file`, `title`, `source`, `topics`, and `tags` (single mode) or the batch equivalent.

## Error Handling

- **Invalid URL**: Ask user to provide valid YouTube URL
- **No transcript**: Report that the video has no available captions; in batch mode, skip and continue
- **Script not found**: Suggest running `stow dotfiles` or checking setup
- **Fetch timeout**: Retry once, then report failure; in batch mode, skip and continue
- **--file path not found**: Report error and ask for correct path
