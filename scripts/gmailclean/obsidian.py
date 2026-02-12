"""Obsidian vault note generation for gmailclean.

Generates markdown notes with YAML frontmatter matching the user's vault conventions.
Handles newsletter, receipt, and relationship notes, plus daily briefing appending.
"""

from __future__ import annotations

import os
import re
from datetime import date, datetime
from pathlib import Path
from typing import Any

DEFAULT_VAULT_PATH = Path.home() / "obsidian"


def get_vault_path(override: str | None = None) -> Path:
    """Resolve the Obsidian vault path.

    Priority: explicit override > OBSIDIAN_VAULT env var > ~/obsidian
    """
    if override:
        return Path(override).expanduser()
    env_path = os.environ.get("OBSIDIAN_VAULT")
    if env_path:
        return Path(env_path).expanduser()
    return DEFAULT_VAULT_PATH


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug for filenames.

    Lowercases, replaces spaces/special chars with hyphens, strips edges.
    """
    slug = text.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_]+", "-", slug)
    slug = re.sub(r"-+", "-", slug)
    return slug.strip("-")


def _format_frontmatter(fields: dict[str, Any]) -> str:
    """Format a dict as YAML frontmatter block.

    Handles strings, numbers, booleans, lists, and None values.
    """
    lines = ["---"]
    for key, value in fields.items():
        if value is None:
            continue
        if isinstance(value, bool):
            lines.append(f"{key}: {'true' if value else 'false'}")
        elif isinstance(value, (int, float)):
            lines.append(f"{key}: {value}")
        elif isinstance(value, list):
            if not value:
                lines.append(f"{key}: []")
            else:
                items = ", ".join(str(v) for v in value)
                lines.append(f"{key}: [{items}]")
        elif isinstance(value, date) and not isinstance(value, datetime):
            lines.append(f"{key}: {value.isoformat()}")
        else:
            # String — quote if it contains special chars
            s = str(value)
            if any(c in s for c in ":#[]{}|>") or s.startswith(("'", '"')):
                lines.append(f'{key}: "{s}"')
            else:
                lines.append(f"{key}: {s}")
    lines.append("---")
    return "\n".join(lines)


# --- Currency symbols ---

CURRENCY_SYMBOLS = {
    "GBP": "\u00a3",
    "USD": "$",
    "EUR": "\u20ac",
    "CAD": "C$",
    "AUD": "A$",
}


def _currency_symbol(code: str) -> str:
    return CURRENCY_SYMBOLS.get(code.upper(), code)


# --- Newsletter notes ---


def write_newsletter_note(
    vault: Path,
    data: dict[str, Any],
    note_date: date,
) -> Path:
    """Write a newsletter note to Knowledge/newsletters/.

    Returns the path to the created file.
    """
    source = data.get("source_name", "Unknown")
    slug = slugify(source)
    filename = f"{note_date.isoformat()}-{slug}.md"

    target_dir = vault / "Knowledge" / "newsletters"
    target_dir.mkdir(parents=True, exist_ok=True)
    filepath = target_dir / filename

    topics = data.get("topics", [])
    tags = ["newsletter"] + topics

    frontmatter = _format_frontmatter({
        "created": note_date,
        "source": "newsletter",
        "sender": source,
        "email_from": data.get("email_from", ""),
        "tags": tags,
    })

    lines = [frontmatter, f"# {source} - {note_date.strftime('%b %d, %Y')}", ""]

    # Key takeaways
    takeaways = data.get("key_takeaways", [])
    if takeaways:
        lines.append("## Key Takeaways")
        for t in takeaways:
            lines.append(f"- {t}")
        lines.append("")

    # Links
    links = data.get("links", [])
    if links:
        lines.append("## Links")
        for link in links:
            title = link.get("title", "Link")
            url = link.get("url", "")
            if url:
                lines.append(f"- [{title}]({url})")
            else:
                lines.append(f"- {title}")
        lines.append("")

    # Summary
    summary = data.get("summary", "")
    if summary:
        lines.append("## Summary")
        lines.append(summary)
        lines.append("")

    filepath.write_text("\n".join(lines))
    return filepath


# --- Receipt notes ---


def write_receipt_note(
    vault: Path,
    data: dict[str, Any],
    note_date: date,
) -> Path:
    """Write a receipt note to Finance/receipts/.

    Returns the path to the created file.
    """
    merchant = data.get("merchant", "Unknown")
    slug = slugify(merchant)
    filename = f"{note_date.isoformat()}-{slug}.md"

    target_dir = vault / "Finance" / "receipts"
    target_dir.mkdir(parents=True, exist_ok=True)
    filepath = target_dir / filename

    amount = data.get("amount", 0)
    currency = data.get("currency", "GBP")
    symbol = _currency_symbol(currency)

    frontmatter = _format_frontmatter({
        "date": note_date,
        "type": "purchase",
        "merchant": merchant,
        "amount": amount,
        "currency": currency,
        "order_id": data.get("order_id"),
        "tags": ["receipt", "finance"],
    })

    lines = [frontmatter, f"# {merchant} - {note_date.isoformat()} - {symbol}{amount}", ""]

    # Items table
    items = data.get("items", [])
    if items:
        lines.append("## Items")
        lines.append("| Item | Qty | Price |")
        lines.append("|------|-----|-------|")
        for item in items:
            name = item.get("name", "")
            qty = item.get("quantity", 1)
            price = item.get("price", "")
            lines.append(f"| {name} | {qty} | {price} |")
        lines.append("")

    # Details
    lines.append("## Details")
    if data.get("order_id"):
        lines.append(f"- **Order ID:** {data['order_id']}")
    if data.get("payment_method"):
        lines.append(f"- **Payment:** {data['payment_method']}")
    lines.append("")

    filepath.write_text("\n".join(lines))
    return filepath


# --- Relationship / Contact notes ---


def find_relationship_file(
    vault: Path,
    name: str,
    email: str,
) -> Path | None:
    """Find an existing relationship file by name slug or email in frontmatter.

    Returns the file path if found, None otherwise.
    """
    rel_dir = vault / "Relationships"
    if not rel_dir.exists():
        return None

    # Try name-based slug match first
    slug = slugify(name)
    candidate = rel_dir / f"{slug}.md"
    if candidate.exists():
        return candidate

    # Search by email in frontmatter
    if email:
        for f in rel_dir.glob("*.md"):
            try:
                content = f.read_text()
                if f"email: {email}" in content:
                    return f
            except OSError:
                continue

    return None


def write_relationship_note(
    vault: Path,
    data: dict[str, Any],
    note_date: date,
) -> Path:
    """Create a new relationship note in Relationships/.

    Returns the path to the created file.
    """
    name = data.get("sender_name", "Unknown")
    slug = slugify(name)
    filename = f"{slug}.md"

    target_dir = vault / "Relationships"
    target_dir.mkdir(parents=True, exist_ok=True)
    filepath = target_dir / filename

    company = data.get("company")
    role = data.get("role")

    frontmatter = _format_frontmatter({
        "type": "colleague" if company else "contact",
        "company": company,
        "email": data.get("email", ""),
        "last_contact": note_date,
        "contact_frequency": "unknown",
        "notes": [],
    })

    about = ""
    if role and company:
        about = f"{role} at {company}"
    elif role:
        about = role
    elif company:
        about = f"Contact at {company}"

    lines = [frontmatter, f"# {name}", ""]
    if about:
        lines.append("## About")
        lines.append(about)
        lines.append("")

    # Initial interaction
    summary = data.get("interaction_summary", "")
    lines.append("## Interaction History")
    if summary:
        lines.append(f"- {note_date.isoformat()}: {summary}")
    else:
        lines.append(f"- {note_date.isoformat()}: Email contact")
    lines.append("")

    filepath.write_text("\n".join(lines))
    return filepath


def update_relationship_file(
    filepath: Path,
    interaction: str,
    note_date: date,
) -> None:
    """Append an interaction entry to an existing relationship file.

    Also updates the last_contact date in frontmatter.
    """
    content = filepath.read_text()

    # Update last_contact in frontmatter
    content = re.sub(
        r"last_contact: \S+",
        f"last_contact: {note_date.isoformat()}",
        content,
        count=1,
    )

    # Append to interaction history
    entry = f"- {note_date.isoformat()}: {interaction}"
    if "## Interaction History" in content:
        # Insert after the header line
        content = content.replace(
            "## Interaction History\n",
            f"## Interaction History\n{entry}\n",
        )
    else:
        content = content.rstrip("\n") + f"\n\n## Interaction History\n{entry}\n"

    filepath.write_text(content)


# --- Daily briefing ---


def append_briefing_to_daily(
    vault: Path,
    briefing_date: date,
    briefing_data: dict[str, Any],
) -> Path:
    """Append an email briefing section to the daily note.

    Creates the daily note if it doesn't exist.
    Returns the path to the daily note.
    """
    year = str(briefing_date.year)
    filename = f"{briefing_date.isoformat()}.md"

    daily_dir = vault / "Daily" / year
    daily_dir.mkdir(parents=True, exist_ok=True)
    filepath = daily_dir / filename

    # Build briefing section
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = ["", "## Email Briefing", f"*Generated: {now}*", ""]

    # Newsletters
    newsletters = briefing_data.get("newsletters", [])
    if newsletters:
        lines.append(f"### Newsletters ({len(newsletters)} new)")
        for nl in newsletters:
            source = nl.get("source_name", "Unknown")
            path = nl.get("obsidian_path", "")
            if path:
                # Convert filesystem path to wikilink
                rel = path.replace(".md", "")
                lines.append(f"- **{source}**: [[{rel}|Key takeaways]]")
            else:
                lines.append(f"- **{source}**")
        lines.append("")

    # People / contacts
    contacts = briefing_data.get("contacts", [])
    if contacts:
        lines.append(f"### People ({len(contacts)} conversations)")
        for c in contacts:
            name = c.get("sender_name", "Unknown")
            company = c.get("company", "")
            slug = slugify(name)
            summary = c.get("interaction_summary", "")
            company_str = f" ({company})" if company else ""
            subject_str = f" - re: {summary}" if summary else ""
            lines.append(
                f"- [[Relationships/{slug}|{name}]]{company_str}{subject_str}"
            )
        lines.append("")

    # Receipts
    receipts = briefing_data.get("receipts", [])
    if receipts:
        lines.append(f"### Receipts ({len(receipts)})")
        for r in receipts:
            merchant = r.get("merchant", "Unknown")
            amount = r.get("amount", 0)
            currency = r.get("currency", "GBP")
            symbol = _currency_symbol(currency)
            path = r.get("obsidian_path", "")
            if path:
                rel = path.replace(".md", "")
                lines.append(f"- {merchant}: {symbol}{amount} - [[{rel}|Details]]")
            else:
                lines.append(f"- {merchant}: {symbol}{amount}")
        lines.append("")

    # Action items
    action_items = briefing_data.get("action_items", [])
    if action_items:
        lines.append("### Action Items")
        for item in action_items:
            lines.append(f"- [ ] {item}")
        lines.append("")

    briefing_text = "\n".join(lines)

    # Append to existing daily note or create new one
    if filepath.exists():
        existing = filepath.read_text()
        # Don't duplicate briefing section
        if "## Email Briefing" in existing:
            return filepath
        filepath.write_text(existing.rstrip("\n") + "\n" + briefing_text)
    else:
        # Create minimal daily note with briefing
        header = f"# {briefing_date.isoformat()}\n"
        filepath.write_text(header + briefing_text)

    return filepath
