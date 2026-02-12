#!/usr/bin/env python3
"""Tests for ollama.py - LLM client and prompt templates."""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent))

from ollama import (
    classify_email,
    extract_contact,
    extract_newsletter,
    extract_receipt,
    llm_extract,
    llm_extract_json,
    ollama_available,
    OLLAMA_BASE_URL,
)


class TestOllamaAvailable:
    """Tests for Ollama health check."""

    @patch("ollama.requests.get")
    def test_available_when_running(self, mock_get):
        mock_get.return_value = MagicMock(status_code=200)
        assert ollama_available() is True
        mock_get.assert_called_once_with(f"{OLLAMA_BASE_URL}/api/tags", timeout=3)

    @patch("ollama.requests.get")
    def test_unavailable_on_connection_error(self, mock_get):
        import requests
        mock_get.side_effect = requests.ConnectionError()
        assert ollama_available() is False

    @patch("ollama.requests.get")
    def test_unavailable_on_timeout(self, mock_get):
        import requests
        mock_get.side_effect = requests.Timeout()
        assert ollama_available() is False

    @patch("ollama.requests.get")
    def test_unavailable_on_500(self, mock_get):
        mock_get.return_value = MagicMock(status_code=500)
        assert ollama_available() is False


class TestLlmExtract:
    """Tests for raw LLM extraction."""

    @patch("ollama.requests.post")
    def test_successful_extraction(self, mock_post):
        mock_post.return_value = MagicMock(
            status_code=200,
            json=lambda: {
                "choices": [{"message": {"content": "Hello world"}}]
            },
        )
        result = llm_extract("system prompt", "user content")
        assert result == "Hello world"

    @patch("ollama.requests.post")
    def test_uses_correct_endpoint(self, mock_post):
        mock_post.return_value = MagicMock(
            status_code=200,
            json=lambda: {"choices": [{"message": {"content": "ok"}}]},
        )
        llm_extract("prompt", "content", model="test-model")
        call_args = mock_post.call_args
        assert call_args[0][0] == f"{OLLAMA_BASE_URL}/v1/chat/completions"
        assert call_args[1]["json"]["model"] == "test-model"
        assert call_args[1]["json"]["temperature"] == 0.1


class TestLlmExtractJson:
    """Tests for JSON extraction with fence stripping."""

    @patch("ollama.llm_extract")
    def test_clean_json(self, mock_extract):
        mock_extract.return_value = '{"key": "value"}'
        result = llm_extract_json("prompt", "content")
        assert result == {"key": "value"}

    @patch("ollama.llm_extract")
    def test_json_with_code_fence(self, mock_extract):
        mock_extract.return_value = '```json\n{"key": "value"}\n```'
        result = llm_extract_json("prompt", "content")
        assert result == {"key": "value"}

    @patch("ollama.llm_extract")
    def test_json_with_plain_fence(self, mock_extract):
        mock_extract.return_value = '```\n{"key": "value"}\n```'
        result = llm_extract_json("prompt", "content")
        assert result == {"key": "value"}

    @patch("ollama.llm_extract")
    def test_json_embedded_in_text(self, mock_extract):
        mock_extract.return_value = 'Here is the result:\n{"category": "newsletter", "confidence": 0.9}\nDone.'
        result = llm_extract_json("prompt", "content")
        assert result["category"] == "newsletter"

    @patch("ollama.llm_extract")
    def test_invalid_json_returns_empty(self, mock_extract):
        mock_extract.return_value = "This is not JSON at all"
        result = llm_extract_json("prompt", "content")
        assert result == {}

    @patch("ollama.llm_extract")
    def test_empty_response(self, mock_extract):
        mock_extract.return_value = ""
        result = llm_extract_json("prompt", "content")
        assert result == {}


