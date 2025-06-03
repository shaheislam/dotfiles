-- WezTerm Key Bindings Configuration
-- Organized key mappings with leader key support

local wezterm = require('wezterm')
local act = wezterm.action

local M = {}

-- Leader key configuration
M.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

-- Key mappings
M.keys = {
  -- Leader key mappings
  {
    key = 'Space',
    mods = 'LEADER|CTRL',
    action = act.SendKey { key = 'Space', mods = 'CTRL' },
  },

  -- Pane splitting
  {
    key = '|',
    mods = 'LEADER|SHIFT',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = '\\',
    mods = 'LEADER',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },

  -- Pane navigation (vim-like)
  {
    key = 'h',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Right',
  },

  -- Pane resizing
  {
    key = 'H',
    mods = 'LEADER|SHIFT',
    action = act.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'J',
    mods = 'LEADER|SHIFT',
    action = act.AdjustPaneSize { 'Down', 5 },
  },
  {
    key = 'K',
    mods = 'LEADER|SHIFT',
    action = act.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'L',
    mods = 'LEADER|SHIFT',
    action = act.AdjustPaneSize { 'Right', 5 },
  },

  -- Pane management
  {
    key = 'z',
    mods = 'LEADER',
    action = act.TogglePaneZoomState,
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = act.CloseCurrentPane { confirm = true },
  },

  -- Tab management
  {
    key = 'c',
    mods = 'LEADER',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'n',
    mods = 'LEADER',
    action = act.ActivateTabRelative(1),
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = act.ActivateTabRelative(-1),
  },
  {
    key = '&',
    mods = 'LEADER|SHIFT',
    action = act.CloseCurrentTab { confirm = true },
  },

  -- Tab switching (numbers)
  {
    key = '1',
    mods = 'LEADER',
    action = act.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'LEADER',
    action = act.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'LEADER',
    action = act.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'LEADER',
    action = act.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'LEADER',
    action = act.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'LEADER',
    action = act.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'LEADER',
    action = act.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'LEADER',
    action = act.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'LEADER',
    action = act.ActivateTab(8),
  },

  -- Copy mode and search
  {
    key = '[',
    mods = 'LEADER',
    action = act.ActivateCopyMode,
  },
  {
    key = '/',
    mods = 'LEADER',
    action = act.Search { CaseSensitiveString = '' },
  },

  -- Workspaces
  {
    key = 'w',
    mods = 'LEADER',
    action = act.ShowLauncherArgs {
      flags = 'FUZZY|WORKSPACES',
    },
  },

  -- Command palette
  {
    key = 'P',
    mods = 'LEADER|SHIFT',
    action = act.ActivateCommandPalette,
  },

  -- Reload configuration
  {
    key = 'r',
    mods = 'LEADER',
    action = act.ReloadConfiguration,
  },

  -- Standard Mac/CMD shortcuts
  {
    key = 'c',
    mods = 'CMD',
    action = act.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CMD',
    action = act.PasteFrom 'Clipboard',
  },
  {
    key = 't',
    mods = 'CMD',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'w',
    mods = 'CMD',
    action = act.CloseCurrentTab { confirm = true },
  },
  {
    key = 'n',
    mods = 'CMD',
    action = act.SpawnWindow,
  },

  -- Font size
  {
    key = '=',
    mods = 'CMD',
    action = act.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CMD',
    action = act.DecreaseFontSize,
  },
  {
    key = '0',
    mods = 'CMD',
    action = act.ResetFontSize,
  },

  -- Tab navigation with CMD
  {
    key = '1',
    mods = 'CMD',
    action = act.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'CMD',
    action = act.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'CMD',
    action = act.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'CMD',
    action = act.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'CMD',
    action = act.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'CMD',
    action = act.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'CMD',
    action = act.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'CMD',
    action = act.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'CMD',
    action = act.ActivateTab(8),
  },

  -- Quick search
  {
    key = 'f',
    mods = 'CMD',
    action = act.Search { CaseSensitiveString = '' },
  },

  -- Toggle fullscreen
  {
    key = 'Enter',
    mods = 'CMD|CTRL',
    action = act.ToggleFullScreen,
  },

  -- Show launcher
  {
    key = 'Space',
    mods = 'CMD',
    action = act.ShowLauncher,
  },
}

-- Mouse bindings
M.mouse_bindings = {
  -- Right click to paste
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },

  -- CMD+click to open links
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.OpenLinkAtMouseCursor,
  },

  -- Middle click to paste
  {
    event = { Down = { streak = 1, button = 'Middle' } },
    mods = 'NONE',
    action = act.PasteFrom 'PrimarySelection',
  },
}

return M
