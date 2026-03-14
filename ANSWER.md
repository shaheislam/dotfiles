# TASK: cmuxbrowser — How cmux Uses Agent Browser from the Terminal

## Question
How is cmux using agent-browser from within the terminal? Is there anything else we might be missing?

## Answer

### How cmux Does It

cmux embeds a **WKWebView** (native macOS WebKit browser) directly as a terminal pane. The browser API is a **port of vercel-labs/agent-browser** adapted for WKWebView instead of Playwright/Chromium.

**Architecture:**
```
cmux process (Swift/AppKit)
    ├── Terminal panes (libghostty rendering)
    └── Browser panes (WKWebView)
         └── Scriptable API via Unix socket (/tmp/cmux.sock)
              ├── CLI: cmux browser <command> [args]
              └── Socket: JSON-RPC {"method": "browser.snapshot", "params": {...}}
```

**Key design choices:**
1. **No extension, no MCP, no network ports** — browser control goes through the same Unix socket as all other cmux commands
2. **Socket auth** — only processes spawned within cmux terminals can connect (default mode), eliminating the CORS/no-auth attack surface
3. **CLI-first** — every browser action is a `cmux browser` subcommand that AI agents call directly via Bash
4. **Claude Code hooks** — `cmux claude-hook session-start|stop|notification` wires into Claude Code lifecycle, replacing tmux watcher polling
5. **Notification rings** — blue rings on panes + sidebar badges when agents need attention, replacing fragile output-parsing

**Full command surface (ported from agent-browser):**
- Navigation: `goto`, `back`, `forward`, `reload`
- DOM interaction: `click`, `dblclick`, `hover`, `focus`, `check`, `uncheck`, `type`, `fill`, `press`, `select`, `scroll`
- Inspection: `snapshot` (accessibility tree with element refs), `screenshot`, `get` (url/title/text/html/value/attr), `is` (visible/enabled/checked), `find` (by role/text/label/testid)
- JS execution: `eval`
- State management: `cookies`, `storage`, `state save|load`, `addinitscript`, `addstyle`, `viewport`
- Waiting: `wait` (selector/text/url/load-state/function)
- Tab/dialog management: `tab`, `dialog`, `frame`

### What We Have (Current Dotfiles)

Three separate browser automation approaches:

| Tool | Transport | Browser | Use Case |
|------|-----------|---------|----------|
| **Playwright MCP** | MCP stdio (bunx) | Isolated Chromium | General automation, testing |
| **agent-browser CLI** | Bash CLI (v0.17.1) | Persistent Chromium daemon | AI-optimized ref-based interaction |
| **ClaudeCodeBrowser** | MCP stdio (Python) | Real Firefox session | Firefox-specific automation |

### What We're Missing

#### 1. MCP Parity Gap (Bug — Fixed)
`.mcp.json` was missing `claudecodebrowser` that Claude Desktop config had. This violates the CLAUDE.md parity rule. **Fixed in this branch.**

#### 2. No Unified Browser Strategy
cmux has one browser API for everything. We have three tools with different interfaces:
- Playwright MCP uses `mcp__playwright__browser_*` tools
- agent-browser uses Bash CLI with `@ref` selectors
- ClaudeCodeBrowser uses `mcp__claudecodebrowser__browser_*` tools

**Impact:** AI agents must know which tool to use when. The agent-browser skill helps, but there's no decision logic for when to prefer one over another.

**Recommendation:** The agent-browser skill already documents the decision matrix (see `.claude/skills/agent-browser/SKILL.md` line 196-203). This is sufficient — we don't need to unify the tools, just ensure the skill is discoverable.

#### 3. agent-browser Not Exposed as MCP
agent-browser (v0.17.1) is CLI-only. cmux proves the CLI model works fine for AI agents — they call `cmux browser` via Bash. Our agent-browser skill already does exactly this (`allowed-tools: Bash(agent-browser:*)`).

**Decision:** CLI-only is the correct pattern for agent-browser. Adding an MCP wrapper would duplicate Playwright MCP's function without benefit. The Bash skill approach matches cmux's design.

#### 4. No Native Browser Pane (Limitation, Not a Gap)
cmux's killer feature is the browser-as-a-pane: `cmux browser open-split --url http://localhost:3000 --direction right` puts a browser next to your terminal. We can't replicate this in WezTerm/tmux — it requires a native app embedding WKWebView.

**Mitigation:** This is already covered in `docs/cmux-evaluation.md`. The evaluation correctly concluded: "extract patterns, don't adopt cmux as terminal."

#### 5. No Agent Notification Hooks for cmux
The Brewfile has `cask "cmux"` and `tap "manaflow-ai/cmux"`, but there's no Claude Code hook wiring for `cmux claude-hook` commands. If someone runs Claude Code inside cmux, they won't get notification rings.

**Recommendation:** Add conditional Claude Code hooks that detect cmux and wire notifications. Low priority since cmux is "evaluate, don't adopt" per the evaluation doc.

#### 6. Playwright MCP Flag Inconsistency
`.mcp.json` uses `["@playwright/mcp@latest"]` but Claude Desktop uses `["-y", "@playwright/mcp@latest"]`. The `-y` flag auto-confirms the bunx install prompt. Without it, first-run may hang waiting for confirmation.

**Fixed in this branch.**

### Summary

cmux's approach is architecturally cleaner (one socket, one API, zero network surface) but tied to a specific terminal app. Our multi-tool approach is more flexible and works across any terminal. The main actionable gaps were:
1. MCP config parity (fixed)
2. Playwright `-y` flag inconsistency (fixed)

Everything else is either already handled (agent-browser skill, cmux evaluation doc) or not applicable (native browser panes require cmux adoption).
