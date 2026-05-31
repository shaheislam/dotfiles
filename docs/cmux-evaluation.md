# cmux Evaluation for Dotfiles Setup

**Date**: 2026-03-12
**Repo**: https://github.com/manaflow-ai/cmux (5.4k stars, Swift, AGPL-3.0)
**What it is**: Native macOS terminal (Swift/AppKit) built on libghostty with vertical sidebar tabs, agent notification system, in-app browser, and full CLI/socket API.

## Verdict: Don't adopt cmux as terminal — extract its patterns instead

Primary stack is **WezTerm + tmux**, not Ghostty. cmux is a Ghostty fork, making it
a poor fit as a terminal replacement. However, three architectural patterns from its
codebase are directly extractable and improve the existing WezTerm + tmux setup.

## What cmux replaces

cmux replaces **both Ghostty and tmux's multiplexing** with a single app. It reads `~/.config/ghostty/config` for themes/fonts/colors, so existing Ghostty customization carries over.

| Current Stack | cmux Equivalent |
|---------------|----------------|
| Ghostty terminal | libghostty rendering engine |
| tmux sessions | cmux workspaces |
| tmux windows | cmux surfaces/tabs |
| tmux panes/splits | cmux panes (split right/down) |
| Tmux agent window colors | Built-in notification rings + sidebar badges |
| tmux-session-manager.sh | Sidebar with git branch, PR status, ports |
| External browser | In-app scriptable browser (from agent-browser) |
| Native tmux status bar | Sidebar metadata: set-status, set-progress, log |

## Key benefits for this setup

### 1. Agent notification system (biggest win)
The current tmux setup color-codes agent windows through Claude hooks and OpenCode status files. It avoids the old polling daemon, but cmux would still provide a richer native notification model:
- **Blue notification rings** on panes when agents need attention
- **Sidebar badges** showing latest notification text per workspace
- **Cmd+Shift+U** to jump to most recent unread
- **`cmux notify`** CLI for Claude Code hooks (OSC 9/99/777 terminal sequences)
- **macOS system notifications** with actual context, not just "Claude is waiting"

### 2. Sidebar metadata per workspace
Current tmux shows git branch in the native status bar (global, not per-window). cmux sidebar shows **per workspace**: git branch, linked PR status/number, working directory, listening ports, and notification text. This directly replaces `gwt-status` for visual awareness.

### 3. Scriptable in-app browser
Agents can snapshot accessibility tree, click elements, fill forms, evaluate JS — all via CLI/socket API. Currently requires switching to an external browser. The `cmux browser` API is ported from Vercel's agent-browser.

### 4. Full CLI/socket API
Everything scriptable: `cmux new-workspace`, `cmux new-split`, `cmux send`, `cmux read-screen`, `cmux notify`, etc. The `gwt-*` Fish functions can be ported to use `cmux` CLI instead of `tmux` commands.

### 5. Native performance
Swift/AppKit, not Electron. GPU-accelerated rendering via libghostty. Lower memory than Ghostty + tmux combined.

## What you lose (and mitigations)

### tmux plugin ecosystem
- **vim-tmux-navigator**: cmux has its own pane navigation (Cmd+h/j/k/l). Need to verify Neovim integration.
- **tmux-thumbs/extrakto**: No equivalent. Rely on Ghostty's built-in URL/text selection or external tools.
- **tmux-fzf/tmux-fuzzback**: Replace with cmux `find-window` CLI + custom fzf wrappers.
- **tmux-1password**: Use 1Password CLI directly or Raycast integration.
- **tmux-yank/copy mode**: cmux inherits Ghostty's clipboard handling. Vi copy mode may differ.

### Remote/SSH session persistence
**This is the dealbreaker for full replacement.** tmux sessions survive terminal crashes and allow detach/reattach over SSH (Mosh + Tailscale setup). cmux does NOT restore live process state — only layout, working directories, and scrollback.

**Mitigation**: Keep tmux installed for remote/SSH work. Use cmux as the local terminal, and when SSH'd into a remote machine, attach to tmux sessions inside cmux panes.

### Custom tmux scripts
All `gwt-*` functions, `tmux-session-manager.sh`, `tmux-worktree-cleanup.sh`, etc. are tmux-native. These need porting to cmux CLI equivalents. This is the main migration effort.

### Session restore limitations
cmux restores layout and metadata but NOT live processes. tmux-resurrect/continuum can restore full sessions. For local-only work with ephemeral agent sessions, this is acceptable.

## Recommended adoption path

### Phase 1: Install and evaluate (low risk)
```bash
brew tap manaflow-ai/cmux && brew install --cask cmux
```
- Run cmux alongside existing Ghostty + tmux setup
- Test notification hooks with Claude Code
- Test `cmux` CLI scripting

### Phase 2: Port agent workflows
- Port `gwt-ticket` to optionally use cmux workspaces instead of tmux windows
- Wire `cmux notify` into Claude Code hooks (`.claude/settings.json`)
- Port `gwt-status` to use `cmux list-workspaces` + sidebar metadata

### Phase 3: Primary local terminal
- Make cmux the default local terminal for multi-agent work
- Keep Ghostty + tmux for remote SSH sessions
- Keep tmux config maintained (it's still valuable for remote work)

## CLI quick reference

```bash
# Workspaces (= tmux sessions/windows)
cmux new-workspace
cmux list-workspaces
cmux select-workspace --id <id>
cmux rename-workspace --id <id> --name "feature-x"

# Splits (= tmux panes)
cmux new-split --direction right
cmux new-split --direction down
cmux focus-pane --id <id>

# Input/Output (= tmux send-keys / capture-pane)
cmux send --text "claude --dangerously-skip-permissions"
cmux send-key --key enter
cmux read-screen --surface <id>

# Notifications (= tmux agent window status replacement)
cmux notify --title "Claude Code" --body "Waiting for input"
cmux list-notifications
cmux clear-notifications

# Sidebar metadata (= no tmux equivalent)
cmux set-status --key git --value "feat/cmux" --icon "branch" --color blue
cmux set-progress --value 0.75 --label "Tests passing"
cmux log --message "Build completed"

# Browser (= no tmux equivalent)
cmux browser open --url "http://localhost:3000"
cmux browser open-split --url "http://localhost:3000" --direction right
```

## Config integration

cmux reads `~/.config/ghostty/config`, so existing font/theme settings (JetBrainsMono Nerd Font, Catppuccin Mocha, background opacity 0.90) will carry over automatically.
