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
    gmailclean nuke          - Full cleanup: scan + unsubscribe + organize
"""

from __future__ import annotations

import argparse
import base64
import email
import json
import os
import re
import sys
import webbrowser
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

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
TOKEN_PATH = CONFIG_DIR / "token.json"
CREDENTIALS_PATH = CONFIG_DIR / "credentials.json"
SCAN_CACHE_PATH = CONFIG_DIR / "scan_cache.json"

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


def extract_unsubscribe_info(headers: list[dict]) -> dict[str, str | None]:
    """Extract unsubscribe URL and mailto from email headers."""
    info: dict[str, str | None] = {"url": None, "mailto": None}

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

    return info


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

                    # Deduplicate by domain
                    if domain in seen_senders:
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
                            "category": category,
                            "labels": [
                                l["name"]
                                for l in msg.get("labelIds", [])
                                if isinstance(l, str)
                            ]
                            if isinstance(msg.get("labelIds"), list)
                            else msg.get("labelIds", []),
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
    table.add_column("Category", style="yellow", max_width=15)
    table.add_column("Subject (latest)", style="white", max_width=40)
    table.add_column("Unsub", style="green", width=6)

    for i, sub in enumerate(subscriptions, 1):
        has_unsub = "URL" if sub["unsubscribe_url"] else "Email" if sub["unsubscribe_mailto"] else "-"
        table.add_row(
            str(i),
            sub["sender_name"][:30],
            sub["domain"][:25],
            sub.get("category") or "-",
            sub["subject"][:40],
            has_unsub,
        )

    console.print(table)

    # Summary stats
    categories = Counter(sub.get("category") or "Uncategorized" for sub in subscriptions)
    console.print("\n[bold]Category Breakdown:[/bold]")
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
    if SCAN_CACHE_PATH.exists() and not args.rescan:
        console.print("[dim]Loading cached scan results...[/dim]")
        subscriptions = json.loads(SCAN_CACHE_PATH.read_text())
    else:
        console.print("[yellow]No cached scan found. Running scan first...[/yellow]")
        service = get_gmail_service()
        subscriptions = scan_inbox(service, max_results=args.max_results)

    if not subscriptions:
        console.print("[green]No subscriptions to unsubscribe from.[/green]")
        return

    display_subscriptions(subscriptions)

    console.print(
        Panel(
            "[bold]Unsubscribe Mode[/bold]\n\n"
            "Options:\n"
            "  [cyan]all[/cyan]     - Open unsubscribe links for ALL subscriptions\n"
            "  [cyan]pick[/cyan]    - Select which ones to unsubscribe from\n"
            "  [cyan]range[/cyan]   - Specify a range (e.g., 1-10,15,20-25)\n"
            "  [cyan]cancel[/cyan]  - Exit without unsubscribing",
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
        if not Confirm.ask(
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
        console.print("[dim]Enter numbers separated by commas, or 'done' to finish:[/dim]")
        for i, sub in enumerate(subscriptions, 1):
            if Confirm.ask(f"  [{i}] {sub['sender_name']} ({sub['domain']})?", default=False):
                indices_to_unsub.append(i - 1)

    # Process unsubscriptions
    opened = 0
    mailto_list: list[str] = []
    failed: list[str] = []

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

            if sub.get("unsubscribe_url"):
                try:
                    webbrowser.open(sub["unsubscribe_url"])
                    opened += 1
                except Exception:
                    failed.append(sub["domain"])
            elif sub.get("unsubscribe_mailto"):
                mailto_list.append(f"{sub['sender_name']}: {sub['unsubscribe_mailto']}")
            else:
                failed.append(sub["domain"])

    # Report
    console.print(
        Panel(
            f"[bold green]Unsubscribe Summary[/bold green]\n\n"
            f"  Opened in browser: {opened}\n"
            f"  Mailto (manual):   {len(mailto_list)}\n"
            f"  Failed:            {len(failed)}\n",
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


def cmd_nuke(args: argparse.Namespace) -> None:
    """Nuke command: full cleanup pipeline."""
    console.print(
        Panel(
            "[bold red]FULL INBOX CLEANUP[/bold red]\n\n"
            "This will:\n"
            "  1. Scan your inbox for subscriptions\n"
            "  2. Help you unsubscribe from them\n"
            "  3. Create labels and filters to organize remaining mail\n"
            "  4. Generate a health report",
            border_style="red",
        )
    )

    if not Confirm.ask("[bold]Proceed with full cleanup?[/bold]"):
        return

    # Step 1: Scan
    console.print("\n[bold cyan]Step 1/4: Scanning inbox...[/bold cyan]")
    service = get_gmail_service()
    subscriptions = scan_inbox(service, max_results=args.max_results)

    if subscriptions:
        display_subscriptions(subscriptions)

        # Step 2: Unsubscribe
        console.print("\n[bold cyan]Step 2/4: Unsubscribe[/bold cyan]")
        if Confirm.ask("Would you like to unsubscribe from detected subscriptions?"):
            unsub_args = argparse.Namespace(rescan=False, max_results=args.max_results)
            cmd_unsubscribe(unsub_args)
    else:
        console.print("[green]No subscriptions found to unsubscribe from.[/green]")

    # Step 3: Organize
    console.print("\n[bold cyan]Step 3/4: Organizing inbox...[/bold cyan]")
    organize_args = argparse.Namespace()
    cmd_organize(organize_args)

    # Step 4: Report
    console.print("\n[bold cyan]Step 4/4: Generating report...[/bold cyan]")
    report_args = argparse.Namespace()
    cmd_report(report_args)

    console.print(
        Panel("[bold green]Cleanup complete![/bold green]", border_style="green")
    )


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="gmailclean - Gmail inbox cleanup tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
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

    # organize command
    subparsers.add_parser("organize", help="Create labels and filters")

    # report command
    subparsers.add_parser("report", help="Generate inbox health report")

    # nuke command
    nuke_parser = subparsers.add_parser("nuke", help="Full cleanup: scan + unsubscribe + organize")
    nuke_parser.add_argument("--max-results", type=int, default=500, help="Max messages to scan")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    commands = {
        "scan": cmd_scan,
        "unsubscribe": cmd_unsubscribe,
        "organize": cmd_organize,
        "report": cmd_report,
        "nuke": cmd_nuke,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
