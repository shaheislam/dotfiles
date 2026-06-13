# Sidebery keybindings — apply checklist

Generated from `keymap.yaml`. Sidebery's UI is the canonical
application surface; this checklist matches what to enter where.

## Global (browser-wide)

Set via: `about:addons` → ⚙ (top-right gear) → **Manage Extension Shortcuts**.

| Action | Chord | Note |
|---|---|---|
| `activate_panel_1` | `Ctrl+Shift+1` | Avoids Aerospace alt-1..4 shadow. |
| `activate_panel_2` | `Ctrl+Shift+2` |  |
| `activate_panel_3` | `Ctrl+Shift+3` |  |
| `activate_panel_4` | `Ctrl+Shift+4` |  |
| `next_panel` | `Ctrl+Shift+]` | Browser-wide cycle, like next-tab muscle memory. |
| `prev_panel` | `Ctrl+Shift+[` |  |

## Panel-scoped (sidebar focus required)

Set via: Sidebery → **Settings** → **Keybindings** tab.

| Action | Chord | Note |
|---|---|---|
| `next_tab` | `j` |  |
| `prev_tab` | `k` |  |
| `next_panel` | `l` | Sidebar-focused panel cycle. Global Ctrl+Shift+] still works. |
| `prev_panel` | `h` |  |
| `activate_tab` | `Enter` |  |
| `edit_url` | `e` | Mirrors tmux `prefix e` + Ghostty `super+e` (= editor surface). |
| `search_tabs` | `/` |  |
| `reload_tab` | `r` |  |
| `duplicate_tab` | `Ctrl+D` |  |
| `pin_tab` | `Ctrl+Shift+P` |  |
| `close_tab` | `Ctrl+W` | Sidebery default; aligned with Ghostty super+w. |
| `new_tab_in_panel` | `Ctrl+T` | Sidebery default; aligned with Ghostty super+t. |
| `collapse_tabs` | `zc` |  |
| `expand_tabs` | `zo` |  |
| `collapse_all_tabs` | `zM` |  |
| `expand_all_tabs` | `zR` |  |
