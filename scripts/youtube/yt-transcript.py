#!/usr/bin/env python3
"""Fetch YouTube video transcripts and output as text or Obsidian note.

Usage:
    yt-transcript.py <url> [--json] [--obsidian]

Outputs transcript text to stdout. With --json, outputs structured JSON
including video metadata. With --obsidian, writes a note to the vault.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import date
from pathlib import Path
from urllib.parse import parse_qs, urlparse

try:
    from youtube_transcript_api import YouTubeTranscriptApi
except ImportError:
    # Try loading from pipx venv if system Python doesn't have it
    _pipx_venv = Path.home() / ".local/pipx/venvs/youtube-transcript-api/lib"
    _site_pkgs = next(_pipx_venv.glob("python*/site-packages"), None) if _pipx_venv.exists() else None
    if _site_pkgs:
        sys.path.insert(0, str(_site_pkgs))
        from youtube_transcript_api import YouTubeTranscriptApi
    else:
        print("Error: youtube-transcript-api not installed.", file=sys.stderr)
        print("Install with: pipx install youtube-transcript-api", file=sys.stderr)
        sys.exit(1)


def extract_video_id(url: str) -> str | None:
    """Extract YouTube video ID from various URL formats."""
    parsed = urlparse(url)

    # youtu.be/VIDEO_ID
    if parsed.hostname in ("youtu.be",):
        return parsed.path.lstrip("/").split("/")[0] or None

    # youtube.com/watch?v=VIDEO_ID
    if parsed.hostname in ("www.youtube.com", "youtube.com", "m.youtube.com"):
        if parsed.path == "/watch":
            qs = parse_qs(parsed.query)
            return qs.get("v", [None])[0]
        # youtube.com/embed/VIDEO_ID or youtube.com/v/VIDEO_ID
        if parsed.path.startswith(("/embed/", "/v/")):
            return parsed.path.split("/")[2] or None
        # youtube.com/shorts/VIDEO_ID
        if parsed.path.startswith("/shorts/"):
            return parsed.path.split("/")[2] or None

    # Bare video ID (11 chars, alphanumeric + _ -)
    if re.match(r"^[\w-]{11}$", url):
        return url

    return None


def fetch_transcript(video_id: str) -> list[dict]:
    """Fetch transcript for a video. Returns list of {text, start, duration}."""
    ytt_api = YouTubeTranscriptApi()
    transcript = ytt_api.fetch(video_id)
    return [
        {
            "text": snippet.text,
            "start": snippet.start,
            "duration": snippet.duration,
        }
        for snippet in transcript.snippets
    ]


def transcript_to_text(segments: list[dict]) -> str:
    """Convert transcript segments to plain text."""
    return " ".join(seg["text"] for seg in segments)


def transcript_to_timestamped(segments: list[dict]) -> str:
    """Convert transcript segments to timestamped text."""
    lines = []
    for seg in segments:
        start = int(seg["start"])
        mins, secs = divmod(start, 60)
        hours, mins = divmod(mins, 60)
        if hours:
            ts = f"[{hours}:{mins:02d}:{secs:02d}]"
        else:
            ts = f"[{mins}:{secs:02d}]"
        lines.append(f"{ts} {seg['text']}")
    return "\n".join(lines)


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug for filenames."""
    slug = text.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_]+", "-", slug)
    slug = re.sub(r"-+", "-", slug)
    return slug.strip("-")[:100]


def write_obsidian_note(
    video_id: str,
    title: str,
    transcript_text: str,
    vault_path: Path | None = None,
    subfolder: str = "",
    tags: list[str] | None = None,
) -> Path:
    """Write a transcript note to the Obsidian vault."""
    vault = vault_path or Path(os.environ.get("OBSIDIAN_VAULT", Path.home() / "obsidian"))
    target_dir = vault / "Career" / "Videos"
    if subfolder:
        target_dir = target_dir / subfolder
    target_dir.mkdir(parents=True, exist_ok=True)

    today = date.today().isoformat()
    slug = slugify(title) if title else video_id
    filepath = target_dir / f"{today}-{slug}.md"

    all_tags = ["youtube", "transcript"] + (tags or [])
    tag_lines = "\n".join(f"  - {t}" for t in all_tags)

    url = f"https://www.youtube.com/watch?v={video_id}"

    content = f"""---
category: "[[Clippings]]"
title: "{title or video_id}"
source: {url}
clipped: {today}
type: youtube-transcript
tags:
{tag_lines}
aliases: []
---

# {title or video_id}

**Source:** {url}
**Transcribed:** {today}

## Transcript

{transcript_text}
"""
    filepath.write_text(content)
    return filepath


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch YouTube transcripts")
    parser.add_argument("url", help="YouTube URL or video ID")
    parser.add_argument("--json", action="store_true", help="Output structured JSON")
    parser.add_argument("--timestamps", action="store_true", help="Include timestamps")
    parser.add_argument("--obsidian", action="store_true", help="Write Obsidian note")
    parser.add_argument("--title", default="", help="Video title for note")
    parser.add_argument("--folder", default="", help="Subfolder within Videos/")
    parser.add_argument("--tags", default="", help="Comma-separated tags")

    args = parser.parse_args()

    video_id = extract_video_id(args.url)
    if not video_id:
        print(f"Error: Could not extract video ID from: {args.url}", file=sys.stderr)
        sys.exit(1)

    try:
        segments = fetch_transcript(video_id)
    except Exception as e:
        print(f"Error fetching transcript: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        output = {
            "video_id": video_id,
            "url": f"https://www.youtube.com/watch?v={video_id}",
            "segment_count": len(segments),
            "text": transcript_to_text(segments),
            "segments": segments,
        }
        print(json.dumps(output, indent=2))
    elif args.obsidian:
        text = transcript_to_timestamped(segments) if args.timestamps else transcript_to_text(segments)
        tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []
        path = write_obsidian_note(
            video_id=video_id,
            title=args.title,
            transcript_text=text,
            subfolder=args.folder,
            tags=tags,
        )
        print(f"Note written to: {path}")
    elif args.timestamps:
        print(transcript_to_timestamped(segments))
    else:
        print(transcript_to_text(segments))


if __name__ == "__main__":
    main()
