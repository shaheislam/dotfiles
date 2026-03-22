---
name: youtube
description: Fetch YouTube transcript, summarize key points with AI, save to Obsidian vault, and emit chain data for downstream skills (e.g., /gap-analysis)
argument-hint: "<youtube-url> [--folder subfolder] [--timestamps] [--no-summary]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion, WebFetch
---

# YouTube Transcript to Obsidian Workflow

Process the YouTube video from: $ARGUMENTS

## Step 1: Parse Arguments

Extract URL and optional flags:

```
URL = first argument (the https://... YouTube URL or video ID)
FOLDER = value after --folder flag (if provided)
TIMESTAMPS = true if --timestamps flag present
NO_SUMMARY = true if --no-summary flag present
```

If no valid URL provided, ask for one.

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

**Otherwise**: Use AskUserQuestion to ask which folder:
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

## Step 9: Emit Chain Data (for downstream skills)

After confirmation, output a structured chain data block that downstream skills (e.g., `/gap-analysis`) can detect in conversation context. This block is always emitted — it is harmless when no downstream skill is listening.

Output the following block exactly:

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

**Rules for chain data:**
- `urls`: Only include URLs that were explicitly mentioned in the transcript or are well-known canonical URLs for tools discussed. If no URLs are discoverable, omit the `urls` key entirely.
- `tools`: Include every specific tool, framework, library, or platform from Topics Mentioned. Also include notable practices (e.g., "Test-Driven Development") with type `practice`.
- `topics`: The content-based tags (exclude the fixed "youtube" and "transcript" tags).
- `tags`: All tags including "youtube" and "transcript".
- If no tools or URLs were found, still emit the block with just `file`, `title`, `source`, `topics`, and `tags`.

## Error Handling

- **Invalid URL**: Ask user to provide valid YouTube URL
- **No transcript**: Report that the video has no available captions
- **Script not found**: Suggest running `stow dotfiles` or checking setup
- **Fetch timeout**: Retry once, then report failure
