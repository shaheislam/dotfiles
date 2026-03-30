# opencode.nvim vs tmux Side Pane

OpenCode already lives in our tmux workflow: prefix + `Ctrl-s` + `O` opens the TUI in a dedicated pane where we manually copy/paste context. The [`opencode.nvim`](https://github.com/nickjvandyke/opencode.nvim) plugin keeps the same backend assistant but embeds it directly in Neovim, which buys us tighter editor awareness, faster iteration, and better review UX.

## Why the plugin is a material upgrade

- **Zero-copy context** – prompts can reference placeholders such as `@this`, `@buffer`, `@diagnostics`, `@diff`, or `@visible`. The plugin resolves those against your current buffer/selection before sending them to OpenCode, so you stop yanking snippets into the side pane.
- **Prompt + operator ergonomics** – `require("opencode").ask`, `select`, and the operator wrapper let you reuse visual selections, ranges, and dot-repeat. Side panes are strictly linear terminals with no operator integration.
- **Editor-driven review loop** – when OpenCode proposes edits, the plugin opens a tab with `:diffpatch`, lets you accept/reject per hunk (`dp`, `do`, `]c`, `[c`), and reloads buffers on approval. The side pane requires manual patch application or copy/paste.
- **Permission + event awareness** – server-sent events surface inside Neovim via the `OpencodeEvent` autocmd, so you can hook custom automation (notifications, statusline, etc.). The pane view only shows whatever the TUI prints.
- **Experimental LSP bridge** – enabling `vim.g.opencode_opts.lsp.enabled` turns hover/code-action requests into OpenCode prompts. There is no equivalent API from the tmux pane.
- **Session UX** – the plugin auto-starts/stops OpenCode servers, exposes commands (`session.select`, `session.interrupt`, etc.) through pickers, and includes optional Snacks integrations. Launching a pane simply spawns `opencode` and leaves lifecycle management to you.

## What stays the same

- The backend assistant is still OpenCode, so authentication, model routing, hooks, and all `.opencode/` scripts remain unchanged.
- You can connect the plugin to any running OpenCode instance via the `server.port` option, which means the tmux binding can keep a long-lived side pane if you want a dedicated transcript while Neovim handles buffer-aware asks.
- Permissions and hooks still flow through the existing `.opencode/plugins/claude-compat.ts` stack—`opencode.nvim` just surfaces them in-editor.

## Comparison snapshot

| Capability | tmux side pane | `opencode.nvim` |
|------------|----------------|-----------------|
| Context capture | Manual copy/paste | Automatic via placeholders (`@this`, `@buffer`, `@diagnostics`, `@diff`, etc.) |
| Prompt ergonomics | TUI input only | Lua API + Snacks picker/input + operator support + dot-repeat |
| Edit review | Copy/paste or apply patch manually | Built-in diff tab with accept/reject bindings (`da`, `dr`, `dp`, `do`) |
| Permission handling | Raw JSON/log output | Inline prompts after idle + autocmd hooks |
| Session control | `opencode` CLI shortcuts | `require("opencode").command("session.*")` + configurable keymaps |
| LSP integration | None | Optional hover/code-action bridge |
| Statusline signal | Pane title only | `require("opencode").statusline` component |

## Adoption guidance

1. Install the plugin via LazyVim (see upstream README snippet) and set `vim.g.opencode_opts.server.port` to match the port our scripts already use (or let it spawn its own terminal).
2. Keep `vim.o.autoread = true` so edits from OpenCode reload correctly.
3. Reuse the recommended keymaps (`<C-a>` ask, `<C-x>` select, `go` operator) or map them under `<leader>o` to avoid conflicts with tmux bindings.
4. Run `:checkhealth opencode` after wiring it up; the check validates that OpenCode is discoverable and events are flowing.
5. Continue to use the tmux pane when you need a dedicated transcript view or when Neovim is not open—both entry points can coexist because they talk to the same OpenCode backend.

By moving repetitive prompt + context work into Neovim we remove most of the friction highlighted in this ticket while leaving the tmux bindings available for workflows outside the editor.