class TestClassifyEmail:
    """Tests for email classification."""

    @patch("ollama.llm_extract_json")
    def test_newsletter_classification(self, mock_json):
        mock_json.return_value = {"category": "newsletter", "confidence": 0.95}
        result = classify_email(
            "Hacker News <hn@example.com>",
            "Weekly Digest",
            "Top stories this week...",
        )
        assert result["category"] == "newsletter"
        assert result["confidence"] == 0.95

    @patch("ollama.llm_extract_json")
    def test_receipt_classification(self, mock_json):
        mock_json.return_value = {"category": "receipt", "confidence": 0.88}
        result = classify_email(
            "Amazon <noreply@amazon.co.uk>",
            "Your order has been dispatched",
            "Order #123-456...",
        )
        assert result["category"] == "receipt"

    @patch("ollama.llm_extract_json")
    def test_missing_category_defaults_to_skip(self, mock_json):
        mock_json.return_value = {"confidence": 0.5}
        result = classify_email("from", "subject", "body")
        assert result["category"] == "skip"

    @patch("ollama.llm_extract_json")
    def test_missing_confidence_defaults_to_zero(self, mock_json):
        mock_json.return_value = {"category": "personal"}
        result = classify_email("from", "subject", "body")
        assert result["confidence"] == 0.0

    @patch("ollama.llm_extract_json")
    def test_body_truncated_to_max_chars(self, mock_json):
        mock_json.return_value = {"category": "skip", "confidence": 0.5}
        long_body = "x" * 10000
        classify_email("from", "subject", long_body)
        # Check that the content passed to LLM is truncated
        call_content = mock_json.call_args[0][1]
        assert len(call_content) < 5000  # 4000 + headers


class TestExtractNewsletter:
    """Tests for newsletter data extraction."""

    @patch("ollama.llm_extract_json")
    def test_full_extraction(self, mock_json):
        mock_json.return_value = {
            "source_name": "Tech Weekly",
            "key_takeaways": ["AI is growing", "Rust is popular"],
            "links": [{"title": "Article", "url": "https://example.com"}],
            "topics": ["ai", "rust"],
            "summary": "A weekly roundup.",
        }
        result = extract_newsletter("newsletter body text")
        assert result["source_name"] == "Tech Weekly"
        assert len(result["key_takeaways"]) == 2
        assert result["topics"] == ["ai", "rust"]

    @patch("ollama.llm_extract_json")
    def test_defaults_on_partial_response(self, mock_json):
        mock_json.return_value = {"source_name": "Weekly"}
        result = extract_newsletter("body")
        assert result["source_name"] == "Weekly"
        assert result["key_takeaways"] == []
        assert result["links"] == []
        assert result["topics"] == []
        assert result["summary"] == ""

    @patch("ollama.llm_extract_json")
    def test_defaults_on_empty_response(self, mock_json):
        mock_json.return_value = {}
        result = extract_newsletter("body")
        assert result["source_name"] == "Unknown Newsletter"


class TestExtractReceipt:
    """Tests for receipt data extraction."""

    @patch("ollama.llm_extract_json")
    def test_full_extraction(self, mock_json):
        mock_json.return_value = {
            "merchant": "Amazon",
            "amount": 29.99,
            "currency": "GBP",
            "items": [{"name": "USB-C Cable", "quantity": 2, "price": "£9.99"}],
            "order_id": "123-456",
            "payment_method": "Visa ending 4242",
        }
        result = extract_receipt("receipt body")
        assert result["merchant"] == "Amazon"
        assert result["amount"] == 29.99
        assert result["currency"] == "GBP"
        assert len(result["items"]) == 1

    @patch("ollama.llm_extract_json")
    def test_defaults_on_empty_response(self, mock_json):
        mock_json.return_value = {}
        result = extract_receipt("body")
        assert result["merchant"] == "Unknown"
        assert result["amount"] == 0.0
        assert result["currency"] == "GBP"


class TestExtractContact:
    """Tests for contact data extraction."""

    @patch("ollama.llm_extract_json")
    def test_full_extraction(self, mock_json):
        mock_json.return_value = {
            "sender_name": "John Smith",
            "email": "john@acme.com",
            "company": "Acme Corp",
            "role": "Software Engineer",
            "topics_discussed": ["Q1 roadmap"],
            "action_items": ["Review architecture doc"],
            "interaction_summary": "Discussed Q1 roadmap",
        }
        result = extract_contact("email body", "John Smith <john@acme.com>")
        assert result["sender_name"] == "John Smith"
        assert result["company"] == "Acme Corp"
        assert len(result["topics_discussed"]) == 1

    @patch("ollama.llm_extract_json")
    def test_defaults_on_empty(self, mock_json):
        mock_json.return_value = {}
        result = extract_contact("body")
        assert result["sender_name"] == "Unknown"
        assert result["email"] == ""
        assert result["company"] is None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
