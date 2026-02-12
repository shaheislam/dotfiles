#!/usr/bin/env python3
"""Tests for obsidian.py - Obsidian vault note generation."""

import sys
import tempfile
from datetime import date
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))

from obsidian import (
    _currency_symbol,
    _format_frontmatter,
    append_briefing_to_daily,
    find_relationship_file,
    get_vault_path,
    slugify,
    update_relationship_file,
    write_newsletter_note,
    write_receipt_note,
    write_relationship_note,
)


class TestSlugify:
    """Tests for text-to-slug conversion."""

    def test_simple_text(self):
        assert slugify("Hello World") == "hello-world"

    def test_special_characters(self):
        assert slugify("Tech & AI Newsletter!") == "tech-ai-newsletter"

    def test_multiple_spaces(self):
        assert slugify("too   many   spaces") == "too-many-spaces"

    def test_leading_trailing(self):
        assert slugify("  hello  ") == "hello"

    def test_already_slug(self):
        assert slugify("already-a-slug") == "already-a-slug"

    def test_uppercase(self):
        assert slugify("UPPERCASE") == "uppercase"

    def test_empty_string(self):
        assert slugify("") == ""


class TestGetVaultPath:
    """Tests for vault path resolution."""

    def test_default_path(self):
        path = get_vault_path()
        assert path == Path.home() / "obsidian"

    def test_explicit_override(self):
        path = get_vault_path("/tmp/my-vault")
        assert path == Path("/tmp/my-vault")

    def test_tilde_expansion(self):
        path = get_vault_path("~/my-vault")
        assert path == Path.home() / "my-vault"

    def test_env_var(self, monkeypatch):
        monkeypatch.setenv("OBSIDIAN_VAULT", "/custom/vault")
        path = get_vault_path()
        assert path == Path("/custom/vault")

    def test_override_beats_env(self, monkeypatch):
        monkeypatch.setenv("OBSIDIAN_VAULT", "/env/vault")
        path = get_vault_path("/override/vault")
        assert path == Path("/override/vault")


class TestFormatFrontmatter:
    """Tests for YAML frontmatter generation."""

    def test_simple_string(self):
        result = _format_frontmatter({"title": "Hello"})
        assert "title: Hello" in result
        assert result.startswith("---")
        assert result.endswith("---")

    def test_number(self):
        result = _format_frontmatter({"amount": 29.99})
        assert "amount: 29.99" in result

    def test_boolean(self):
        result = _format_frontmatter({"active": True})
        assert "active: true" in result

    def test_list(self):
        result = _format_frontmatter({"tags": ["a", "b", "c"]})
        assert "tags: [a, b, c]" in result

    def test_empty_list(self):
        result = _format_frontmatter({"tags": []})
        assert "tags: []" in result

    def test_none_skipped(self):
        result = _format_frontmatter({"key": None, "visible": "yes"})
        assert "key" not in result
        assert "visible: yes" in result

    def test_date_value(self):
        result = _format_frontmatter({"created": date(2026, 2, 8)})
        assert "created: 2026-02-08" in result

    def test_special_chars_quoted(self):
        result = _format_frontmatter({"sender": "News: Daily"})
        assert 'sender: "News: Daily"' in result


class TestCurrencySymbol:
    """Tests for currency symbol lookup."""

    def test_gbp(self):
        assert _currency_symbol("GBP") == "\u00a3"

    def test_usd(self):
        assert _currency_symbol("USD") == "$"

    def test_eur(self):
        assert _currency_symbol("EUR") == "\u20ac"

    def test_unknown_returns_code(self):
        assert _currency_symbol("JPY") == "JPY"

    def test_case_insensitive(self):
        assert _currency_symbol("gbp") == "\u00a3"


