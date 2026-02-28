# gmailclean

Gmail inbox cleanup tool that scans for subscriptions, bulk-unsubscribes from newsletters, organizes your inbox with labels and filters, and helps consolidate email accounts.

## Setup

### 1. Install dependencies

```bash
./scripts/gmailclean/setup.sh
```

### 2. Configure Gmail API

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project (or select existing)
3. Enable the **Gmail API** (APIs & Services > Library > search "Gmail API")
4. Create **OAuth 2.0 Client ID** (Credentials > Create Credentials > OAuth client ID > Desktop application)
5. Download the credentials JSON file
6. Save it to `~/.config/gmailclean/credentials.json`

On first run, a browser window will open for OAuth authorization.

## Usage

```bash
# Scan inbox for subscriptions
gmailclean scan

# Unsubscribe from detected newsletters (interactive)
gmailclean unsubscribe

# Unsubscribe from ALL subscriptions without prompting
gmailclean unsubscribe --auto

# Create labels and filters to organize inbox
gmailclean organize

# Generate inbox health report
gmailclean report

# Archive old emails from unsubscribed senders
gmailclean cleanup
gmailclean cleanup --dry-run    # Preview without archiving

# Set up email account consolidation
gmailclean centralize

# Full cleanup: scan + unsubscribe + cleanup + organize + report
gmailclean nuke
gmailclean nuke --auto          # Non-interactive full cleanup
 
# Permanently delete emails matching a query (irreversible)
gmailclean purge --query "from:some@sender.com subject:promo" --dry-run
gmailclean purge --query "hotel" --yes   # Executes after confirmation
```

### Options

```bash
gmailclean scan --max-results 1000      # Scan more messages
gmailclean unsubscribe --rescan         # Force rescan before unsubscribing
gmailclean unsubscribe --auto           # Non-interactive unsubscribe all
gmailclean cleanup --dry-run            # Preview archive without acting
gmailclean nuke --auto --max-results 1000  # Full auto cleanup
```

## How It Works

### Scan
Searches Gmail for emails with `List-Unsubscribe` headers (the standard way newsletters embed unsubscribe links). Deduplicates by sender domain, tracks email frequency per sender, and categorizes emails.

### Unsubscribe
Three-tier unsubscribe approach:
- **One-click (RFC 8058)**: Automatically sends HTTP POST to unsubscribe - no browser needed. Used when `List-Unsubscribe-Post` header is present.
- **URL-based**: Opens the unsubscribe link in your browser for manual confirmation.
- **Mailto-based**: Lists email addresses for manual unsubscription.

Selection modes: all, pick individually, specify ranges, or `--auto` for fully non-interactive.

### Cleanup
Archives (removes from inbox) old emails from senders you've already unsubscribed from. Uses the unsubscribe log to identify which domains to clean up. Supports `--dry-run` to preview.

### Organize
Creates labels under `AutoClean/` and Gmail filters to automatically categorize incoming mail:
- `AutoClean/Newsletters` - Newsletters and digests
- `AutoClean/Notifications` - Alerts and status updates
- `AutoClean/Social` - Social media notifications
- `AutoClean/Promotions` - Sales and promotional emails
- `AutoClean/Finance` - Banking and payment notifications
- `AutoClean/Shopping` - Order and shipping notifications

### Report
Generates an inbox health report showing:
- Total/unread message counts
- Category distribution
- Top senders by volume
- Actionable recommendations

### Centralize
Helps consolidate multiple email accounts into one Gmail inbox:
- Shows current linked accounts and forwarding rules
- Provides step-by-step instructions for importing mail from other accounts
- Options: POP3/IMAP import, forwarding, and send-as addresses

### Nuke
Full cleanup pipeline: scan + unsubscribe + cleanup + organize + report. Use `--auto` for a fully non-interactive run.

## Files

- `~/.config/gmailclean/credentials.json` - Google API credentials (you create this)
- `~/.config/gmailclean/token.json` - OAuth refresh token (auto-generated)
- `~/.config/gmailclean/scan_cache.json` - Cached scan results
- `~/.config/gmailclean/unsubscribed.json` - Log of unsubscribed domains

## Security

- Credentials are stored locally in `~/.config/gmailclean/`
- OAuth2 tokens have offline refresh capability
- The tool uses `gmail.modify` scope (read/write) and `gmail.settings.basic` (create filters)
- No data is sent to third parties - all communication is directly with Gmail API
- One-click unsubscribe sends only the RFC 8058 standard POST body to the newsletter's own unsubscribe endpoint
 - Purge requests additional `https://mail.google.com/` scope on first use for permanent delete
