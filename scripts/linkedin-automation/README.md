# LinkedIn Automation Scripts

Playwright-based scripts for LinkedIn networking automation. Finds people who engage with your content (commenters, likers) and view your profile, then sends connection requests.

## Setup

```bash
cd scripts/linkedin-automation
bun install        # or: npm install
```

## First Run: Save Your Session

Before running any automation, save your LinkedIn login session:

```bash
node save-session.mjs
```

This opens a browser. Log in to LinkedIn, then press Ctrl+C. Your session is saved to `~/.linkedin-automation-session/` and reused by all scripts.

## Scripts

### Connect with Post Engagers
```bash
# Connect with commenters on your recent posts
node connect-post-engagers.mjs --type=commenters

# Connect with likers
node connect-post-engagers.mjs --type=likers

# Both commenters and likers
node connect-post-engagers.mjs --type=all

# Limit to the last 30 days of posts
node connect-post-engagers.mjs --type=all --days=30

# Target a specific post
node connect-post-engagers.mjs --post-url=https://www.linkedin.com/feed/update/urn:li:activity:XXXXX
```

### Connect with Profile Viewers
```bash
node connect-profile-viewers.mjs
```

Note: Full viewer list requires LinkedIn Premium.

### Run Everything
```bash
node connect-all.mjs    # All workflows in sequence
```

### Dry Run
```bash
DRY_RUN=1 node connect-all.mjs   # Logs actions without sending requests
```

## Configuration

Edit `config.mjs` to adjust:

- `maxConnectionsPerRun` — limit per execution (default: 20, LinkedIn weekly cap ~100)
- `--days` — only scan posts from the last N days (default: 30)
- `delays.*` — timing between actions (randomized within range)
- `browser.headless` — set `true` for background execution
- `connectionNotes.commenter` — note for post commenters, supports `{firstName}`
- `connectionNotes.liker` — note for post likers, supports `{firstName}`
- `connectionNotes.profileViewer` — note for profile viewers, supports `{firstName}`
- `connectionNotes.default` — fallback note when no source-specific template exists

## Rate Limiting

LinkedIn limits connection requests (~100/week). These scripts include:
- Randomized delays between actions (3-8 seconds between connections)
- Configurable max connections per run
- Human-like browsing patterns

## File Structure

```
linkedin-automation/
  config.mjs                  # Shared configuration and delay helpers
  linkedin-helpers.mjs        # Core Playwright functions (session, connect, scroll)
  save-session.mjs            # One-time session setup
  connect-post-engagers.mjs   # Connect with post commenters/likers
  connect-profile-viewers.mjs # Connect with profile viewers
  connect-all.mjs             # Combined workflow
  package.json
```
