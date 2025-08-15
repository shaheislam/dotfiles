# BrowserTools MCP Setup Guide

## Overview
BrowserTools MCP enables Claude to interact with your browser for taking screenshots, auditing pages, and debugging web applications. It requires both a Chrome extension and a bridge server to function.

## Architecture
```
Claude MCP Server ←→ BrowserTools Server ←→ Chrome Extension ←→ Browser
```

1. **MCP Server** (`@agentdeskai/browser-tools-mcp`): Communicates with Claude
2. **Bridge Server** (`@agentdeskai/browser-tools-server`): WebSocket bridge
3. **Chrome Extension**: Captures browser data and screenshots

## Installation Steps

### 1. Automatic Setup (via setup script)
The setup script automatically:
- Downloads the Chrome extension to this directory
- Extracts it to `chrome-extension/`
- Installs required npm packages

### 2. Manual Chrome Extension Installation
1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top-right)
3. Click "Load unpacked"
4. Select: `~/dotfiles/.config/browser-tools/chrome-extension`
5. Verify the "BrowserToolsMCP" extension is installed and enabled

### 3. Start the Bridge Server
```bash
npx @agentdeskai/browser-tools-server@latest
```

The server runs on `ws://localhost:8080` by default.

## Usage

### Available MCP Tools
- `takeScreenshot`: Capture page or element screenshots
- `getConsoleLogs`: View browser console logs
- `getConsoleErrors`: View console errors
- `getNetworkLogs`: Monitor network requests
- `runAccessibilityAudit`: Check page accessibility
- `runPerformanceAudit`: Analyze page performance
- `runSEOAudit`: SEO analysis

### Example Commands
```
Take a screenshot of the current page
Run an accessibility audit on this page
Check console errors
```

## Troubleshooting

### "fetch failed" Errors
**Cause**: Bridge server not running or Chrome extension not installed

**Solutions**:
1. Verify Chrome extension is installed at `chrome://extensions/`
2. Start bridge server: `npx @agentdeskai/browser-tools-server@latest`
3. Check server is running on `ws://localhost:8080`

### JSON Parsing Errors
**Cause**: Server outputting non-JSON messages (fixed in v1.1.0+)

**Solution**: Configuration in Claude Desktop uses v1.1.0 with error suppression:
```json
"browser-tools": {
  "command": "npx",
  "args": ["-y", "@agentdeskai/browser-tools-mcp@1.1.0"],
  "env": {
    "NODE_OPTIONS": "--no-warnings"
  }
}
```

### Extension Not Connecting
1. Check Chrome DevTools for WebSocket connection errors
2. Verify no firewall blocking localhost:8080
3. Restart both bridge server and Chrome

## File Structure
```
.config/browser-tools/
├── README.md                    # This documentation
├── BrowserTools-extension.zip   # Downloaded extension package
└── chrome-extension/            # Extracted extension files
    ├── manifest.json
    ├── background.js
    ├── devtools.js
    ├── devtools.html
    ├── panel.js
    └── panel.html
```

## Configuration Files

### Claude Desktop Config
Location: `~/Library/Application Support/Claude/claude_desktop_config.json`
```json
"browser-tools": {
  "command": "npx",
  "args": ["-y", "@agentdeskai/browser-tools-mcp@1.1.0"],
  "env": {
    "NODE_OPTIONS": "--no-warnings"
  }
}
```

### Claude Code Config
Added via: `claude mcp add --scope user browser-tools npx @agentdeskai/browser-tools-mcp@1.2.0`

## Version Notes
- **v1.1.0**: Stable version with error suppression (used in Claude Desktop)
- **v1.2.0**: Latest version (used in Claude Code and setup script)
- **Chrome Extension**: v1.2.0 (downloaded from GitHub releases)

## Differences from Playwright MCP
- **BrowserTools**: Real-time browser debugging, audits, screenshots of active tabs
- **Playwright**: Automated browser testing, scripted interactions, headless automation
- **Use BrowserTools for**: Debugging live websites, taking screenshots, auditing performance
- **Use Playwright for**: Automated testing, form filling, scripted browser actions

## Restart Requirements
After changes:
1. **Claude Desktop**: Restart application to reload MCP config
2. **Claude Code**: No restart needed (dynamic MCP loading)
3. **Bridge Server**: Restart if configuration changes
4. **Chrome Extension**: Reload extension if files change

## Support
- GitHub: https://github.com/AgentDeskAI/browser-tools-mcp
- Issues: https://github.com/AgentDeskAI/browser-tools-mcp/issues
