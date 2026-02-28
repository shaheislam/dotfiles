# ClaudeCodeBrowser Firefox Extension - Security Assessment

## Summary

**Extension**: [ClaudeCodeBrowser](https://addons.mozilla.org/en-US/firefox/addon/claudecodebrowser/)
**Source**: [nanogenomic/ClaudeCodeBrowser](https://github.com/nanogenomic/ClaudeCodeBrowser) (MIT License)
**Version**: 1.0.0 (last updated 2025-12-16, repo active as of 2026-02-25)
**Firefox Users**: ~64 | **Stars**: 13 | **Reviews**: 0
**Author**: nanogenomic / Ligandal

**Verdict: MODERATE RISK - Safe for local development use with precautions.**

The extension is designed for local-only browser automation via Claude Code's MCP
protocol. It is **not** a data-harvesting or malicious extension. However, its broad
permissions and lack of authentication create a meaningful attack surface if misused
or if localhost is compromised.

---

## What It Does

ClaudeCodeBrowser gives Claude Code the ability to control Firefox - taking
screenshots, clicking elements, typing text, scrolling, navigating, and executing
JavaScript on web pages. It acts as a bridge:

```
Claude Code CLI --> MCP Server (localhost:8765/8766) --> Native Host --> Firefox Extension --> Web Page
```

**Four components**:
1. **Firefox WebExtension** - executes commands in the browser (content.js + background.js)
2. **Native Messaging Host** - Python stdio bridge between extension and MCP server
3. **MCP Server** - HTTP (port 8765) + WebSocket (port 8766) server
4. **Browser Agent** - high-level Python automation wrapper

## Permission Analysis

### Manifest Permissions (manifest.json, Manifest V2)

| Permission | Risk | Purpose |
|-----------|------|---------|
| `activeTab` | Low | Access to currently active tab |
| `tabs` | Medium | List, create, close, navigate tabs |
| `nativeMessaging` | **High** | Bridge to local Python process |
| `storage` | Low | Store extension state |
| `<all_urls>` | **High** | Content script runs on ALL websites |
| `webNavigation` | Medium | Monitor navigation events |
| `contextMenus` | Low | Right-click menu integration |

### Content Script Capabilities

The content script (`content.js`, ~44KB) injects into **every page in every frame** and can:

- **Intercept console output**: Wraps `console.log/warn/error/info/debug`, stores up to 500 entries
- **Intercept network requests**: Hooks `fetch()` and `XMLHttpRequest` to capture URLs, methods, headers, request bodies, and response bodies (up to 5000 chars)
- **Access full DOM**: Read any element, form data, input values
- **Simulate user input**: Click, type, scroll, submit forms via synthetic events
- **Select elements**: By CSS selector, XPath, text content, coordinates, or ARIA attributes

### Native Host Capabilities

The native host (`claudecodebrowser_host.py`, ~19KB) runs as a **local Python process** and can:

- Write screenshots to `/tmp/claudecodebrowser/screenshots/`
- Create log files at `~/.claudecodebrowser/logs/`
- Launch and kill the MCP server process
- Use `lsof`/`fuser` to find and kill processes on ports

### MCP Server Capabilities

The MCP server (`server.py`, ~41KB) exposes **~40+ tools** via HTTP/WebSocket:

- `browser_navigate` - Navigate to any URL
- `browser_click` / `browser_type` - Interact with any element
- `browser_screenshot` - Capture page screenshots
- `browser_execute_script` - **Execute arbitrary JavaScript in browser context**
- `browser_get_console_logs` / `browser_get_network_logs` - Exfiltrate logged data
- `browser_get_page_info` / `browser_get_elements` - Read page content
- Tab management (create, close, focus, reload)

## Security Concerns

### Critical Issues

1. **No authentication on MCP server**: The HTTP/WebSocket server on localhost accepts
   commands from ANY local process. No API keys, tokens, or credential validation.
   Any malware running locally could control your browser.

2. **Arbitrary JavaScript execution**: The `browser_execute_script` tool allows running
   any JavaScript in the browser context. Combined with no auth, this is effectively
   local RCE through the browser.

3. **Network/console interception**: The content script hooks `fetch()` and `XHR` on
   every page, capturing request/response bodies. This could expose auth tokens,
   API keys, and sensitive data in transit.

### Moderate Issues

4. **`<all_urls>` + all frames**: Content script runs everywhere including banking
   sites, email, password managers - anything you visit in Firefox.

5. **No origin validation on external messages**: `browser.runtime.onMessageExternal`
   accepts commands without checking the sender.

6. **World-writable screenshot storage**: Default `/tmp/` directory is accessible to
   all local users.

7. **Manifest V2**: Uses the older manifest format. Firefox hasn't fully deprecated
   MV2 (unlike Chrome), but MV3 offers better permission isolation.

8. **Environment variable path injection**: `CLAUDE_MCP_HOST`, `CLAUDE_MCP_PORT`,
   `CLAUDE_BROWSER_SCREENSHOTS_DIR` can redirect traffic or storage.

### Mitigating Factors

- **Localhost-only**: MCP server binds to `127.0.0.1` - not exposed to network
- **Open source**: Full source code available for audit (MIT license)
- **No telemetry**: No evidence of data collection or phone-home behavior
- **Firefox Add-ons review**: Listed on AMO (Mozilla's add-on store), which has a review process
- **Intentional design**: These are features, not bugs - the extension is meant to give
  Claude Code browser control for development automation
- **Active development**: Repository updated recently (2026-02-25), 13 stars

## Comparison: Official vs Third-Party

| Aspect | Claude in Chrome (Official) | ClaudeCodeBrowser (Third-Party) |
|--------|---------------------------|--------------------------------|
| Publisher | Anthropic | nanogenomic / Ligandal |
| Browser | Chrome only | Firefox only |
| Auth | Anthropic account required | None (localhost) |
| Permissions | Site-level user control | All sites, all frames |
| Action confirmation | High-risk action prompts | No confirmation |
| Prompt injection defense | Opus 4.5 hardening (~1% success) | No defense layer |
| MV version | Manifest V3 | Manifest V2 |
| Code review | Anthropic internal | Open source (community) |
| User base | 1000+ (controlled rollout) | ~64 |

**Key difference**: The official Claude in Chrome extension operates through Anthropic's
infrastructure with authentication, permission controls, and prompt injection defenses.
ClaudeCodeBrowser is a community tool that trusts the local environment entirely.

## Recommendations

### If You Decide to Use It

1. **Use a separate Firefox profile** for Claude Code browser automation:
   ```bash
   firefox -P "claude-automation" --no-remote
   ```
   Keep your primary browsing (banking, email, passwords) in a different profile.

2. **Only enable when needed**: Disable the extension when not actively using
   Claude Code browser automation. Don't leave it running during general browsing.

3. **Audit the source code** yourself - it's only ~130KB of JavaScript + Python:
   - `extension/background.js` (26KB)
   - `extension/content.js` (44KB)
   - `mcp-server/server.py` (41KB)
   - `native-host/claudecodebrowser_host.py` (19KB)

4. **Pin to a specific commit**: Don't auto-update. Review changes before updating.

5. **Monitor the MCP server port**: Ensure only Claude Code connects to `localhost:8765`.

6. **Don't use on sensitive sites**: The content script's network interception
   captures auth tokens and API keys from every page you visit.

### If You Want Maximum Safety

1. **Don't install it** - use Playwright MCP server instead (already configured in
   your dotfiles via the `--play` flag). Playwright provides similar browser
   automation without requiring a browser extension.

2. **Use the official Claude in Chrome** when it becomes available for your use case,
   or wait for an official Firefox extension from Anthropic.

## Alternative: Playwright MCP (Already Available)

Your dotfiles already have Playwright MCP configured, which provides similar
browser automation capabilities:

- Screenshot capture
- Element clicking and typing
- Page navigation
- JavaScript evaluation
- Tab management
- No browser extension required (uses Playwright's browser automation)

The Playwright MCP is:
- Maintained by Microsoft (Playwright) with Anthropic integration
- Doesn't require installing any browser extension
- Runs in an isolated browser context (not your primary browser)
- Already wired into your Claude Code setup

**To use**: Invoke with `--play` flag or use the `mcp__playwright__*` tools directly.

## Conclusion

ClaudeCodeBrowser fills a real gap - Firefox users don't have an official Anthropic
browser extension. The extension is **not malicious** and the code is transparent.
However, its broad permissions and lack of authentication mean you should treat it
as a development tool, not something to leave enabled during daily browsing.

**For your use case** (Firefox as primary browser), the safest approach is:
1. Use Playwright MCP for browser automation needs (already configured)
2. If you need Firefox-specific automation, use ClaudeCodeBrowser in an
   **isolated Firefox profile** only during active development sessions
3. Monitor for an official Anthropic Firefox extension

---

*Assessment date: 2026-02-28*
*Source code reviewed: nanogenomic/ClaudeCodeBrowser @ main (2026-02-25)*
