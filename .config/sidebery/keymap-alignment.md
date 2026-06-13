# Keybinding alignment: tmux × Neovim × Aerospace × Ghostty × Sidebery

Audit of the current keymap surface across the tools you actually use, with
recommended Sidebery bindings that minimise context-switching cost.

Treat this as a **proposal doc**, not an auto-applied config. Sidebery
bindings are set in Firefox: about:addons → Sidebery → Settings →
Keybindings. The browser is the easiest surface to bend — tmux, Nvim,
Aerospace, and Ghostty stay sacred (in that priority order).

## Surface map

| Tool | Modifier convention | Notable choices |
|---|---|---|
| **tmux** | `C-s` prefix (single chord) | `prefix v`/`prefix [` copy-mode, `prefix e` opens `nvim .`, `prefix o` URL handler, `prefix s/w` pane/window picker, `prefix C` Claude split, `prefix S` session manager |
| **Neovim (LazyVim)** | `<space>` leader | `C-h/j/k/l` = vim-tmux-navigator (seamless tmux↔vim), `<C-d>` scrolls **up**, `<C-f>` scrolls **down** (deliberate swap), `<Esc><Esc>` exits terminal mode |
| **Aerospace** | `alt-` (Option) | `alt-1..4` workspace profile switching (NOT 1..9) |
| **Ghostty** | `super-` (Cmd) | `super+d`/`super+shift+d` splits, `super+h/j/k/l` split nav, `super+t` new tab, `super+e` opens `nvim .`, `super+w` close surface |
| **Sidebery default** | `Ctrl+` / `Alt+` | `Alt+1..9` panel switch, `Ctrl+T` new tab, `Ctrl+W` close, arrows for tab nav |
| **Fish** | aliases only (no key bindings configured) | `n` = nvim, `k*` = kubectl ecosystem, lots of CLI aliases |

## Cross-tool alignment principles (底层逻辑)

1. **One mental model per modifier.** Each modifier should mean roughly
   one thing across tools:
   - `Cmd / super` = "talk to the host app" (Ghostty splits, OS Cmd+T/W).
   - `Alt / Opt`  = "talk to the OS WM" (Aerospace workspaces).
   - `Ctrl`       = "in-app navigation" (Vim, browser, terminal multiplexer).
   - prefix `C-s` = tmux's own modal layer.
   - `<space>`    = Neovim's modal layer.
   - **No new modifier conventions for Sidebery** — reuse these.

2. **Vim motion `h/j/k/l` is universal.** It's in copy-mode, vim-tmux-navigator,
   Ghostty split nav. Sidebery default uses arrow keys — wasteful. Rebind
   panel-up/panel-down/tab-up/tab-down to `j/k` (within panel) and
   panel-left/right to `h/l`.

3. **Match action verbs to identical keys where the action maps cleanly.**
   - `e` for "edit / editor" (tmux `prefix e`, Ghostty `super+e`) → Sidebery
     `e` = focus URL bar for edit.
   - `t` for new tab (Ghostty `super+t`) → Sidebery already uses `Ctrl+T`.
     Keep.
   - `w` for close (Ghostty `super+w`) → Sidebery already uses `Ctrl+W`.
     Keep.

4. **Avoid conflicts with Firefox built-ins.** Sidebery's keybindings are
   captured by the Sidebery sidebar panel only — Firefox window-level
   shortcuts always win. Don't waste effort on shortcuts that fire only
   when the sidebar is focused unless you actively want sidebar focus.

5. **Aerospace conflict on `Alt+1..4`.** Sidebery default `Alt+1..9` is
   *partially shadowed* — Aerospace eats 1, 2, 3, 4. Symptoms: switching
   to Sidebery panels 1-4 actually triggers Aerospace workspace switches
   first. **Fix: rebind Sidebery panel switching to `Ctrl+Shift+1..9`**
   (also free in Ghostty + Nvim).

## Recommended Sidebery keybindings

Apply these in about:addons → Sidebery → Settings → Keybindings.

