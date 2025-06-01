-- WezTerm Configuration
-- https://wezfurlong.org/wezterm/config/files.html

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Color Scheme - Tokyo Night
config.color_scheme = 'Tokyo Night'

-- Font Configuration
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrainsMono NerdFont',
  'Hack Nerd Font',
  'MesloLGS Nerd Font',
  'SF Mono',
  'Menlo',
}
config.font_size = 14.0
config.line_height = 1.2

-- Window Configuration
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.window_close_confirmation = 'AlwaysPrompt'

-- Window Frame
config.window_frame = {
  font = wezterm.font({ family = 'JetBrainsMono Nerd Font', weight = 'Bold' }),
  font_size = 12.0,
  active_titlebar_bg = '#1a1b26',
  inactive_titlebar_bg = '#16161e',
}

-- Tab Configuration
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.show_tab_index_in_tab_bar = false

-- Tab Colors
config.colors = {
  tab_bar = {
    background = '#1a1b26',
    active_tab = {
      bg_color = '#7aa2f7',
      fg_color = '#1a1b26',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#414868',
      fg_color = '#c0caf5',
    },
    inactive_tab_hover = {
      bg_color = '#565f89',
      fg_color = '#c0caf5',
    },
    new_tab = {
      bg_color = '#1a1b26',
      fg_color = '#c0caf5',
    },
    new_tab_hover = {
      bg_color = '#414868',
      fg_color = '#c0caf5',
    },
  },
}

-- Cursor Configuration
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500

-- Scrollback
config.scrollback_lines = 10000

-- Performance
config.max_fps = 120
config.animation_fps = 60

-- Key Bindings
config.keys = {
  -- Pane splitting
  {
    key = '|',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '_',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },

  -- Pane navigation
  {
    key = 'LeftArrow',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },

  -- Pane resizing
  {
    key = 'LeftArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'RightArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 'UpArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'DownArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },

  -- Tab management
  {
    key = 't',
    mods = 'CMD',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'w',
    mods = 'CMD',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },

  -- Quick tab switching
  {
    key = '1',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(8),
  },

  -- Copy/Paste
  {
    key = 'c',
    mods = 'CMD',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CMD',
    action = wezterm.action.PasteFrom 'Clipboard',
  },

  -- Font size
  {
    key = '=',
    mods = 'CMD',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CMD',
    action = wezterm.action.DecreaseFontSize,
  },
  {
    key = '0',
    mods = 'CMD',
    action = wezterm.action.ResetFontSize,
  },

  -- Search
  {
    key = 'f',
    mods = 'CMD',
    action = wezterm.action.Search { CaseSensitiveString = '' },
  },

  -- Toggle fullscreen
  {
    key = 'Enter',
    mods = 'CMD|CTRL',
    action = wezterm.action.ToggleFullScreen,
  },
}

-- Mouse Configuration
config.mouse_bindings = {
  -- Right click to paste
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Bell Configuration
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn',
  fade_in_duration_ms = 150,
  fade_out_function = 'EaseOut',
  fade_out_duration_ms = 150,
}

-- Hyperlink Rules
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add rule for opening URLs with CMD+click
table.insert(config.hyperlink_rules, {
  regex = [[\b\w+://\S+\b]],
  format = '$0',
})

-- Tab Title
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  end
  return tab.active_pane.title
end)

-- Window Title
wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  local zoomed = ''
  if tab.active_pane.is_zoomed then
    zoomed = '[Z] '
  end

  local index = ''
  if #tabs > 1 then
    index = string.format('[%d/%d] ', tab.tab_index + 1, #tabs)
  end

  return zoomed .. index .. tab.active_pane.title
end)

-- Startup
config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Environment Variables
config.set_environment_variables = {
  PATH = '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
}

return config
