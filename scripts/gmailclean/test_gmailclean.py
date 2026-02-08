#!/usr/bin/env python3
"""Tests for gmailclean utility functions."""

import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add the script directory to path
sys.path.insert(0, str(Path(__file__).parent))

from gmailclean import (
    categorize_email,
    extract_sender_domain,
    extract_sender_name,
    extract_unsubscribe_info,
    load_unsub_log,
    one_click_unsubscribe,
    save_unsub_log,
    ORGANIZATION_LABELS,
)


class TestExtractUnsubscribeInfo:
    """Tests for List-Unsubscribe header parsing."""

    def test_http_url(self):
        headers = [
            {"name": "List-Unsubscribe", "value": "<https://example.com/unsub?id=123>"}
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub?id=123"
        assert result["mailto"] is None

    def test_mailto(self):
        headers = [
            {"name": "List-Unsubscribe", "value": "<mailto:unsub@example.com>"}
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] is None
        assert result["mailto"] == "mailto:unsub@example.com"

    def test_both_url_and_mailto(self):
        headers = [
            {
                "name": "List-Unsubscribe",
                "value": "<mailto:unsub@example.com>, <https://example.com/unsub>",
            }
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub"
        assert result["mailto"] == "mailto:unsub@example.com"

    def test_no_unsubscribe_header(self):
        headers = [
            {"name": "From", "value": "test@example.com"},
            {"name": "Subject", "value": "Hello"},
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] is None
        assert result["mailto"] is None

    def test_empty_headers(self):
        result = extract_unsubscribe_info([])
        assert result["url"] is None
        assert result["mailto"] is None

    def test_case_insensitive_header_name(self):
        headers = [
            {"name": "list-unsubscribe", "value": "<https://example.com/unsub>"}
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub"

    def test_http_url_without_https(self):
        headers = [
            {"name": "List-Unsubscribe", "value": "<http://example.com/unsub>"}
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "http://example.com/unsub"


class TestExtractSenderDomain:
    """Tests for sender domain extraction."""

    def test_simple_email(self):
        assert extract_sender_domain("user@example.com") == "example.com"

    def test_name_and_email(self):
        assert extract_sender_domain("John Doe <john@example.com>") == "example.com"

    def test_quoted_name(self):
        assert extract_sender_domain('"Company" <news@company.co.uk>') == "company.co.uk"

    def test_subdomain(self):
        assert extract_sender_domain("noreply@mail.example.com") == "mail.example.com"

    def test_no_at_sign(self):
        assert extract_sender_domain("invalid-email") == "unknown"

    def test_empty_string(self):
        assert extract_sender_domain("") == "unknown"


class TestExtractSenderName:
    """Tests for sender name extraction."""

    def test_name_with_brackets(self):
        assert extract_sender_name("John Doe <john@example.com>") == "John Doe"

    def test_quoted_name(self):
        assert extract_sender_name('"Newsletter" <news@example.com>') == "Newsletter"

    def test_email_only(self):
        assert extract_sender_name("john@example.com") == "john"

    def test_empty_string(self):
        result = extract_sender_name("")
        assert result == ""


class TestCategorizeEmail:
    """Tests for email categorization."""

    def test_newsletter(self):
        assert categorize_email("Weekly Digest", "news@example.com") == "Newsletters"

    def test_notification(self):
        assert categorize_email("Alert: New login", "security@bank.com") == "Notifications"

    def test_social(self):
        assert categorize_email("New follower", "noreply@linkedin.com") == "Social"

    def test_promotion(self):
        assert categorize_email("50% Off Sale!", "promo@store.com") == "Promotions"

    def test_finance(self):
        assert categorize_email("Payment received", "noreply@bank.com") == "Finance"

    def test_shopping(self):
        assert categorize_email("Your order has shipped", "orders@shop.com") == "Shopping"

    def test_uncategorized(self):
        assert categorize_email("Meeting tomorrow", "colleague@work.com") is None

    def test_case_insensitive(self):
        assert categorize_email("WEEKLY NEWSLETTER", "NEWS@EXAMPLE.COM") == "Newsletters"


class TestOrganizationLabels:
    """Tests for label configuration."""

    def test_all_categories_have_keywords(self):
        for label, keywords in ORGANIZATION_LABELS.items():
            assert len(keywords) > 0, f"Label '{label}' has no keywords"

    def test_no_duplicate_keywords_across_categories(self):
        # Keywords can overlap between categories (first match wins)
        # but each category should have unique keywords internally
        for label, keywords in ORGANIZATION_LABELS.items():
            assert len(keywords) == len(set(keywords)), (
                f"Label '{label}' has duplicate keywords"
            )

    def test_expected_categories_exist(self):
        expected = {"Newsletters", "Notifications", "Social", "Promotions", "Finance", "Shopping"}
        assert set(ORGANIZATION_LABELS.keys()) == expected


class TestScanCacheFormat:
    """Tests for scan cache serialization."""

    def test_subscription_serializable(self):
        """Test that subscription dict is JSON-serializable."""
        sub = {
            "message_id": "abc123",
            "from": "Test <test@example.com>",
            "sender_name": "Test",
            "domain": "example.com",
            "subject": "Test Subject",
            "date": "Mon, 1 Jan 2024 00:00:00 +0000",
            "unsubscribe_url": "https://example.com/unsub",
            "unsubscribe_mailto": None,
            "category": "Newsletters",
            "labels": ["INBOX"],
        }
        # Should not raise
        result = json.dumps(sub)
        parsed = json.loads(result)
        assert parsed["domain"] == "example.com"
        assert parsed["unsubscribe_url"] == "https://example.com/unsub"

    def test_cache_roundtrip(self):
        """Test writing and reading scan cache."""
        subscriptions = [
            {
                "message_id": "msg1",
                "from": "a@example.com",
                "sender_name": "A",
                "domain": "example.com",
                "subject": "Newsletter",
                "date": "",
                "unsubscribe_url": "https://example.com/unsub",
                "unsubscribe_mailto": None,
                "category": "Newsletters",
                "labels": [],
            },
            {
                "message_id": "msg2",
                "from": "b@shop.com",
                "sender_name": "B",
                "domain": "shop.com",
                "subject": "Order shipped",
                "date": "",
                "unsubscribe_url": None,
                "unsubscribe_mailto": "mailto:unsub@shop.com",
                "category": "Shopping",
                "labels": [],
            },
        ]

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(subscriptions, f)
            tmppath = f.name

        loaded = json.loads(Path(tmppath).read_text())
        assert len(loaded) == 2
        assert loaded[0]["domain"] == "example.com"
        assert loaded[1]["unsubscribe_mailto"] == "mailto:unsub@shop.com"

        Path(tmppath).unlink()


class TestOneClickUnsubscribe:
    """Tests for RFC 8058 one-click unsubscribe detection."""

    def test_one_click_detected(self):
        headers = [
            {"name": "List-Unsubscribe", "value": "<https://example.com/unsub>"},
            {"name": "List-Unsubscribe-Post", "value": "List-Unsubscribe=One-Click"},
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub"
        assert result["one_click"] is True

    def test_no_one_click_without_post_header(self):
        headers = [
            {"name": "List-Unsubscribe", "value": "<https://example.com/unsub>"}
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub"
        assert result["one_click"] is False

    def test_one_click_with_mailto_and_url(self):
        headers = [
            {
                "name": "List-Unsubscribe",
                "value": "<mailto:unsub@example.com>, <https://example.com/unsub>",
            },
            {"name": "List-Unsubscribe-Post", "value": "List-Unsubscribe=One-Click"},
        ]
        result = extract_unsubscribe_info(headers)
        assert result["url"] == "https://example.com/unsub"
        assert result["mailto"] == "mailto:unsub@example.com"
        assert result["one_click"] is True


class TestOneClickUnsubscribeHTTP:
    """Tests for the HTTP one-click unsubscribe function."""

    @patch("gmailclean.http_requests.post")
    def test_successful_unsubscribe(self, mock_post):
        mock_post.return_value = MagicMock(status_code=200)
        assert one_click_unsubscribe("https://example.com/unsub") is True
        mock_post.assert_called_once_with(
            "https://example.com/unsub",
            data="List-Unsubscribe=One-Click",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=15,
            allow_redirects=True,
        )

    @patch("gmailclean.http_requests.post")
    def test_accepted_response(self, mock_post):
        mock_post.return_value = MagicMock(status_code=202)
        assert one_click_unsubscribe("https://example.com/unsub") is True

    @patch("gmailclean.http_requests.post")
    def test_redirect_response(self, mock_post):
        mock_post.return_value = MagicMock(status_code=302)
        assert one_click_unsubscribe("https://example.com/unsub") is True

    @patch("gmailclean.http_requests.post")
    def test_server_error(self, mock_post):
        mock_post.return_value = MagicMock(status_code=500)
        assert one_click_unsubscribe("https://example.com/unsub") is False

    @patch("gmailclean.http_requests.post")
    def test_network_error(self, mock_post):
        mock_post.side_effect = Exception("Connection refused")
        assert one_click_unsubscribe("https://example.com/unsub") is False


class TestUnsubLog:
    """Tests for unsubscribe log persistence."""

    def test_save_and_load(self):
        import gmailclean

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            tmppath = Path(f.name)

        original_path = gmailclean.UNSUB_LOG_PATH
        try:
            gmailclean.UNSUB_LOG_PATH = tmppath

            log = {
                "unsubscribed": [
                    {"domain": "example.com", "sender": "Test", "method": "one_click"}
                ],
                "blocked": [],
            }
            save_unsub_log(log)
            loaded = load_unsub_log()
            assert len(loaded["unsubscribed"]) == 1
            assert loaded["unsubscribed"][0]["domain"] == "example.com"
        finally:
            gmailclean.UNSUB_LOG_PATH = original_path
            tmppath.unlink(missing_ok=True)

    def test_load_missing_file(self):
        import gmailclean

        original_path = gmailclean.UNSUB_LOG_PATH
        try:
            gmailclean.UNSUB_LOG_PATH = Path("/tmp/nonexistent_gmailclean_test.json")
            result = load_unsub_log()
            assert result == {"unsubscribed": [], "blocked": []}
        finally:
            gmailclean.UNSUB_LOG_PATH = original_path


class TestSubscriptionData:
    """Tests for subscription data format with new fields."""

    def test_subscription_with_one_click(self):
        sub = {
            "message_id": "abc123",
            "from": "Test <test@example.com>",
            "sender_name": "Test",
            "domain": "example.com",
            "subject": "Test Subject",
            "date": "Mon, 1 Jan 2024 00:00:00 +0000",
            "unsubscribe_url": "https://example.com/unsub",
            "unsubscribe_mailto": None,
            "one_click": True,
            "category": "Newsletters",
            "email_count": 15,
            "labels": ["INBOX"],
        }
        result = json.dumps(sub)
        parsed = json.loads(result)
        assert parsed["one_click"] is True
        assert parsed["email_count"] == 15

    def test_subscription_without_one_click(self):
        sub = {
            "message_id": "abc123",
            "from": "Test <test@example.com>",
            "sender_name": "Test",
            "domain": "example.com",
            "subject": "Test Subject",
            "date": "",
            "unsubscribe_url": "https://example.com/unsub",
            "unsubscribe_mailto": None,
            "one_click": False,
            "category": None,
            "email_count": 1,
            "labels": [],
        }
        result = json.dumps(sub)
        parsed = json.loads(result)
        assert parsed["one_click"] is False
        assert parsed["email_count"] == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
