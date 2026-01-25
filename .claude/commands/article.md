---
name: article
description: Clip web article to Obsidian vault with metadata extraction
argument-hint: "<url> [--folder subfolder]"
allowed-tools: WebFetch, Read, Write, Glob, AskUserQuestion
---

# Article Clipping Workflow

Clip the article from: $ARGUMENTS

## Step 1: Parse Arguments

Extract URL and optional folder flag:

```
URL = first argument (the https://... URL)
FOLDER = value after --folder flag (if provided)
```

If no valid URL provided, ask for one.

## Step 2: Fetch Article Content

Use WebFetch to retrieve the article with this prompt:

> Extract the following from this article:
> 1. **Title**: The article title
> 2. **Author**: The author name (if available)
> 3. **Published Date**: Publication date in YYYY-MM-DD format (if available)
> 4. **Main Content**: The full article content converted to clean markdown
> 5. **Description**: A 1-2 sentence summary
>
> Format your response as:
> ```
> TITLE: [title]
> AUTHOR: [author or "Unknown"]
> PUBLISHED: [YYYY-MM-DD or "Unknown"]
> DESCRIPTION: [summary]
> ---
> [Full article content in markdown]
> ```

## Step 3: Generate Tags

Based on the URL domain and article content, generate relevant tags:

**Always include first**: `clippings`

**Domain-based tags** (detect from URL):
- `prometheus.io`, `grafana.com` → `prometheus`, `monitoring`, `observability`
- `oauth.net`, `auth0.com`, `propelauth.com` → `oauth`, `authentication`, `security`
- `github.com/blog`, `git-scm.com` → `git`, `github`, `version-control`
- `kubernetes.io`, `k8s` → `kubernetes`, `containers`, `devops`
- `aws.amazon.com`, `docs.aws` → `aws`, `cloud`
- `openai.com`, `anthropic.com`, AI topics → `ai`, `llm`
- `terraform.io`, `hashicorp` → `terraform`, `infrastructure`

**Content-based tags**: Extract 2-4 additional tags from key technologies, concepts, or frameworks mentioned.

## Step 4: Select Subfolder

Check existing subfolders:

```bash
ls ~/obsidian/Career/Articles/
```

Existing folders: AI, Certificates, Git, Mimir, OAuth, OpsGenie, Prometheus

**If `--folder` was specified**: Use that folder (create if needed)

**Otherwise**: Use AskUserQuestion to ask which folder:
- List existing folders as options
- Include "Create new folder" option
- Include "Root (no subfolder)" option

Auto-suggest based on primary tag matching folder name.

## Step 5: Generate Filename

Create filename from title:
1. Use the article title
2. Remove special characters except hyphens and spaces
3. Truncate to 100 characters if needed
4. Add `.md` extension

Example: `OAuth 2.1 in Simple Terms - PropelAuth.md`

## Step 6: Create Article File

Generate the file with this format:

```markdown
---
category: "[[Clippings]]"
author: "[[{AUTHOR}]]"
title: {TITLE}
source: {URL}
clipped: {TODAY in YYYY-MM-DD}
published: {PUBLISHED_DATE}
tags:
  - clippings
  - {tag1}
  - {tag2}
  - {tag3}
aliases: []
id: {TITLE}
---

{ARTICLE_CONTENT}
```

**Notes**:
- If author is "Unknown", use empty string: `author: ""`
- If published date is "Unknown", omit the `published` field entirely
- `id` should match the `title` field exactly
- `aliases` is always an empty array
- Ensure content is clean markdown with proper headings

## Step 7: Save and Confirm

Save to: `~/obsidian/Career/Articles/{FOLDER}/{FILENAME}`

Confirm with:
- File path
- Title
- Tags applied
- Source URL

## Error Handling

- **Invalid URL**: Ask user to provide valid URL
- **Fetch failed**: Report error, suggest trying again
- **Paywall/login required**: Save available metadata, note limitation
- **Duplicate detected**: Search for existing file with same source URL, ask whether to update or skip
