"""Ollama LLM client for email classification and extraction.

Uses Ollama's OpenAI-compatible API at localhost:11434/v1 via requests.
No additional SDK dependencies needed.
"""

from __future__ import annotations

import json
import re
from typing import Any

import requests

OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_MODEL = "llama3.1:8b"

# Maximum content lengths to stay within context window
MAX_CLASSIFY_CHARS = 4000
MAX_EXTRACT_CHARS = 6000


def ollama_available() -> bool:
    """Check if Ollama is running and responsive."""
    try:
        resp = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=3)
        return resp.status_code == 200
    except (requests.ConnectionError, requests.Timeout):
        return False


def llm_extract(prompt: str, content: str, model: str = DEFAULT_MODEL) -> str:
    """Send a prompt + content to Ollama and return the raw response text.

    Uses the OpenAI-compatible chat completions endpoint.
    """
    resp = requests.post(
        f"{OLLAMA_BASE_URL}/v1/chat/completions",
        json={
            "model": model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": content},
            ],
            "temperature": 0.1,
            "stream": False,
        },
        timeout=120,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"]


def llm_extract_json(prompt: str, content: str, model: str = DEFAULT_MODEL) -> dict[str, Any]:
    """Extract structured JSON from LLM response.

    Strips markdown code fences and parses JSON. Returns empty dict on failure.
    """
    raw = llm_extract(prompt, content, model)

    # Strip markdown code fences (```json ... ``` or ``` ... ```)
    cleaned = re.sub(r"^```(?:json)?\s*\n?", "", raw.strip())
    cleaned = re.sub(r"\n?```\s*$", "", cleaned)

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # Try to find JSON object in the response
        match = re.search(r"\{[\s\S]*\}", raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                return {}
        return {}


# --- Classification prompt ---

CLASSIFY_PROMPT = """You are an email classifier. Given the From header, Subject, and a preview of the email body, classify the email into exactly one category.

Categories:
- newsletter: Newsletters, digests, blog updates, content roundups
- receipt: Purchase confirmations, invoices, payment receipts, order confirmations
- personal: Direct messages from real people (colleagues, friends, business contacts)
- skip: Automated notifications, marketing, spam, or anything not worth extracting

Respond with ONLY a JSON object:
{"category": "newsletter|receipt|personal|skip", "confidence": 0.0-1.0}"""


def classify_email(
    from_header: str,
    subject: str,
    body_preview: str,
    model: str = DEFAULT_MODEL,
) -> dict[str, Any]:
    """Classify an email into newsletter/receipt/personal/skip.

    Returns {"category": str, "confidence": float}.
    """
    content = (
        f"From: {from_header}\n"
        f"Subject: {subject}\n"
        f"Body preview:\n{body_preview[:MAX_CLASSIFY_CHARS]}"
    )
    result = llm_extract_json(CLASSIFY_PROMPT, content, model)
    if "category" not in result:
        result["category"] = "skip"
    if "confidence" not in result:
        result["confidence"] = 0.0
    return result


# --- Newsletter extraction prompt ---

NEWSLETTER_PROMPT = """You are extracting structured data from a newsletter email. Extract:

1. source_name: The name of the newsletter/publication
2. key_takeaways: A list of 3-5 key insights or takeaways (strings)
3. links: A list of objects with "title" and "url" for notable links mentioned
4. topics: A list of topic tags (lowercase, e.g. "ai", "python", "security")
5. summary: A 2-3 sentence summary of the newsletter content

Respond with ONLY a JSON object matching this schema:
{
  "source_name": "string",
  "key_takeaways": ["string"],
  "links": [{"title": "string", "url": "string"}],
  "topics": ["string"],
  "summary": "string"
}"""


def extract_newsletter(body: str, model: str = DEFAULT_MODEL) -> dict[str, Any]:
    """Extract structured data from a newsletter email body."""
    result = llm_extract_json(NEWSLETTER_PROMPT, body[:MAX_EXTRACT_CHARS], model)
    # Ensure required fields
    result.setdefault("source_name", "Unknown Newsletter")
    result.setdefault("key_takeaways", [])
    result.setdefault("links", [])
    result.setdefault("topics", [])
    result.setdefault("summary", "")
    return result


# --- Receipt extraction prompt ---

RECEIPT_PROMPT = """You are extracting structured data from a purchase receipt or order confirmation email. Extract:

1. merchant: The company/store name
2. amount: The total amount as a number (e.g. 29.99)
3. currency: The currency code (e.g. "GBP", "USD", "EUR")
4. items: A list of objects with "name", "quantity", and "price" (price as string with currency symbol)
5. order_id: The order/reference number (or null if not found)
6. payment_method: Payment method description (or null if not found)
7. date: The purchase date in YYYY-MM-DD format if mentioned (or null)

Respond with ONLY a JSON object matching this schema:
{
  "merchant": "string",
  "amount": 0.0,
  "currency": "GBP",
  "items": [{"name": "string", "quantity": 1, "price": "string"}],
  "order_id": "string or null",
  "payment_method": "string or null",
  "date": "string or null"
}"""


def extract_receipt(body: str, model: str = DEFAULT_MODEL) -> dict[str, Any]:
    """Extract structured data from a receipt/order confirmation email body."""
    result = llm_extract_json(RECEIPT_PROMPT, body[:MAX_EXTRACT_CHARS], model)
    result.setdefault("merchant", "Unknown")
    result.setdefault("amount", 0.0)
    result.setdefault("currency", "GBP")
    result.setdefault("items", [])
    result.setdefault("order_id", None)
    result.setdefault("payment_method", None)
    result.setdefault("date", None)
    return result


# --- Contact extraction prompt ---

CONTACT_PROMPT = """You are extracting contact information and interaction context from a personal email. Extract:

1. sender_name: The person's full name
2. email: Their email address
3. company: Their company/organization (or null)
4. role: Their job title/role (or null)
5. topics_discussed: A list of topics/subjects discussed in the email
6. action_items: A list of any action items or follow-ups mentioned
7. interaction_summary: A one-sentence summary of the interaction

Respond with ONLY a JSON object matching this schema:
{
  "sender_name": "string",
  "email": "string",
  "company": "string or null",
  "role": "string or null",
  "topics_discussed": ["string"],
  "action_items": ["string"],
  "interaction_summary": "string"
}"""


def extract_contact(
    body: str,
    from_header: str = "",
    model: str = DEFAULT_MODEL,
) -> dict[str, Any]:
    """Extract contact info and interaction context from a personal email."""
    content = f"From: {from_header}\n\n{body[:MAX_EXTRACT_CHARS]}"
    result = llm_extract_json(CONTACT_PROMPT, content, model)
    result.setdefault("sender_name", "Unknown")
    result.setdefault("email", "")
    result.setdefault("company", None)
    result.setdefault("role", None)
    result.setdefault("topics_discussed", [])
    result.setdefault("action_items", [])
    result.setdefault("interaction_summary", "")
    return result
