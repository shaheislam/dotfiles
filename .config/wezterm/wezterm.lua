-- ~/.config/wezterm/wezterm.lua
-- Catppuccin Mocha theme with omerxx-inspired aesthetics
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Font configuration
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Medium' })
config.font_size = 14.0

-- Color scheme - Catppuccin Mocha for consistency
config.color_scheme = 'Catppuccin Mocha'

-- Window configuration
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 20

-- Tab bar
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true

-- Cursor
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500

-- Shell
config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Environment variables
config.set_environment_variables = {
  TERM = 'xterm-256color',
  COLORTERM = 'truecolor',
  STARSHIP_CONFIG = os.getenv("HOME") .. '/.config/starship.toml',
}

-- Ensure proper shell integration
config.enable_kitty_keyboard = false
config.enable_csi_u_key_encoding = false

-- Terminal features for better prompt support
config.term = "xterm-256color"
config.enable_scroll_bar = false
config.scrollback_lines = 10000

-- Additional omerxx-inspired settings
config.window_padding = {
  left = 2,
  right = 2,
  top = 0,
  bottom = 0,
}

-- Disable font size adjustment with mouse wheel
config.adjust_window_size_when_changing_font_size = false

-- Key bindings (enhanced with omerxx style)
config.keys = {
  -- Toggle fullscreen (omerxx style)
  {
    key = 'q',
    mods = 'CTRL',
    action = wezterm.action.ToggleFullScreen,
  },
  -- Clear scrollback
  {
    key = "'",
    mods = 'CTRL',
    action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
  },
  -- Split panes
  {
    key = 'd',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Navigate panes
  {
    key = 'LeftArrow',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
}

-- Mouse bindings (omerxx style - Ctrl+Click to open links)
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- Performance
config.enable_wayland = false
config.front_end = "OpenGL"
config.max_fps = 120

return config
