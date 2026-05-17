# opencode.nvim vs tmux Side Pane

OpenCode already lives in our tmux workflow: prefix + `Ctrl-s` + `O` opens the TUI in a dedicated pane. The terminal binary is `ocv` from [`leohenon/opencode-vim`](https://github.com/leohenon/opencode-vim), exposed through the repo-managed `scripts/bin/opencode` shim so existing launchers keep working while the TUI gains Vim motions, copy mode, and clipboard-register support. The [`opencode.nvim`](https://github.com/nickjvandyke/opencode.nvim) plugin is the complementary Neovim integration layer: it keeps the same backend assistant but embeds editor context directly in Neovim, which buys us tighter editor awareness, faster iteration, and better review UX.

## Why the plugin is a material upgrade

- **Zero-copy context** – prompts can reference placeholders such as `@this`, `@buffer`, `@diagnostics`, `@diff`, or `@visible`. The plugin resolves those against your current buffer/selection before sending them to OpenCode, so you stop yanking snippets into the side pane.
- **Prompt + operator ergonomics** – `require("opencode").ask`, `select`, and the operator wrapper let you reuse visual selections, ranges, and dot-repeat. Side panes are strictly linear terminals with no operator integration.
- **Editor-driven review loop** – when OpenCode proposes edits, the plugin opens a tab with `:diffpatch`, lets you accept/reject per hunk (`dp`, `do`, `]c`, `[c`), and reloads buffers on approval. The side pane requires manual patch application or copy/paste.
- **Permission + event awareness** – server-sent events surface inside Neovim via the `OpencodeEvent` autocmd, so you can hook custom automation (notifications, statusline, etc.). The pane view only shows whatever the TUI prints.
- **Experimental LSP bridge** – enabling `vim.g.opencode_opts.lsp.enabled` turns hover/code-action requests into OpenCode prompts. There is no equivalent API from the tmux pane.
- **Session UX** – the plugin auto-starts/stops OpenCode servers, exposes commands (`session.select`, `session.interrupt`, etc.) through pickers, and includes optional Snacks integrations. Launching a pane simply spawns `opencode` and leaves lifecycle management to you.

## What stays the same

- The backend assistant is still OpenCode-compatible (`opencode` resolves to `ocv`), so authentication, model routing, hooks, and all `.opencode/` scripts remain unchanged.
- You can connect the plugin to any running OpenCode instance via the `server.port` option, which means the tmux binding can keep a long-lived side pane if you want a dedicated transcript while Neovim handles buffer-aware asks.
- Permissions and hooks still flow through the existing `.config/opencode/plugin/claude-compat.ts` stack—`opencode.nvim` just surfaces them in-editor.

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

## opencode-vim and opencode.nvim together

- `ocv` replaces the terminal TUI and provides full Vim-mode ergonomics when OpenCode runs in tmux or a standalone shell.
- `scripts/bin/opencode` preserves the command name expected by `gwt-ticket`, tmux launchers, cross-provider hooks, and `opencode.nvim`.
- `opencode.nvim` keeps using `opencode --port`; the shim routes that to `ocv --port`, so editor-native prompts inherit the same binary and plugin stack.
- `.config/opencode/tui.json` stays close to the documented OpenCode schema: it uses the local `transparent` theme to avoid panel background fill, disables mouse capture, and only overrides a few navigation shortcuts.
- Use `Ctrl-x y` to copy the selected/current message from OpenCode. For arbitrary transcript text, use tmux copy mode: `Ctrl-s [` or `Ctrl-s v`, select with `v`, then yank with `y` or `Enter`.

By moving repetitive prompt + context work into Neovim we remove most of the friction highlighted in this ticket while leaving the tmux bindings available for workflows outside the editor.

## OpenCode-only Neovim workflow

`opencode.nvim` is now the primary in-editor AI layer. It owns buffer-aware prompts, visual selections, operator workflows, and the diff review loop. The tmux side pane remains useful for long transcripts and non-editor sessions; no secondary editor-assistant plugin is part of the active workflow.

### Reference Lua snippet

```lua
-- lazy.nvim spec excerpt (~/neovim/lua/plugins/opencode.lua)
return {
  "nickjvandyke/opencode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = function()
    vim.g.opencode_opts = {
      server = {
        port = tonumber(vim.env.OPENCODE_PORT or 3333),
      },
      prompts = {
        diagnostics = { name = "diagnostics", prompt = "Explain @diagnostics" },
        refactor = { name = "refactor", prompt = "Refactor @this for readability" },
      },
    }
    vim.keymap.set({ "n", "x" }, "<C-a>", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask OpenCode" })
    vim.api.nvim_create_autocmd("User", {
      pattern = "OpencodeEvent:*",
      callback = function(args)
        require("opencode.status").update(args.data.event)
      end,
    })
  end,
}
```

With this setup you can define explicit workflows:

- **Diagnostics review** – `:lua require("opencode").ask("Explain @diagnostics and propose the smallest fix", { submit = true })`.
- **Refactor selection** – visual select code, hit `go` to enqueue via the operator, then accept/reject hunks in the diff tab.
- **Diff review** – `:lua require("opencode").ask("Review @diff for correctness, regressions, and missing tests", { submit = true })`.

## SSE logging + Entire checkpoints

- `.config/opencode/plugin/sse-recorder.ts` listens to every OpenCode SSE event, writes a JSONL audit log under `.entire/opencode/sse/events.jsonl`, and mirrors summary payloads into `entire hooks opencode sse-event` so checkpoints capture turn-by-turn metadata.
- Whenever an event contains a diff/patch payload, the plugin stores a timestamped snapshot inside `.entire/opencode/sse/diffs/` and emits a secondary `sse-diff` hook with the file path.
- The harness `scripts/opencode/test-sse-recorder.ts` exercises the plugin in isolation to guarantee log + diff files are produced.
- Use `scripts/opencode/diffview-latest.sh --cat` (or `--meta`) to inspect the newest AI patch. Diffview can read those patch files through its existing tmux/Zsh discovery hooks, so you can replay AI-generated edits even after closing the OpenCode TUI.

## Diffview integration pointers

1. Keep `.config/fish/conf.d/diffview-follow.fish` enabled so every `cd` notifies Neovim’s Diffview window about repo changes.
2. When the SSE recorder drops a new patch, run `scripts/opencode/diffview-latest.sh` to get the file path, then inside Neovim run `:DiffviewFileHistory <patch>` or open it in a scratch buffer for review.
3. Because the recorder stores metadata (`*.patch.json`), you can show the originating session/message in statuslines or in Entire checkpoints.

## Automated validation

`scripts/test-filter.sh opencode` now covers the new surfaces:

- `scripts/opencode/test-sse-recorder.ts` (Bun harness) ensures the recorder plugin logs events/diffs.
- `scripts/opencode/test-nvim-health.sh` runs `nvim --headless` → `luafile` (module probes for `opencode` and `wrapped`) → `:checkhealth opencode` so CI flags missing OpenCode editor integration immediately. Set `OPENCODE_NVIM_APPNAME` if you use a non-default Neovim profile.
- `scripts/opencode/diffview-latest.sh` gives tooling + tests a stable entry point for the most recent diff snapshot.

Together these cover the “hybrid UI + SSE logging + Diffview replay” workflow discussed in the ticket.

## Wrapped.nvim dashboard

- `aikhe/wrapped.nvim` is installed (Lazy spec in `~/neovim/lua/plugins/wrapped.lua`) with `nvzone/volt` so you can launch a dashboard of repo activity via `:WrappedNvim` or the shortcut `<leader>aw`.
- The dashboard pulls git stats from `vim.fn.stdpath("config")` (override with `NVIM_WRAPPED_PATH`) and renders commit heatmaps, plugin growth charts, and large-file summaries. Size/border are tuned for tmux panes via rounded border + 75% of current editor dimensions.
- Use `<` / `>` to cycle years, `r` to refresh after new commits, and `q` to close. Because data collection is async, a loading screen appears until git/file/plugin tasks finish.
- Pairing this dashboard with the SSE recorder means Entire checkpoints capture both AI session history and evolving Neovim configuration history (for example, referencing the most active month when reviewing opencode usage).
