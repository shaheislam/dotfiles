#!/usr/bin/env python3
"""
gmailclean - Gmail inbox cleanup tool.

Scans Gmail for subscription emails, provides unsubscribe links,
and organizes inbox with labels and filters.

Usage:
    gmailclean scan          - Scan inbox for subscriptions
    gmailclean unsubscribe   - Unsubscribe from detected newsletters
    gmailclean organize      - Create labels and filters to organize inbox
    gmailclean report        - Generate inbox health report
    gmailclean cleanup       - Archive old emails from unsubscribed senders
    gmailclean archive       - Bulk archive all inbox emails older than N days
    gmailclean centralize    - Set up forwarding rules to consolidate accounts
    gmailclean nuke          - Full cleanup: scan + unsubscribe + organize
    gmailclean extract       - Extract email insights into Obsidian notes
    gmailclean briefing      - Generate daily email briefing in Obsidian
    gmailclean contacts      - Build contact graph from email history
"""

from __future__ import annotations

import argparse
import base64
import email
import json
import os
import re
import sys
import time
import webbrowser
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import html2text
import requests as http_requests

# Google API imports
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Rich for pretty output
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Confirm, Prompt
from rich.table import Table

console = Console()

# Gmail API scopes - we need modify to manage labels/filters and read messages
SCOPES = [
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.settings.basic",
]

# Config directory
CONFIG_DIR = Path.home() / ".config" / "gmailclean"
CREDENTIALS_PATH = CONFIG_DIR / "credentials.json"

# Per-account paths (updated by configure_account if --account is used)
TOKEN_PATH = CONFIG_DIR / "token.json"
SCAN_CACHE_PATH = CONFIG_DIR / "scan_cache.json"
UNSUB_LOG_PATH = CONFIG_DIR / "unsubscribed.json"
EXTRACT_LOG_PATH = CONFIG_DIR / "extract_log.json"


def configure_account(account: str | None) -> None:
    """Configure per-account paths.

    When account is None, paths stay at the root config dir (backwards compatible).
    When account is set, per-user state files go to accounts/<name>/.
    credentials.json is always shared at the root.

    Args:
        account: Account profile name, or None for default.
    """
    global TOKEN_PATH, SCAN_CACHE_PATH, UNSUB_LOG_PATH, EXTRACT_LOG_PATH

    if account is None:
        return

    if not re.match(r"^[a-zA-Z0-9_-]+$", account):
        console.print(f"[red]Invalid account name: {account}[/red]")
        console.print("[dim]Use only letters, numbers, hyphens, underscores.[/dim]")
        sys.exit(1)

    account_dir = CONFIG_DIR / "accounts" / account
    account_dir.mkdir(parents=True, exist_ok=True)

    TOKEN_PATH = account_dir / "token.json"
    SCAN_CACHE_PATH = account_dir / "scan_cache.json"
    UNSUB_LOG_PATH = account_dir / "unsubscribed.json"
    EXTRACT_LOG_PATH = account_dir / "extract_log.json"

    console.print(f"[dim]Using account: {account}[/dim]")

# Labels for organization
ORGANIZATION_LABELS = {
    "Newsletters": {"newsletters", "digest", "weekly", "monthly", "bulletin"},
    "Notifications": {"notification", "alert", "update", "status"},
    "Social": {"social", "facebook", "twitter", "linkedin", "instagram"},
    "Promotions": {"promo", "sale", "discount", "offer", "deal", "coupon"},
    "Finance": {"bank", "payment", "invoice", "receipt", "statement", "transaction"},
    "Shopping": {"order", "shipping", "delivery", "tracking", "purchased"},
}


