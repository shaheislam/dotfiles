"""Tests for yt-transcript.py — URL parsing and text formatting."""

from __future__ import annotations

import sys
from pathlib import Path

# Add parent to path so we can import the script
sys.path.insert(0, str(Path(__file__).parent))

from importlib.machinery import SourceFileLoader

# Load the module from the hyphenated filename
loader = SourceFileLoader("yt_transcript", str(Path(__file__).parent / "yt-transcript.py"))
mod = loader.load_module()

extract_video_id = mod.extract_video_id
transcript_to_text = mod.transcript_to_text
transcript_to_timestamped = mod.transcript_to_timestamped
slugify = mod.slugify


class TestExtractVideoId:
    def test_standard_url(self):
        assert extract_video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_short_url(self):
        assert extract_video_id("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_embed_url(self):
        assert extract_video_id("https://www.youtube.com/embed/dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_shorts_url(self):
        assert extract_video_id("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_bare_video_id(self):
        assert extract_video_id("dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_mobile_url(self):
        assert extract_video_id("https://m.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ"

    def test_with_extra_params(self):
        assert extract_video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s") == "dQw4w9WgXcQ"

    def test_invalid_url(self):
        assert extract_video_id("https://example.com") is None

    def test_empty_string(self):
        assert extract_video_id("") is None


class TestTranscriptToText:
    def test_basic(self):
        segments = [
            {"text": "Hello", "start": 0, "duration": 1},
            {"text": "world", "start": 1, "duration": 1},
        ]
        assert transcript_to_text(segments) == "Hello world"

    def test_empty(self):
        assert transcript_to_text([]) == ""


class TestTranscriptToTimestamped:
    def test_basic(self):
        segments = [
            {"text": "Hello", "start": 0, "duration": 1},
            {"text": "world", "start": 65, "duration": 1},
        ]
        result = transcript_to_timestamped(segments)
        assert "[0:00] Hello" in result
        assert "[1:05] world" in result

    def test_hours(self):
        segments = [{"text": "late", "start": 3661, "duration": 1}]
        result = transcript_to_timestamped(segments)
        assert "[1:01:01] late" in result


class TestSlugify:
    def test_basic(self):
        assert slugify("Hello World") == "hello-world"

    def test_special_chars(self):
        assert slugify("What's Up? (2024)") == "whats-up-2024"

    def test_truncation(self):
        long = "a" * 200
        assert len(slugify(long)) <= 100