class TestWriteNewsletterNote:
    """Tests for newsletter note generation."""

    def test_creates_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "source_name": "Tech Weekly",
                "email_from": "tech@example.com",
                "key_takeaways": ["AI is growing", "Rust is popular"],
                "links": [{"title": "Article", "url": "https://example.com"}],
                "topics": ["ai", "rust"],
                "summary": "A weekly roundup of tech news.",
            }
            path = write_newsletter_note(vault, data, date(2026, 2, 8))

            assert path.exists()
            assert path.name == "2026-02-08-tech-weekly.md"
            assert path.parent.name == "newsletters"
            assert path.parent.parent.name == "Knowledge"

            content = path.read_text()
            assert "source: newsletter" in content
            assert "Tech Weekly" in content
            assert "AI is growing" in content
            assert "[Article](https://example.com)" in content
            assert "tags: [newsletter, ai, rust]" in content

    def test_creates_directory_structure(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {"source_name": "Test"}
            path = write_newsletter_note(vault, data, date(2026, 1, 1))
            assert (vault / "Knowledge" / "newsletters").is_dir()


class TestWriteReceiptNote:
    """Tests for receipt note generation."""

    def test_creates_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "merchant": "Amazon",
                "amount": 29.99,
                "currency": "GBP",
                "items": [{"name": "USB-C Cable", "quantity": 2, "price": "\u00a39.99"}],
                "order_id": "123-456",
                "payment_method": "Visa ending 4242",
            }
            path = write_receipt_note(vault, data, date(2026, 2, 8))

            assert path.exists()
            assert path.name == "2026-02-08-amazon.md"
            assert path.parent.name == "receipts"
            assert path.parent.parent.name == "Finance"

            content = path.read_text()
            assert "merchant: Amazon" in content
            assert "amount: 29.99" in content
            assert "USB-C Cable" in content
            assert "123-456" in content

    def test_receipt_with_minimal_data(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {"merchant": "Shop"}
            path = write_receipt_note(vault, data, date(2026, 1, 1))
            assert path.exists()
            content = path.read_text()
            assert "merchant: Shop" in content


class TestRelationshipNotes:
    """Tests for contact/relationship note management."""

    def test_write_new_relationship(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "sender_name": "John Smith",
                "email": "john@acme.com",
                "company": "Acme Corp",
                "role": "Software Engineer",
                "interaction_summary": "Discussed Q1 roadmap",
            }
            path = write_relationship_note(vault, data, date(2026, 2, 8))

            assert path.exists()
            assert path.name == "john-smith.md"
            assert path.parent.name == "Relationships"

            content = path.read_text()
            assert "# John Smith" in content
            assert "email: john@acme.com" in content
            assert "Acme Corp" in content
            assert "Discussed Q1 roadmap" in content

    def test_find_by_name_slug(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {"sender_name": "Jane Doe", "email": "jane@test.com"}
            write_relationship_note(vault, data, date(2026, 1, 1))

            found = find_relationship_file(vault, "Jane Doe", "jane@test.com")
            assert found is not None
            assert found.name == "jane-doe.md"

    def test_find_by_email_in_frontmatter(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {"sender_name": "Jane Doe", "email": "jane@unique.com"}
            write_relationship_note(vault, data, date(2026, 1, 1))

            # Search with different name but same email
            found = find_relationship_file(vault, "Different Name", "jane@unique.com")
            assert found is not None
            assert found.name == "jane-doe.md"

    def test_find_returns_none_when_not_found(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            found = find_relationship_file(vault, "Nobody", "nobody@test.com")
            assert found is None

    def test_update_existing_relationship(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "sender_name": "John Smith",
                "email": "john@acme.com",
                "interaction_summary": "Initial contact",
            }
            path = write_relationship_note(vault, data, date(2026, 1, 1))

            update_relationship_file(path, "Follow-up on project", date(2026, 2, 8))

            content = path.read_text()
            assert "last_contact: 2026-02-08" in content
            assert "Follow-up on project" in content
            assert "Initial contact" in content  # Original still there

    def test_relationship_without_company(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {"sender_name": "Solo Person", "email": "solo@test.com"}
            path = write_relationship_note(vault, data, date(2026, 1, 1))
            content = path.read_text()
            assert "type: contact" in content


class TestDailyBriefing:
    """Tests for daily briefing append."""

    def test_creates_new_daily_note(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "newsletters": [
                    {"source_name": "Tech Weekly", "obsidian_path": "Knowledge/newsletters/2026-02-08-tech-weekly.md"}
                ],
                "contacts": [
                    {"sender_name": "John Smith", "company": "Acme", "interaction_summary": "Q1 roadmap"}
                ],
                "receipts": [
                    {"merchant": "Amazon", "amount": 29.99, "currency": "GBP", "obsidian_path": "Finance/receipts/2026-02-08-amazon.md"}
                ],
                "action_items": ["Reply to John"],
            }
            path = append_briefing_to_daily(vault, date(2026, 2, 8), data)

            assert path.exists()
            assert path.name == "2026-02-08.md"
            assert (vault / "Daily" / "2026").is_dir()

            content = path.read_text()
            assert "## Email Briefing" in content
            assert "Tech Weekly" in content
            assert "John Smith" in content
            assert "Amazon" in content
            assert "Reply to John" in content

    def test_appends_to_existing_daily_note(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            daily_dir = vault / "Daily" / "2026"
            daily_dir.mkdir(parents=True)
            daily_file = daily_dir / "2026-02-08.md"
            daily_file.write_text("# 2026-02-08\n\n## Tasks\n- Do stuff\n")

            data = {
                "newsletters": [{"source_name": "News", "obsidian_path": ""}],
                "contacts": [],
                "receipts": [],
                "action_items": [],
            }
            append_briefing_to_daily(vault, date(2026, 2, 8), data)

            content = daily_file.read_text()
            assert "## Tasks" in content  # Original preserved
            assert "## Email Briefing" in content  # Briefing added

    def test_no_duplicate_briefing(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            daily_dir = vault / "Daily" / "2026"
            daily_dir.mkdir(parents=True)
            daily_file = daily_dir / "2026-02-08.md"
            daily_file.write_text("# 2026-02-08\n\n## Email Briefing\nAlready here\n")

            data = {
                "newsletters": [{"source_name": "News", "obsidian_path": ""}],
                "contacts": [],
                "receipts": [],
                "action_items": [],
            }
            append_briefing_to_daily(vault, date(2026, 2, 8), data)

            content = daily_file.read_text()
            assert content.count("## Email Briefing") == 1

    def test_wikilinks_in_briefing(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = Path(tmpdir)
            data = {
                "newsletters": [
                    {"source_name": "Tech", "obsidian_path": "Knowledge/newsletters/2026-02-08-tech.md"}
                ],
                "contacts": [],
                "receipts": [
                    {"merchant": "Shop", "amount": 10, "currency": "USD", "obsidian_path": "Finance/receipts/2026-02-08-shop.md"}
                ],
                "action_items": [],
            }
            path = append_briefing_to_daily(vault, date(2026, 2, 8), data)
            content = path.read_text()
            assert "[[Knowledge/newsletters/2026-02-08-tech|Key takeaways]]" in content
            assert "[[Finance/receipts/2026-02-08-shop|Details]]" in content


class TestExtractMimeParts:
    """Tests for MIME part extraction (in gmailclean.py)."""

    def test_plain_text_extraction(self):
        import base64
        from gmailclean import extract_mime_parts

        text = "Hello, world!"
        encoded = base64.urlsafe_b64encode(text.encode()).decode()
        payload = {
            "mimeType": "text/plain",
            "body": {"data": encoded},
        }
        result = extract_mime_parts(payload)
        assert result["text/plain"] == "Hello, world!"

    def test_multipart_extraction(self):
        import base64
        from gmailclean import extract_mime_parts

        plain = base64.urlsafe_b64encode(b"Plain text").decode()
        html = base64.urlsafe_b64encode(b"<p>HTML</p>").decode()
        payload = {
            "mimeType": "multipart/alternative",
            "body": {},
            "parts": [
                {"mimeType": "text/plain", "body": {"data": plain}},
                {"mimeType": "text/html", "body": {"data": html}},
            ],
        }
        result = extract_mime_parts(payload)
        assert result["text/plain"] == "Plain text"
        assert result["text/html"] == "<p>HTML</p>"

    def test_nested_multipart(self):
        import base64
        from gmailclean import extract_mime_parts

        text = base64.urlsafe_b64encode(b"Deep text").decode()
        payload = {
            "mimeType": "multipart/mixed",
            "body": {},
            "parts": [
                {
                    "mimeType": "multipart/alternative",
                    "body": {},
                    "parts": [
                        {"mimeType": "text/plain", "body": {"data": text}},
                    ],
                }
            ],
        }
        result = extract_mime_parts(payload)
        assert result["text/plain"] == "Deep text"

    def test_empty_payload(self):
        from gmailclean import extract_mime_parts

        result = extract_mime_parts({"mimeType": "multipart/mixed", "body": {}})
        assert result == {}


class TestExtractLog:
    """Tests for extract log persistence."""

    def test_load_missing_file(self):
        import gmailclean

        original = gmailclean.EXTRACT_LOG_PATH
        try:
            gmailclean.EXTRACT_LOG_PATH = Path("/tmp/nonexistent_extract_log.json")
            result = gmailclean.load_extract_log()
            assert result["last_run"] is None
            assert result["processed_ids"] == {}
            assert result["stats"]["newsletters"] == 0
        finally:
            gmailclean.EXTRACT_LOG_PATH = original

    def test_save_and_load_roundtrip(self):
        import gmailclean

        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            tmppath = Path(f.name)

        original = gmailclean.EXTRACT_LOG_PATH
        try:
            gmailclean.EXTRACT_LOG_PATH = tmppath
            log = {
                "last_run": None,
                "processed_ids": {
                    "msg123": {"category": "newsletter", "processed_at": "2026-02-08T10:00:00Z"}
                },
                "stats": {"newsletters": 1, "receipts": 0, "contacts": 0},
            }
            gmailclean.save_extract_log(log)
            loaded = gmailclean.load_extract_log()
            assert "msg123" in loaded["processed_ids"]
            assert loaded["processed_ids"]["msg123"]["category"] == "newsletter"
            assert loaded["last_run"] is not None  # save_extract_log sets this
        finally:
            gmailclean.EXTRACT_LOG_PATH = original
            tmppath.unlink(missing_ok=True)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