def get_gmail_service() -> Any:
    """Authenticate and return Gmail API service."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    creds = None

    if TOKEN_PATH.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            console.print("[yellow]Refreshing expired credentials...[/yellow]")
            creds.refresh(Request())
        else:
            if not CREDENTIALS_PATH.exists():
                console.print(
                    Panel(
                        "[bold red]Gmail API credentials not found![/bold red]\n\n"
                        "To set up Gmail API access:\n\n"
                        "1. Go to [link=https://console.cloud.google.com/apis/credentials]Google Cloud Console[/link]\n"
                        "2. Create a project (or select existing)\n"
                        "3. Enable the Gmail API\n"
                        "4. Create OAuth 2.0 Client ID (Desktop application)\n"
                        "5. Download the credentials JSON\n"
                        f"6. Save it as: [cyan]{CREDENTIALS_PATH}[/cyan]\n\n"
                        "Then run gmailclean again.",
                        title="Setup Required",
                        border_style="red",
                    )
                )
                sys.exit(1)

            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_PATH), SCOPES
            )
            creds = flow.run_local_server(port=0)

        # Save credentials for next run
        TOKEN_PATH.write_text(creds.to_json())
        console.print("[green]Credentials saved.[/green]")

    return build("gmail", "v1", credentials=creds)


def extract_unsubscribe_info(headers: list[dict]) -> dict[str, str | None | bool]:
    """Extract unsubscribe URL and mailto from email headers."""
    info: dict[str, str | None | bool] = {
        "url": None,
        "mailto": None,
        "one_click": False,
    }

    for header in headers:
        name = header.get("name", "").lower()
        value = header.get("value", "")

        if name == "list-unsubscribe":
            # Extract HTTP URL
            url_match = re.search(r"<(https?://[^>]+)>", value)
            if url_match:
                info["url"] = url_match.group(1)

            # Extract mailto
            mailto_match = re.search(r"<(mailto:[^>]+)>", value)
            if mailto_match:
                info["mailto"] = mailto_match.group(1)

        # RFC 8058: List-Unsubscribe-Post header means one-click HTTP unsubscribe
        if name == "list-unsubscribe-post":
            info["one_click"] = True

    return info


def one_click_unsubscribe(url: str) -> bool:
    """Perform RFC 8058 one-click unsubscribe via HTTP POST.

    Returns True if the unsubscribe request was successful.
    """
    try:
        resp = http_requests.post(
            url,
            data="List-Unsubscribe=One-Click",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=15,
            allow_redirects=True,
        )
        return resp.status_code in (200, 202, 204, 301, 302)
    except Exception:
        return False


def load_unsub_log() -> dict[str, Any]:
    """Load the unsubscribe log (tracks which domains have been unsubscribed)."""
    if UNSUB_LOG_PATH.exists():
        return json.loads(UNSUB_LOG_PATH.read_text())
    return {"unsubscribed": [], "blocked": []}


def save_unsub_log(log: dict[str, Any]) -> None:
    """Save the unsubscribe log."""
    UNSUB_LOG_PATH.write_text(json.dumps(log, indent=2, default=str))


def extract_sender_domain(from_header: str) -> str:
    """Extract domain from From header."""
    match = re.search(r"@([\w.-]+)", from_header)
    return match.group(1) if match else "unknown"


def extract_sender_name(from_header: str) -> str:
    """Extract readable name from From header."""
    # Try "Name <email>" format
    match = re.match(r'"?([^"<]+)"?\s*<', from_header)
    if match:
        return match.group(1).strip()
    return from_header.split("@")[0] if "@" in from_header else from_header


def categorize_email(subject: str, from_header: str) -> str | None:
    """Categorize an email based on subject and sender."""
    text = f"{subject} {from_header}".lower()

    for label, keywords in ORGANIZATION_LABELS.items():
        if any(kw in text for kw in keywords):
            return label

    return None


def extract_mime_parts(payload: dict) -> dict[str, str]:
    """Recursively walk a Gmail MIME payload and extract text parts.

    Returns {"text/plain": content, "text/html": content} with the first
    found part of each type.
    """
    parts: dict[str, str] = {}

    def _walk(node: dict) -> None:
        mime_type = node.get("mimeType", "")

        # Leaf node with body data
        body = node.get("body", {})
        data = body.get("data", "")
        if data and mime_type in ("text/plain", "text/html") and mime_type not in parts:
            decoded = base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")
            parts[mime_type] = decoded

        # Recurse into child parts
        for child in node.get("parts", []):
            _walk(child)

    _walk(payload)
    return parts


def fetch_email_body(service: Any, msg_id: str) -> dict[str, str]:
    """Fetch full email body for a message ID.

    Returns {"text": plain_text_content, "from": sender, "subject": subject, "date": date}.
    Prefers text/plain; falls back to html2text conversion of text/html.
    """
    msg = (
        service.users()
        .messages()
        .get(userId="me", id=msg_id, format="full")
        .execute()
    )

    payload = msg.get("payload", {})
    headers = payload.get("headers", [])

    from_header = next(
        (h["value"] for h in headers if h["name"].lower() == "from"), ""
    )
    subject = next(
        (h["value"] for h in headers if h["name"].lower() == "subject"), ""
    )
    date_header = next(
        (h["value"] for h in headers if h["name"].lower() == "date"), ""
    )

    mime_parts = extract_mime_parts(payload)

    if "text/plain" in mime_parts:
        text = mime_parts["text/plain"]
    elif "text/html" in mime_parts:
        h = html2text.HTML2Text()
        h.ignore_links = False
        h.ignore_images = True
        h.body_width = 0
        text = h.handle(mime_parts["text/html"])
    else:
        text = ""

    return {
        "text": text,
        "from": from_header,
        "subject": subject,
        "date": date_header,
    }


def load_extract_log() -> dict[str, Any]:
    """Load the extract log tracking processed message IDs."""
    if EXTRACT_LOG_PATH.exists():
        return json.loads(EXTRACT_LOG_PATH.read_text())
    return {
        "last_run": None,
        "processed_ids": {},
        "stats": {"newsletters": 0, "receipts": 0, "contacts": 0},
    }


def save_extract_log(log: dict[str, Any]) -> None:
    """Save the extract log."""
    log["last_run"] = datetime.now(timezone.utc).isoformat()
    EXTRACT_LOG_PATH.write_text(json.dumps(log, indent=2, default=str))


def scan_inbox(service: Any, max_results: int = 500) -> list[dict]:
    """Scan inbox for subscription emails."""
    subscriptions: list[dict] = []
    seen_senders: set[str] = set()

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Scanning inbox for subscriptions...", total=None)

        try:
            # Search for emails with List-Unsubscribe header
            # Gmail doesn't directly filter by header, so we search broadly
            queries = [
                "unsubscribe",
                "label:inbox category:promotions",
                "label:inbox category:updates",
                "label:inbox category:social",
            ]

            all_message_ids: set[str] = set()

            for query in queries:
                progress.update(task, description=f"Searching: {query}...")
                page_token = None

                while len(all_message_ids) < max_results:
                    result = (
                        service.users()
                        .messages()
                        .list(
                            userId="me",
                            q=query,
                            maxResults=min(100, max_results - len(all_message_ids)),
                            pageToken=page_token,
                        )
                        .execute()
                    )

                    messages = result.get("messages", [])
                    for msg in messages:
                        all_message_ids.add(msg["id"])

                    page_token = result.get("nextPageToken")
                    if not page_token:
                        break

            progress.update(
                task,
                description=f"Found {len(all_message_ids)} potential subscription emails. Analyzing...",
            )

            # Analyze each message
            for i, msg_id in enumerate(all_message_ids):
                if i % 50 == 0:
                    progress.update(
                        task,
                        description=f"Analyzing message {i+1}/{len(all_message_ids)}...",
                    )

                try:
                    msg = (
                        service.users()
                        .messages()
                        .get(
                            userId="me",
                            id=msg_id,
                            format="metadata",
                            metadataHeaders=[
                                "From",
                                "Subject",
                                "Date",
                                "List-Unsubscribe",
                                "List-Unsubscribe-Post",
                            ],
                        )
                        .execute()
                    )

                    headers = msg.get("payload", {}).get("headers", [])
                    unsub_info = extract_unsubscribe_info(headers)

                    # Only include if it has unsubscribe info
                    if not unsub_info["url"] and not unsub_info["mailto"]:
                        continue

                    from_header = next(
                        (
                            h["value"]
                            for h in headers
                            if h["name"].lower() == "from"
                        ),
                        "Unknown",
                    )
                    subject = next(
                        (
                            h["value"]
                            for h in headers
                            if h["name"].lower() == "subject"
                        ),
                        "No Subject",
                    )
                    date = next(
                        (
                            h["value"]
                            for h in headers
                            if h["name"].lower() == "date"
                        ),
                        "",
                    )

                    domain = extract_sender_domain(from_header)
                    sender_name = extract_sender_name(from_header)

                    # Track email count per domain
                    if domain in seen_senders:
                        # Increment count for existing entry
                        for sub in subscriptions:
                            if sub["domain"] == domain:
                                sub["email_count"] = sub.get("email_count", 1) + 1
                                break
                        continue
                    seen_senders.add(domain)

                    category = categorize_email(subject, from_header)

                    subscriptions.append(
                        {
                            "message_id": msg_id,
                            "from": from_header,
                            "sender_name": sender_name,
                            "domain": domain,
                            "subject": subject,
                            "date": date,
                            "unsubscribe_url": unsub_info["url"],
                            "unsubscribe_mailto": unsub_info["mailto"],
                            "one_click": unsub_info.get("one_click", False),
                            "category": category,
                            "email_count": 1,
                            "labels": msg.get("labelIds", []),
                        }
                    )

                except HttpError:
                    continue

        except HttpError as e:
            console.print(f"[red]Gmail API error: {e}[/red]")
            sys.exit(1)

    # Sort by domain
    subscriptions.sort(key=lambda x: x["domain"])

    # Cache results
    SCAN_CACHE_PATH.write_text(json.dumps(subscriptions, indent=2, default=str))
    console.print(
        f"[dim]Scan results cached to {SCAN_CACHE_PATH}[/dim]"
    )

    return subscriptions


def display_subscriptions(subscriptions: list[dict]) -> None:
    """Display subscriptions in a rich table."""
    table = Table(title=f"Found {len(subscriptions)} Subscriptions", show_lines=True)
    table.add_column("#", style="dim", width=4)
    table.add_column("Sender", style="cyan", max_width=30)
    table.add_column("Domain", style="blue", max_width=25)
    table.add_column("Category", style="yellow", max_width=12)
    table.add_column("Emails", style="magenta", width=6, justify="right")
    table.add_column("Subject (latest)", style="white", max_width=35)
    table.add_column("Unsub", style="green", width=8)

    for i, sub in enumerate(subscriptions, 1):
        if sub.get("one_click"):
            unsub_type = "1-Click"
        elif sub.get("unsubscribe_url"):
            unsub_type = "URL"
        elif sub.get("unsubscribe_mailto"):
            unsub_type = "Email"
        else:
            unsub_type = "-"

        table.add_row(
            str(i),
            sub["sender_name"][:30],
            sub["domain"][:25],
            sub.get("category") or "-",
            str(sub.get("email_count", 1)),
            sub["subject"][:35],
            unsub_type,
        )

    console.print(table)

    # Summary stats
    categories = Counter(sub.get("category") or "Uncategorized" for sub in subscriptions)
    one_click_count = sum(1 for s in subscriptions if s.get("one_click"))
    total_emails = sum(s.get("email_count", 1) for s in subscriptions)

    console.print(f"\n[bold]Summary:[/bold]")
    console.print(f"  Total subscription emails found: {total_emails}")
    console.print(f"  Unique senders: {len(subscriptions)}")
    console.print(f"  One-click unsubscribe available: {one_click_count}")
    console.print(f"\n[bold]Category Breakdown:[/bold]")
    for cat, count in categories.most_common():
        console.print(f"  {cat}: {count}")


def cmd_scan(args: argparse.Namespace) -> None:
    """Scan command: find all subscriptions in inbox."""
    console.print(Panel("[bold]Scanning Gmail inbox for subscriptions...[/bold]", border_style="blue"))

    service = get_gmail_service()
    subscriptions = scan_inbox(service, max_results=args.max_results)

    if not subscriptions:
        console.print("[green]No subscription emails found. Your inbox is clean![/green]")
        return

    display_subscriptions(subscriptions)
    console.print(
        f"\n[dim]Results saved to {SCAN_CACHE_PATH}[/dim]"
        f"\n[dim]Run 'gmailclean unsubscribe' to start unsubscribing.[/dim]"
    )


def cmd_unsubscribe(args: argparse.Namespace) -> None:
    """Unsubscribe command: batch unsubscribe from newsletters."""
    # Load cached scan or run new scan
    if SCAN_CACHE_PATH.exists() and not getattr(args, "rescan", False):
        console.print("[dim]Loading cached scan results...[/dim]")
        subscriptions = json.loads(SCAN_CACHE_PATH.read_text())
    else:
        console.print("[yellow]No cached scan found. Running scan first...[/yellow]")
        service = get_gmail_service()
        subscriptions = scan_inbox(service, max_results=getattr(args, "max_results", 500))

    if not subscriptions:
        console.print("[green]No subscriptions to unsubscribe from.[/green]")
        return

    auto_mode = getattr(args, "auto", False) or getattr(args, "yes", False)

    display_subscriptions(subscriptions)

    if auto_mode:
        choice = "all"
        console.print("[bold yellow]Auto mode: unsubscribing from all subscriptions[/bold yellow]")
    else:
        console.print(
            Panel(
                "[bold]Unsubscribe Mode[/bold]\n\n"
                "Options:\n"
                "  [cyan]all[/cyan]     - Unsubscribe from ALL subscriptions\n"
                "  [cyan]pick[/cyan]    - Select which ones to unsubscribe from\n"
                "  [cyan]range[/cyan]   - Specify a range (e.g., 1-10,15,20-25)\n"
                "  [cyan]cancel[/cyan]  - Exit without unsubscribing\n\n"
                "[dim]Tip: One-click subscriptions are handled automatically via HTTP.[/dim]\n"
                "[dim]URL subscriptions open in your browser for manual confirmation.[/dim]",
                border_style="yellow",
            )
        )

        choice = Prompt.ask(
            "How would you like to unsubscribe?",
            choices=["all", "pick", "range", "cancel"],
            default="pick",
        )

    if choice == "cancel":
        return

    indices_to_unsub: list[int] = []

    if choice == "all":
        if not auto_mode and not Confirm.ask(
            f"[bold red]Unsubscribe from ALL {len(subscriptions)} subscriptions?[/bold red]"
        ):
            return
        indices_to_unsub = list(range(len(subscriptions)))

    elif choice == "range":
        range_str = Prompt.ask("Enter range (e.g., 1-10,15,20-25)")
        for part in range_str.split(","):
            part = part.strip()
            if "-" in part:
                start, end = part.split("-", 1)
                indices_to_unsub.extend(range(int(start) - 1, int(end)))
            else:
                indices_to_unsub.append(int(part) - 1)

    elif choice == "pick":
        console.print("[dim]Confirm each subscription to unsubscribe:[/dim]")
        for i, sub in enumerate(subscriptions, 1):
            method = "1-click" if sub.get("one_click") else "browser"
            if Confirm.ask(
                f"  [{i}] {sub['sender_name']} ({sub['domain']}) [{method}]?",
                default=False,
            ):
                indices_to_unsub.append(i - 1)

    # Process unsubscriptions
    one_click_success = 0
    browser_opened = 0
    mailto_list: list[str] = []
    failed: list[str] = []
    unsub_log = load_unsub_log()

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Processing unsubscriptions...", total=len(indices_to_unsub))

        for idx in indices_to_unsub:
            if idx < 0 or idx >= len(subscriptions):
                continue

            sub = subscriptions[idx]
            progress.update(task, description=f"Unsubscribing from {sub['domain']}...", advance=1)

            # Try one-click HTTP unsubscribe first (RFC 8058)
            if sub.get("one_click") and sub.get("unsubscribe_url"):
                if one_click_unsubscribe(sub["unsubscribe_url"]):
                    one_click_success += 1
                    unsub_log["unsubscribed"].append({
                        "domain": sub["domain"],
                        "sender": sub["sender_name"],
                        "method": "one_click",
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    })
                    # Small delay to avoid rate limiting
                    time.sleep(0.3)
                    continue
                # Fall through to browser if one-click fails

            if sub.get("unsubscribe_url"):
                try:
                    webbrowser.open(sub["unsubscribe_url"])
                    browser_opened += 1
                    unsub_log["unsubscribed"].append({
                        "domain": sub["domain"],
                        "sender": sub["sender_name"],
                        "method": "browser",
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    })
                    # Throttle browser opens to avoid overwhelming
                    time.sleep(0.5)
                except Exception:
                    failed.append(sub["domain"])
            elif sub.get("unsubscribe_mailto"):
                mailto_list.append(f"{sub['sender_name']}: {sub['unsubscribe_mailto']}")
            else:
                failed.append(sub["domain"])

    # Deduplicate unsubscribed log
    seen = set()
    deduped = []
    for entry in unsub_log["unsubscribed"]:
        if entry["domain"] not in seen:
            seen.add(entry["domain"])
            deduped.append(entry)
    unsub_log["unsubscribed"] = deduped
    save_unsub_log(unsub_log)

    # Report
    console.print(
        Panel(
            f"[bold green]Unsubscribe Summary[/bold green]\n\n"
            f"  One-click (auto): {one_click_success}\n"
            f"  Opened in browser: {browser_opened}\n"
            f"  Mailto (manual):   {len(mailto_list)}\n"
            f"  Failed:            {len(failed)}\n\n"
            f"[dim]Log saved to {UNSUB_LOG_PATH}[/dim]",
            border_style="green",
        )
    )

    if mailto_list:
        console.print("\n[yellow]These require email-based unsubscription:[/yellow]")
        for item in mailto_list:
            console.print(f"  {item}")

    if failed:
        console.print("\n[red]Failed to process:[/red]")
        for domain in failed:
            console.print(f"  {domain}")


def cmd_organize(args: argparse.Namespace) -> None:
    """Organize command: create labels and filters."""
    console.print(Panel("[bold]Organizing Gmail inbox...[/bold]", border_style="blue"))

    service = get_gmail_service()

    # Get existing labels
    results = service.users().labels().list(userId="me").execute()
    existing_labels = {l["name"]: l["id"] for l in results.get("labels", [])}

    console.print(f"[dim]Found {len(existing_labels)} existing labels[/dim]")

    # Create organization labels if they don't exist
    created_labels: dict[str, str] = {}

    for label_name in ORGANIZATION_LABELS:
        full_name = f"AutoClean/{label_name}"

        if full_name in existing_labels:
            created_labels[label_name] = existing_labels[full_name]
            console.print(f"  [dim]Label exists: {full_name}[/dim]")
        else:
            try:
                label_body = {
                    "name": full_name,
                    "labelListVisibility": "labelShow",
                    "messageListVisibility": "show",
                }
                result = (
                    service.users()
                    .labels()
                    .create(userId="me", body=label_body)
                    .execute()
                )
                created_labels[label_name] = result["id"]
                console.print(f"  [green]Created label: {full_name}[/green]")
            except HttpError as e:
                console.print(f"  [red]Failed to create {full_name}: {e}[/red]")

    # Create filters for each category
    console.print("\n[bold]Creating filters...[/bold]")

    for label_name, keywords in ORGANIZATION_LABELS.items():
        if label_name not in created_labels:
            continue

        # Build filter query from keywords
        query_parts = [f"subject:{kw}" for kw in keywords]
        query = " OR ".join(query_parts)

        filter_body = {
            "criteria": {"query": query},
            "action": {
                "addLabelIds": [created_labels[label_name]],
                "removeLabelIds": [],  # Don't remove INBOX - let user decide
            },
        }

        try:
            service.users().settings().filters().create(
                userId="me", body=filter_body
            ).execute()
            console.print(f"  [green]Filter created for: AutoClean/{label_name}[/green]")
        except HttpError as e:
            if "Filter already exists" in str(e) or "already exists" in str(e).lower():
                console.print(f"  [dim]Filter exists for: AutoClean/{label_name}[/dim]")
            else:
                console.print(f"  [red]Failed to create filter for {label_name}: {e}[/red]")

    # Apply labels to existing messages from scan cache
    if SCAN_CACHE_PATH.exists():
        subscriptions = json.loads(SCAN_CACHE_PATH.read_text())
        labeled_count = 0

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Labeling existing messages...", total=len(subscriptions))

            for sub in subscriptions:
                progress.advance(task)
                category = sub.get("category")
                if category and category in created_labels:
                    try:
                        service.users().messages().modify(
                            userId="me",
                            id=sub["message_id"],
                            body={"addLabelIds": [created_labels[category]]},
                        ).execute()
                        labeled_count += 1
                    except HttpError:
                        continue

        console.print(f"\n[green]Labeled {labeled_count} existing messages.[/green]")

    console.print(
        Panel(
            "[bold green]Organization Complete[/bold green]\n\n"
            "Labels created under AutoClean/:\n"
            + "\n".join(f"  - AutoClean/{name}" for name in created_labels)
            + "\n\nFilters will automatically categorize new incoming mail.",
            border_style="green",
        )
    )


def cmd_report(args: argparse.Namespace) -> None:
    """Report command: generate inbox health report."""
    console.print(Panel("[bold]Gmail Inbox Health Report[/bold]", border_style="blue"))

    service = get_gmail_service()

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Gathering inbox statistics...", total=None)

        # Get inbox message count
        progress.update(task, description="Counting inbox messages...")
        inbox = (
            service.users()
            .labels()
            .get(userId="me", id="INBOX")
            .execute()
        )
        total_messages = inbox.get("messagesTotal", 0)
        unread_messages = inbox.get("messagesUnread", 0)

        # Get messages by category
        progress.update(task, description="Analyzing categories...")
        categories: dict[str, int] = {}
        for cat in ["promotions", "social", "updates", "forums", "primary"]:
            try:
                result = (
                    service.users()
                    .messages()
                    .list(userId="me", q=f"label:inbox category:{cat}", maxResults=1)
                    .execute()
                )
                categories[cat] = result.get("resultSizeEstimate", 0)
            except HttpError:
                categories[cat] = 0

        # Get top senders
        progress.update(task, description="Finding top senders...")
        sender_counts: Counter[str] = Counter()
        page_token = None
        messages_checked = 0

        while messages_checked < 200:
            result = (
                service.users()
                .messages()
                .list(
                    userId="me",
                    q="label:inbox",
                    maxResults=100,
                    pageToken=page_token,
                )
                .execute()
            )

            for msg_summary in result.get("messages", []):
                try:
                    msg = (
                        service.users()
                        .messages()
                        .get(
                            userId="me",
                            id=msg_summary["id"],
                            format="metadata",
                            metadataHeaders=["From"],
                        )
                        .execute()
                    )
                    from_header = next(
                        (
                            h["value"]
                            for h in msg.get("payload", {}).get("headers", [])
                            if h["name"].lower() == "from"
                        ),
                        "Unknown",
                    )
                    domain = extract_sender_domain(from_header)
                    sender_counts[domain] += 1
                    messages_checked += 1
                except HttpError:
                    continue

            page_token = result.get("nextPageToken")
            if not page_token:
                break

    # Display report
    console.print(
        Panel(
            f"[bold]Inbox Overview[/bold]\n\n"
            f"  Total messages:  {total_messages:,}\n"
            f"  Unread messages: {unread_messages:,}\n"
            f"  Read rate:       {((total_messages - unread_messages) / max(total_messages, 1) * 100):.1f}%",
            border_style="cyan",
        )
    )

    # Category breakdown
    cat_table = Table(title="Category Distribution")
    cat_table.add_column("Category", style="cyan")
    cat_table.add_column("Estimated Count", style="white", justify="right")

    for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
        cat_table.add_row(cat.title(), str(count))

    console.print(cat_table)

    # Top senders
    sender_table = Table(title="Top 20 Senders (from last 200 messages)")
    sender_table.add_column("Domain", style="cyan")
    sender_table.add_column("Messages", style="white", justify="right")
    sender_table.add_column("% of Sample", style="yellow", justify="right")

    for domain, count in sender_counts.most_common(20):
        pct = count / max(messages_checked, 1) * 100
        sender_table.add_row(domain, str(count), f"{pct:.1f}%")

    console.print(sender_table)

    # Recommendations
    recommendations = []
    if unread_messages > 100:
        recommendations.append("Consider running 'gmailclean scan' to find subscriptions to remove")
    if categories.get("promotions", 0) > 50:
        recommendations.append("High promotions volume - run 'gmailclean unsubscribe' to clean up")
    if sender_counts and sender_counts.most_common(1)[0][1] > 10:
        top_domain = sender_counts.most_common(1)[0][0]
        recommendations.append(
            f"Top sender '{top_domain}' has many messages - consider unsubscribing"
        )

    if recommendations:
        console.print(
            Panel(
                "[bold]Recommendations[/bold]\n\n"
                + "\n".join(f"  - {r}" for r in recommendations),
                border_style="yellow",
            )
        )


def cmd_cleanup(args: argparse.Namespace) -> None:
    """Cleanup command: archive old emails from unsubscribed senders."""
    console.print(Panel("[bold]Cleaning up old subscription emails...[/bold]", border_style="blue"))

    unsub_log = load_unsub_log()
    if not unsub_log.get("unsubscribed"):
        console.print(
            "[yellow]No unsubscribed senders found. Run 'gmailclean unsubscribe' first.[/yellow]"
        )
        return

    service = get_gmail_service()
    domains = [entry["domain"] for entry in unsub_log["unsubscribed"]]

    console.print(f"[dim]Found {len(domains)} unsubscribed domains. Searching for old emails...[/dim]")

    archived_count = 0
    dry_run = getattr(args, "dry_run", False)

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Archiving old emails...", total=len(domains))

        for domain in domains:
            progress.update(task, description=f"Processing {domain}...", advance=1)

            try:
                # Find all emails from this domain still in inbox
                result = (
                    service.users()
                    .messages()
                    .list(userId="me", q=f"from:{domain} label:inbox", maxResults=500)
                    .execute()
                )

                messages = result.get("messages", [])
                if not messages:
                    continue

                if dry_run:
                    console.print(f"  [dim]Would archive {len(messages)} emails from {domain}[/dim]")
                    archived_count += len(messages)
                    continue

                # Batch archive (remove INBOX label)
                msg_ids = [m["id"] for m in messages]
                # Gmail API supports batch modify up to 1000 messages
                for batch_start in range(0, len(msg_ids), 1000):
                    batch = msg_ids[batch_start : batch_start + 1000]
                    service.users().messages().batchModify(
                        userId="me",
                        body={
                            "ids": batch,
                            "removeLabelIds": ["INBOX"],
                        },
                    ).execute()
                    archived_count += len(batch)

            except HttpError:
                continue

    action = "Would archive" if dry_run else "Archived"
    console.print(
        Panel(
            f"[bold green]Cleanup Complete[/bold green]\n\n"
            f"  {action}: {archived_count} emails from {len(domains)} unsubscribed senders\n"
            + ("[dim]Run without --dry-run to actually archive[/dim]" if dry_run else ""),
            border_style="green",
        )
    )


def cmd_archive(args: argparse.Namespace) -> None:
    """Archive command: bulk archive all inbox emails older than N days."""
    days = args.days
    dry_run = args.dry_run
    auto = getattr(args, "auto", False)

    console.print(
        Panel(f"[bold]Archiving inbox emails older than {days} days...[/bold]", border_style="blue")
    )

    service = get_gmail_service()
    query = f"label:inbox older_than:{days}d"

    # Collect all matching message IDs via pagination
    msg_ids: list[str] = []
    page_token = None
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Searching for old emails...", total=None)
        while True:
            result = (
                service.users()
                .messages()
                .list(userId="me", q=query, maxResults=500, pageToken=page_token)
                .execute()
            )
            messages = result.get("messages", [])
            msg_ids.extend(m["id"] for m in messages)
            progress.update(task, description=f"Found {len(msg_ids)} emails so far...")
            page_token = result.get("nextPageToken")
            if not page_token:
                break

    if not msg_ids:
        console.print(f"[green]No inbox emails older than {days} days found. Inbox is clean![/green]")
        return

    if dry_run:
        console.print(
            Panel(
                f"[bold yellow]Dry Run[/bold yellow]\n\n"
                f"  Found: {len(msg_ids)} emails older than {days} days\n"
                f"[dim]Run without --dry-run to actually archive[/dim]",
                border_style="yellow",
            )
        )
        return

    if not auto:
        console.print(f"\n[bold]Found {len(msg_ids)} emails older than {days} days.[/bold]")
        confirm = input("Archive all of them? [y/N] ").strip().lower()
        if confirm not in ("y", "yes"):
            console.print("[yellow]Aborted.[/yellow]")
            return

    # Batch archive: remove INBOX label in chunks of 1000
    archived_count = 0
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Archiving...", total=len(msg_ids))
        for batch_start in range(0, len(msg_ids), 1000):
            batch = msg_ids[batch_start : batch_start + 1000]
            service.users().messages().batchModify(
                userId="me",
                body={
                    "ids": batch,
                    "removeLabelIds": ["INBOX"],
                },
            ).execute()
            archived_count += len(batch)
            progress.update(task, advance=len(batch), description=f"Archived {archived_count}/{len(msg_ids)}...")

    console.print(
        Panel(
            f"[bold green]Archive Complete[/bold green]\n\n"
            f"  Archived: {archived_count} emails older than {days} days",
            border_style="green",
        )
    )


def cmd_centralize(args: argparse.Namespace) -> None:
    """Centralize command: set up forwarding filters and show account consolidation info."""
    console.print(
        Panel(
            "[bold]Email Centralization Setup[/bold]\n\n"
            "This helps you consolidate multiple email accounts into one Gmail inbox.",
            border_style="blue",
        )
    )

    service = get_gmail_service()

    # Show current forwarding/send-as addresses
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Checking account configuration...", total=None)

        # Get profile info
        progress.update(task, description="Getting profile...")
        profile = service.users().getProfile(userId="me").execute()
        primary_email = profile.get("emailAddress", "unknown")

        # List send-as addresses (shows linked accounts)
        progress.update(task, description="Checking linked accounts...")
        try:
            send_as_result = (
                service.users().settings().sendAs().list(userId="me").execute()
            )
            send_as_addresses = send_as_result.get("sendAs", [])
        except HttpError:
            send_as_addresses = []

        # List forwarding addresses
        progress.update(task, description="Checking forwarding rules...")
        try:
            fwd_result = (
                service.users()
                .settings()
                .forwardingAddresses()
                .list(userId="me")
                .execute()
            )
            forwarding_addresses = fwd_result.get("forwardingAddresses", [])
        except HttpError:
            forwarding_addresses = []

        # List existing filters
        progress.update(task, description="Checking filters...")
        try:
            filters_result = (
                service.users().settings().filters().list(userId="me").execute()
            )
            existing_filters = filters_result.get("filter", [])
        except HttpError:
            existing_filters = []

    # Display current state
    console.print(
        Panel(
            f"[bold]Primary Account:[/bold] {primary_email}",
            border_style="cyan",
        )
    )

    if send_as_addresses:
        sa_table = Table(title="Send-As Addresses (linked accounts)")
        sa_table.add_column("Email", style="cyan")
        sa_table.add_column("Display Name", style="white")
        sa_table.add_column("Default", style="yellow")

        for sa in send_as_addresses:
            sa_table.add_row(
                sa.get("sendAsEmail", ""),
                sa.get("displayName", ""),
                "Yes" if sa.get("isDefault") else "",
            )
        console.print(sa_table)

    if forwarding_addresses:
        fwd_table = Table(title="Forwarding Addresses")
        fwd_table.add_column("Email", style="cyan")
        fwd_table.add_column("Verified", style="green")

        for fwd in forwarding_addresses:
            fwd_table.add_row(
                fwd.get("forwardingEmail", ""),
                fwd.get("verificationStatus", ""),
            )
        console.print(fwd_table)

    console.print(f"\n[dim]Active filters: {len(existing_filters)}[/dim]")

    # Provide setup instructions
    console.print(
        Panel(
            "[bold]How to Consolidate Email Accounts[/bold]\n\n"
            "[cyan]Option 1: Import mail from other accounts[/cyan]\n"
            "  Settings > Accounts > Check mail from other accounts\n"
            "  - Gmail will fetch mail from other POP3/IMAP accounts\n"
            "  - Reply as the original account address\n\n"
            "[cyan]Option 2: Forward other accounts to Gmail[/cyan]\n"
            "  In each external account, set up forwarding to:\n"
            f"  [bold]{primary_email}[/bold]\n\n"
            "[cyan]Option 3: Add send-as addresses[/cyan]\n"
            "  Settings > Accounts > Send mail as\n"
            "  - Send from your other email addresses via Gmail\n"
            "  - Keeps everything in one place\n\n"
            "[dim]Gmail Settings URL: https://mail.google.com/mail/u/0/#settings/accounts[/dim]",
            border_style="yellow",
        )
    )

    if Confirm.ask("Open Gmail account settings in browser?", default=False):
        webbrowser.open("https://mail.google.com/mail/u/0/#settings/accounts")


def cmd_nuke(args: argparse.Namespace) -> None:
    """Nuke command: full cleanup pipeline."""
    auto_mode = getattr(args, "auto", False) or getattr(args, "yes", False)

    console.print(
        Panel(
            "[bold red]FULL INBOX CLEANUP[/bold red]\n\n"
            "This will:\n"
            "  1. Scan your inbox for subscriptions\n"
            "  2. Help you unsubscribe from them\n"
            "  3. Archive old emails from unsubscribed senders\n"
            "  4. Create labels and filters to organize remaining mail\n"
            "  5. Generate a health report",
            border_style="red",
        )
    )

    if not auto_mode and not Confirm.ask("[bold]Proceed with full cleanup?[/bold]"):
        return

    # Step 1: Scan
    console.print("\n[bold cyan]Step 1/5: Scanning inbox...[/bold cyan]")
    service = get_gmail_service()
    subscriptions = scan_inbox(service, max_results=getattr(args, "max_results", 500))

    if subscriptions:
        display_subscriptions(subscriptions)

        # Step 2: Unsubscribe
        console.print("\n[bold cyan]Step 2/5: Unsubscribe[/bold cyan]")
        if auto_mode or Confirm.ask("Would you like to unsubscribe from detected subscriptions?"):
            unsub_args = argparse.Namespace(
                rescan=False,
                max_results=getattr(args, "max_results", 500),
                auto=auto_mode,
                yes=auto_mode,
            )
            cmd_unsubscribe(unsub_args)

        # Step 3: Cleanup
        console.print("\n[bold cyan]Step 3/5: Archiving old subscription emails...[/bold cyan]")
        if auto_mode or Confirm.ask("Archive old emails from unsubscribed senders?"):
            cleanup_args = argparse.Namespace(dry_run=False)
            cmd_cleanup(cleanup_args)
    else:
        console.print("[green]No subscriptions found to unsubscribe from.[/green]")

    # Step 4: Organize
    console.print("\n[bold cyan]Step 4/5: Organizing inbox...[/bold cyan]")
    organize_args = argparse.Namespace()
    cmd_organize(organize_args)

    # Step 5: Report
    console.print("\n[bold cyan]Step 5/5: Generating report...[/bold cyan]")
    report_args = argparse.Namespace()
    cmd_report(report_args)

    console.print(
        Panel("[bold green]Cleanup complete![/bold green]", border_style="green")
    )


def cmd_extract(args: argparse.Namespace) -> None:
    """Extract command: classify emails and generate Obsidian notes."""
    from ollama import (
        classify_email as llm_classify,
        extract_contact,
        extract_newsletter,
        extract_receipt,
        ollama_available,
    )
    from obsidian import (
        find_relationship_file,
        get_vault_path,
        slugify,
        update_relationship_file,
        write_newsletter_note,
        write_receipt_note,
        write_relationship_note,
    )

    vault = get_vault_path(getattr(args, "vault", None))
    model = getattr(args, "model", "llama3.1:8b")
    dry_run = getattr(args, "dry_run", False)
    no_llm = getattr(args, "no_llm", False)
    auto_mode = getattr(args, "auto", False) or getattr(args, "yes", False)
    categories_filter = getattr(args, "categories", "all")
    max_results = getattr(args, "max_results", 100)

    since = getattr(args, "since", None)
    if since:
        since_date = datetime.strptime(since, "%Y-%m-%d").date()
    else:
        from datetime import timedelta
        since_date = (datetime.now() - timedelta(days=1)).date()

    console.print(
        Panel(
            f"[bold]Email Intelligence Extraction[/bold]\n\n"
            f"  Since: {since_date}\n"
            f"  Vault: {vault}\n"
            f"  Model: {model}\n"
            f"  Categories: {categories_filter}\n"
            f"  Dry run: {dry_run}",
            border_style="blue",
        )
    )

    # Check Ollama availability
    if not no_llm and not ollama_available():
        console.print(
            "[red]Ollama is not running![/red]\n"
            "[dim]Start Ollama with: ollama serve[/dim]\n"
            "[dim]Or use --no-llm for header-only classification[/dim]"
        )
        sys.exit(1)

    service = get_gmail_service()
    extract_log = load_extract_log()

    # Calculate days since for Gmail query
    days_since = (datetime.now().date() - since_date).days
    query = f"newer_than:{max(days_since, 1)}d"

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Listing messages...", total=None)

        # List messages
        all_msg_ids: list[str] = []
        page_token = None
        while len(all_msg_ids) < max_results:
            result = (
                service.users()
                .messages()
                .list(
                    userId="me",
                    q=query,
                    maxResults=min(100, max_results - len(all_msg_ids)),
                    pageToken=page_token,
                )
                .execute()
            )
            messages = result.get("messages", [])
            for msg in messages:
                if msg["id"] not in extract_log["processed_ids"]:
                    all_msg_ids.append(msg["id"])
            page_token = result.get("nextPageToken")
            if not page_token:
                break

        progress.update(task, description=f"Found {len(all_msg_ids)} new messages to process")

    if not all_msg_ids:
        console.print("[green]No new messages to process.[/green]")
        return

    if not auto_mode and not dry_run:
        if not Confirm.ask(f"Process {len(all_msg_ids)} messages?"):
            return

    # Process each message
    results: dict[str, list[dict]] = {"newsletter": [], "receipt": [], "personal": [], "skip": []}

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Processing emails...", total=len(all_msg_ids))

        for i, msg_id in enumerate(all_msg_ids):
            progress.update(task, description=f"Processing {i+1}/{len(all_msg_ids)}...", advance=1)

            try:
                body_data = fetch_email_body(service, msg_id)
            except Exception as e:
                console.print(f"[dim]Skipping {msg_id}: {e}[/dim]")
                continue

            from_header = body_data["from"]
            subject = body_data["subject"]
            text = body_data["text"]
            email_date_str = body_data["date"]

            # Parse email date
            try:
                email_date = datetime.strptime(
                    re.sub(r"\s*\([^)]*\)\s*$", "", email_date_str),
                    "%a, %d %b %Y %H:%M:%S %z",
                ).date()
            except (ValueError, TypeError):
                email_date = datetime.now().date()

            # Classify
            if no_llm:
                # Header-only classification
                cat = categorize_email(subject, from_header)
                cat_map = {"Newsletters": "newsletter", "Finance": "receipt", "Shopping": "receipt"}
                category = cat_map.get(cat, "skip") if cat else "skip"
                confidence = 0.5
            else:
                preview = text[:4000] if text else ""
                classification = llm_classify(from_header, subject, preview, model)
                category = classification.get("category", "skip")
                confidence = classification.get("confidence", 0.0)

            # Apply category filter
            if categories_filter != "all" and category not in categories_filter.split(","):
                continue

            entry: dict[str, Any] = {
                "msg_id": msg_id,
                "from": from_header,
                "subject": subject,
                "date": str(email_date),
                "category": category,
                "confidence": confidence,
            }

            if category == "newsletter" and not no_llm:
                data = extract_newsletter(text, model)
                data["email_from"] = from_header
                entry["data"] = data
                if not dry_run:
                    path = write_newsletter_note(vault, data, email_date)
                    entry["obsidian_path"] = str(path.relative_to(vault))
                    extract_log["stats"]["newsletters"] += 1

            elif category == "receipt" and not no_llm:
                data = extract_receipt(text, model)
                entry["data"] = data
                if not dry_run:
                    path = write_receipt_note(vault, data, email_date)
                    entry["obsidian_path"] = str(path.relative_to(vault))
                    extract_log["stats"]["receipts"] += 1

            elif category == "personal" and not no_llm:
                data = extract_contact(text, from_header, model)
                entry["data"] = data
                if not dry_run:
                    existing = find_relationship_file(
                        vault, data.get("sender_name", ""), data.get("email", "")
                    )
                    if existing:
                        update_relationship_file(
                            existing, data.get("interaction_summary", "Email"), email_date
                        )
                        entry["obsidian_path"] = str(existing.relative_to(vault))
                    else:
                        path = write_relationship_note(vault, data, email_date)
                        entry["obsidian_path"] = str(path.relative_to(vault))
                    extract_log["stats"]["contacts"] += 1

            results[category].append(entry)

            if not dry_run:
                extract_log["processed_ids"][msg_id] = {
                    "category": category,
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                    "obsidian_path": entry.get("obsidian_path"),
                }

            # Rate limit: 50ms between full-body fetches
            time.sleep(0.05)

    # Save extract log
    if not dry_run:
        save_extract_log(extract_log)

    # Display summary
    table = Table(title="Extraction Results")
    table.add_column("Category", style="cyan")
    table.add_column("Count", style="white", justify="right")
    table.add_column("Details", style="dim")

    for cat in ["newsletter", "receipt", "personal", "skip"]:
        items = results[cat]
        if items:
            details = ", ".join(
                f"{e.get('data', {}).get('source_name', e.get('data', {}).get('merchant', e.get('subject', '')[:30]))}"
                for e in items[:3]
            )
            if len(items) > 3:
                details += f" +{len(items) - 3} more"
            table.add_row(cat.title(), str(len(items)), details)

    console.print(table)

    action = "Would write" if dry_run else "Wrote"
    total_notes = len(results["newsletter"]) + len(results["receipt"]) + len(results["personal"])
    console.print(
        Panel(
            f"[bold green]Extraction Complete[/bold green]\n\n"
            f"  {action} {total_notes} Obsidian notes\n"
            f"  Newsletters: {len(results['newsletter'])}\n"
            f"  Receipts: {len(results['receipt'])}\n"
            f"  Contacts: {len(results['personal'])}\n"
            f"  Skipped: {len(results['skip'])}",
            border_style="green",
        )
    )


def cmd_briefing(args: argparse.Namespace) -> None:
    """Briefing command: generate daily email briefing for Obsidian."""
    from obsidian import append_briefing_to_daily, get_vault_path

    vault = get_vault_path(getattr(args, "vault", None))
    dry_run = getattr(args, "dry_run", False)
    quiet = getattr(args, "quiet", False)

    briefing_date_str = getattr(args, "date", None)
    if briefing_date_str:
        briefing_date = datetime.strptime(briefing_date_str, "%Y-%m-%d").date()
    else:
        briefing_date = datetime.now().date()

    if not quiet:
        console.print(
            Panel(
                f"[bold]Daily Email Briefing[/bold]\n\n"
                f"  Date: {briefing_date}\n"
                f"  Vault: {vault}",
                border_style="blue",
            )
        )

    extract_log = load_extract_log()

    # Aggregate today's extractions from the log
    briefing_data: dict[str, list[dict]] = {
        "newsletters": [],
        "contacts": [],
        "receipts": [],
        "action_items": [],
    }

    for msg_id, entry in extract_log.get("processed_ids", {}).items():
        processed_date = entry.get("processed_at", "")
        if not processed_date.startswith(briefing_date.isoformat()):
            continue

        category = entry.get("category", "")
        obsidian_path = entry.get("obsidian_path", "")

        if category == "newsletter":
            briefing_data["newsletters"].append({
                "source_name": obsidian_path.split("/")[-1].replace(".md", "").split("-", 3)[-1].replace("-", " ").title() if obsidian_path else "Newsletter",
                "obsidian_path": obsidian_path,
            })
        elif category == "receipt":
            # Try to extract merchant/amount from path
            parts = obsidian_path.split("/")[-1].replace(".md", "").split("-", 3) if obsidian_path else []
            briefing_data["receipts"].append({
                "merchant": parts[-1].replace("-", " ").title() if len(parts) > 3 else "Purchase",
                "amount": 0,
                "currency": "GBP",
                "obsidian_path": obsidian_path,
            })
        elif category == "personal":
            parts = obsidian_path.split("/")[-1].replace(".md", "").replace("-", " ").title() if obsidian_path else "Contact"
            briefing_data["contacts"].append({
                "sender_name": parts if isinstance(parts, str) else "Contact",
            })

    total = (
        len(briefing_data["newsletters"])
        + len(briefing_data["receipts"])
        + len(briefing_data["contacts"])
    )

    if total == 0:
        if not quiet:
            console.print("[yellow]No extracted emails found for this date.[/yellow]")
            console.print("[dim]Run 'gmailclean extract' first.[/dim]")
        return

    if dry_run:
        if not quiet:
            console.print("[bold]Briefing preview:[/bold]")
            if briefing_data["newsletters"]:
                console.print(f"  Newsletters: {len(briefing_data['newsletters'])}")
            if briefing_data["contacts"]:
                console.print(f"  People: {len(briefing_data['contacts'])}")
            if briefing_data["receipts"]:
                console.print(f"  Receipts: {len(briefing_data['receipts'])}")
        return

    daily_path = append_briefing_to_daily(vault, briefing_date, briefing_data)

    if not quiet:
        console.print(
            Panel(
                f"[bold green]Briefing Complete[/bold green]\n\n"
                f"  Daily note: {daily_path}\n"
                f"  Newsletters: {len(briefing_data['newsletters'])}\n"
                f"  People: {len(briefing_data['contacts'])}\n"
                f"  Receipts: {len(briefing_data['receipts'])}",
                border_style="green",
            )
        )


def cmd_contacts(args: argparse.Namespace) -> None:
    """Contacts command: build contact graph from email history."""
    from ollama import extract_contact, ollama_available
    from obsidian import (
        find_relationship_file,
        get_vault_path,
        update_relationship_file,
        write_relationship_note,
    )

    vault = get_vault_path(getattr(args, "vault", None))
    dry_run = getattr(args, "dry_run", False)
    update_existing = getattr(args, "update_existing", False)
    max_results = getattr(args, "max_results", 500)

    since = getattr(args, "since", None)
    if since:
        since_date = datetime.strptime(since, "%Y-%m-%d").date()
    else:
        from datetime import timedelta
        since_date = (datetime.now() - timedelta(days=30)).date()

    console.print(
        Panel(
            f"[bold]Contact Graph Builder[/bold]\n\n"
            f"  Since: {since_date}\n"
            f"  Vault: {vault}\n"
            f"  Update existing: {update_existing}\n"
            f"  Dry run: {dry_run}",
            border_style="blue",
        )
    )

    if not ollama_available():
        console.print(
            "[red]Ollama is not running![/red]\n"
            "[dim]Start Ollama with: ollama serve[/dim]"
        )
        sys.exit(1)

    service = get_gmail_service()

    days_since = (datetime.now().date() - since_date).days
    # Focus on emails from real people, not automated
    query = f"newer_than:{max(days_since, 1)}d -category:promotions -category:social -category:updates"

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Finding personal emails...", total=None)

        all_msg_ids: list[str] = []
        page_token = None
        while len(all_msg_ids) < max_results:
            result = (
                service.users()
                .messages()
                .list(
                    userId="me",
                    q=query,
                    maxResults=min(100, max_results - len(all_msg_ids)),
                    pageToken=page_token,
                )
                .execute()
            )
            messages = result.get("messages", [])
            all_msg_ids.extend(m["id"] for m in messages)
            page_token = result.get("nextPageToken")
            if not page_token:
                break

        progress.update(task, description=f"Found {len(all_msg_ids)} potential personal emails")

    if not all_msg_ids:
        console.print("[green]No personal emails found in the given period.[/green]")
        return

    created = 0
    updated = 0
    skipped = 0

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Analyzing contacts...", total=len(all_msg_ids))

        for i, msg_id in enumerate(all_msg_ids):
            progress.update(task, description=f"Analyzing {i+1}/{len(all_msg_ids)}...", advance=1)

            try:
                body_data = fetch_email_body(service, msg_id)
            except Exception:
                skipped += 1
                continue

            from_header = body_data["from"]
            text = body_data["text"]

            try:
                email_date = datetime.strptime(
                    re.sub(r"\s*\([^)]*\)\s*$", "", body_data["date"]),
                    "%a, %d %b %Y %H:%M:%S %z",
                ).date()
            except (ValueError, TypeError):
                email_date = datetime.now().date()

            data = extract_contact(text, from_header)
            name = data.get("sender_name", "")
            email_addr = data.get("email", "")

            if not name or name == "Unknown":
                skipped += 1
                continue

            existing = find_relationship_file(vault, name, email_addr)

            if existing:
                if update_existing and not dry_run:
                    update_relationship_file(
                        existing, data.get("interaction_summary", "Email"), email_date
                    )
                    updated += 1
                elif not update_existing:
                    skipped += 1
                else:
                    updated += 1  # dry run count
            else:
                if not dry_run:
                    write_relationship_note(vault, data, email_date)
                created += 1

            time.sleep(0.05)

    action = "Would create" if dry_run else "Created"
    update_action = "Would update" if dry_run else "Updated"
    console.print(
        Panel(
            f"[bold green]Contact Analysis Complete[/bold green]\n\n"
            f"  {action}: {created} new contacts\n"
            f"  {update_action}: {updated} existing contacts\n"
            f"  Skipped: {skipped}",
            border_style="green",
        )
    )


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="gmailclean - Gmail inbox cleanup tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--account", type=str, default=None,
        help="Account profile name (uses ~/.config/gmailclean/accounts/<name>/)",
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # scan command
    scan_parser = subparsers.add_parser("scan", help="Scan inbox for subscriptions")
    scan_parser.add_argument(
        "--max-results", type=int, default=500, help="Maximum messages to scan (default: 500)"
    )

    # unsubscribe command
    unsub_parser = subparsers.add_parser("unsubscribe", help="Unsubscribe from newsletters")
    unsub_parser.add_argument("--rescan", action="store_true", help="Force rescan instead of using cache")
    unsub_parser.add_argument("--max-results", type=int, default=500, help="Max messages to scan")
    unsub_parser.add_argument(
        "--auto", "--yes", "-y", action="store_true", dest="auto",
        help="Non-interactive: unsubscribe from all without prompting",
    )

    # organize command
    subparsers.add_parser("organize", help="Create labels and filters")

    # report command
    subparsers.add_parser("report", help="Generate inbox health report")

    # cleanup command
    cleanup_parser = subparsers.add_parser(
        "cleanup", help="Archive old emails from unsubscribed senders"
    )
    cleanup_parser.add_argument(
        "--dry-run", action="store_true", help="Show what would be archived without doing it"
    )

    # archive command
    archive_parser = subparsers.add_parser("archive", help="Bulk archive old inbox emails")
    archive_parser.add_argument(
        "--days", type=int, default=30, help="Archive emails older than N days (default: 30)"
    )
    archive_parser.add_argument(
        "--dry-run", action="store_true", help="Show count without archiving"
    )
    archive_parser.add_argument(
        "--auto", "--yes", "-y", action="store_true", dest="auto",
        help="Skip confirmation prompt",
    )

    # centralize command
    subparsers.add_parser(
        "centralize", help="Set up forwarding rules to consolidate email accounts"
    )

    # nuke command
    nuke_parser = subparsers.add_parser("nuke", help="Full cleanup: scan + unsubscribe + organize")
    nuke_parser.add_argument("--max-results", type=int, default=500, help="Max messages to scan")
    nuke_parser.add_argument(
        "--auto", "--yes", "-y", action="store_true", dest="auto",
        help="Non-interactive: run full cleanup without prompting",
    )

    # extract command
    extract_parser = subparsers.add_parser(
        "extract", help="Extract insights from emails into Obsidian notes"
    )
    extract_parser.add_argument(
        "--since", type=str, default=None,
        help="Process emails since date (YYYY-MM-DD, default: yesterday)",
    )
    extract_parser.add_argument("--max-results", type=int, default=100, help="Max emails to process")
    extract_parser.add_argument(
        "--categories", type=str, default="all",
        help="Filter: newsletter,receipt,personal,all (default: all)",
    )
    extract_parser.add_argument("--dry-run", action="store_true", help="Preview without writing files")
    extract_parser.add_argument("--vault", type=str, default=None, help="Obsidian vault path")
    extract_parser.add_argument(
        "--model", type=str, default="llama3.1:8b", help="Ollama model (default: llama3.1:8b)"
    )
    extract_parser.add_argument(
        "--no-llm", action="store_true", help="Header-only classification, skip body extraction"
    )
    extract_parser.add_argument(
        "--auto", "--yes", "-y", action="store_true", dest="auto",
        help="Skip confirmation prompt",
    )

    # briefing command
    briefing_parser = subparsers.add_parser(
        "briefing", help="Generate daily email briefing in Obsidian"
    )
    briefing_parser.add_argument(
        "--date", type=str, default=None,
        help="Date for briefing (YYYY-MM-DD, default: today)",
    )
    briefing_parser.add_argument("--vault", type=str, default=None, help="Obsidian vault path")
    briefing_parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    briefing_parser.add_argument("--quiet", action="store_true", help="Suppress output (for cron)")

    # contacts command
    contacts_parser = subparsers.add_parser(
        "contacts", help="Build contact graph from email history"
    )
    contacts_parser.add_argument(
        "--since", type=str, default=None,
        help="Analyze since date (YYYY-MM-DD, default: 30 days ago)",
    )
    contacts_parser.add_argument("--max-results", type=int, default=500, help="Max emails to analyze")
    contacts_parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    contacts_parser.add_argument("--vault", type=str, default=None, help="Obsidian vault path")
    contacts_parser.add_argument(
        "--update-existing", action="store_true",
        help="Update existing contact files (default: create-only)",
    )

    args = parser.parse_args()

    configure_account(args.account)

    if not args.command:
        parser.print_help()
        sys.exit(0)

    commands = {
        "scan": cmd_scan,
        "unsubscribe": cmd_unsubscribe,
        "organize": cmd_organize,
        "report": cmd_report,
        "cleanup": cmd_cleanup,
        "archive": cmd_archive,
        "centralize": cmd_centralize,
        "nuke": cmd_nuke,
        "extract": cmd_extract,
        "briefing": cmd_briefing,
        "contacts": cmd_contacts,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
