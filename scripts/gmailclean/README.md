# gmailclean

Gmail inbox cleanup tool that scans for subscriptions, unsubscribes from newsletters, and organizes your inbox with labels and filters.

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

# Create labels and filters to organize inbox
gmailclean organize

# Generate inbox health report
gmailclean report

# Full cleanup: scan + unsubscribe + organize + report
gmailclean nuke
```

### Options

```bash
gmailclean scan --max-results 1000    # Scan more messages
gmailclean unsubscribe --rescan       # Force rescan before unsubscribing
```

## How It Works

### Scan
Searches Gmail for emails with `List-Unsubscribe` headers (the standard way newsletters embed unsubscribe links). Deduplicates by sender domain and categorizes emails.

### Unsubscribe
Opens unsubscribe URLs in your browser for one-click unsubscription. Supports:
- **URL-based**: Opens the unsubscribe link directly
- **Mailto-based**: Lists email addresses for manual unsubscription
- **Interactive selection**: Choose all, pick individually, or specify ranges

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

## Files

- `~/.config/gmailclean/credentials.json` - Google API credentials (you create this)
- `~/.config/gmailclean/token.json` - OAuth refresh token (auto-generated)
- `~/.config/gmailclean/scan_cache.json` - Cached scan results

## Security

- Credentials are stored locally in `~/.config/gmailclean/`
- OAuth2 tokens have offline refresh capability
- The tool uses `gmail.modify` scope (read/write) and `gmail.settings.basic` (create filters)
- No data is sent to third parties - all communication is directly with Gmail API