| Sidebery action | Recommended chord | Why |
|---|---|---|
| **next_panel** | `Ctrl+Shift+]` | Mirrors common "next tab" intuition, no conflicts. |
| **prev_panel** | `Ctrl+Shift+[` | Symmetric. |
| **switch_to_panel_1..9** | `Ctrl+Shift+1..9` | Avoids Aerospace `Alt+1..4` clash. |
| **new_tab_in_panel** | `Ctrl+T` (default) | Aligns Ghostty `super+t`. Keep default. |
| **close_tab** | `Ctrl+W` (default) | Aligns Ghostty `super+w`. Keep default. |
| **next_tab** | `j` (panel-focused) | Vim down. |
| **prev_tab** | `k` (panel-focused) | Vim up. |
| **next_panel** (panel-focused) | `l` | Vim right. |
| **prev_panel** (panel-focused) | `h` | Vim left. |
| **activate_tab** | `Enter` or `o` | `o` = "open" semantic. |
| **edit_url** (focus URL bar) | `e` | Mirrors tmux/Ghostty `e` = editor. |
| **search_tabs** | `/` | Vim-style search. |
| **pin_tab** | `Ctrl+Shift+P` | Doesn't clash; mnemonic. |
| **duplicate_tab** | `Ctrl+D` | Sidebery default. |
| **reload_tab** | `r` (panel-focused) | Vim/tmux convention. |
| **move_tab_to_panel_N** | `Ctrl+Shift+Alt+1..9` | Mirrors switch-to-panel but with move semantic. |
| **collapse_tree** | `zc` | Vim fold semantic. |
| **expand_tree** | `zo` | Vim fold semantic. |
| **collapse_all** | `zM` | Vim fold semantic. |
| **expand_all** | `zR` | Vim fold semantic. |

## Conflicts deliberately accepted

- **Sidebery `j/k/h/l`** require sidebar focus first (click into sidebar or
  use a keyboard shortcut to focus it). This is a Sidebery limitation —
  the browser captures these keys for find-as-you-type unless sidebar has
  focus. Treat as a "Vim-mode" sub-layer that only applies when you're
  actively navigating tabs.

- **Sidebery `e` for URL edit** conflicts with Firefox find-as-you-type
  `e` letter input when on a page. Sidebery binding only fires when
  sidebar is focused, so this is fine in practice — but won't be a
  global "press e anywhere to edit URL" shortcut.

## What stays untouched

- tmux prefix `C-s` and all its single-key follow-ups — load-bearing.
- Neovim leader = `<space>` and all `<leader>x` mappings — load-bearing.
- The deliberate `C-d`/`C-f` scroll swap in Nvim — non-obvious choice,
  preserved.
- vim-tmux-navigator `C-h/j/k/l` across tmux and Nvim — *the* most
  load-bearing alignment in the stack. Sidebery's `h/j/k/l` proposal
  doesn't conflict because they require sidebar focus.
- Aerospace `alt-1..4` — keep; Sidebery moves around it.
- Ghostty `super+*` — keep.

## Open follow-ups (tracked in `bd dotfiles-plat-345-swq`)

- Consider extending `build-import.py` to emit a Sidebery keybindings
  JSON section once you've validated this proposal via the UI for a
  week. Until validated, manual entry preserves your ability to back out
  any individual binding without re-importing the whole settings blob.
- If you adopt `j/k` for tab nav, audit whether find-as-you-type in
  Firefox needs `accessibility.typeaheadfind.startlinksonly` tweaks.
- A second-pass review of Sidebery's bookmark panel bindings if/when you
  start using bookmark panels (currently no bookmark panel in your
  routing).

## How to apply (~5 min)

1. Open Sidebery → Settings → **Keybindings** tab.
2. For each row in the recommended table, click the existing chord and
   press the new combo. Sidebery flags conflicts inline.
3. Test in this order:
   - `Ctrl+Shift+1..9` → panel switching (confirms Aerospace doesn't eat).
   - Click into sidebar → `j/k/h/l` → tab/panel navigation works.
   - `e` (sidebar focus) → URL bar opens with current URL editable.
   - `Ctrl+Shift+]` / `[` → cycle panels from anywhere in Firefox.
4. If anything feels wrong after a day, reverse it. Bindings are cheap to
   try, expensive to over-engineer up-front.
