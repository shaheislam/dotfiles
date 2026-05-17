-- ~/.config/wezterm/wezterm.lua
-- Catppuccin Mocha theme with omerxx-inspired aesthetics
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Font configuration with ligatures and enhanced styling
-- Options: 'DankMono Nerd Font', 'JetBrainsMono Nerd Font', 'VictorMono Nerd Font'
config.font = wezterm.font_with_fallback({
  {
    family = 'JetBrainsMono Nerd Font',
    weight = 'Medium',
    harfbuzz_features = { 'calt=1', 'liga=1' }, -- Standard ligatures only (dlig/ss* add shaping overhead)
  },
  'Flog Symbols', -- Private-use glyphs for vim-flog v3 extended graph drawing
  'DankMono Nerd Font', -- Fallback
})

-- Font size
config.font_size = 14.0

-- Enhanced font rendering
config.freetype_load_target = 'Normal'
config.freetype_render_target = 'HorizontalLcd'

-- Font rules for italic and bold contexts
config.font_rules = {
  -- Italic
  {
    intensity = 'Normal',
    italic = true,
    font = wezterm.font({
      family = 'JetBrainsMono Nerd Font',
      weight = 'Medium',
      style = 'Italic',
    }),
  },
  -- Bold
  {
    intensity = 'Bold',
    italic = false,
    font = wezterm.font({
      family = 'JetBrainsMono Nerd Font',
      weight = 'Bold',
    }),
  },
  -- Bold + Italic
  {
    intensity = 'Bold',
    italic = true,
    font = wezterm.font({
      family = 'JetBrainsMono Nerd Font',
      weight = 'Bold',
      style = 'Italic',
    }),
  },
}

-- Color scheme - Catppuccin Mocha for consistency
config.color_scheme = 'Catppuccin Mocha'

-- Window configuration
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.9
config.macos_window_background_blur = 10

-- Tab bar
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true

-- Cursor
config.default_cursor_style = 'SteadyBlock'

-- Shell
config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Environment variables
config.set_environment_variables = {
  TERM = 'xterm-256color',
  COLORTERM = 'truecolor',
  SHELL = '/opt/homebrew/bin/fish',
  STARSHIP_CONFIG = os.getenv("HOME") .. '/.config/starship.toml',
}

-- Ensure proper shell integration
config.enable_kitty_keyboard = false
config.enable_csi_u_key_encoding = false

-- Terminal features for better prompt support
config.term = "xterm-256color"
config.enable_scroll_bar = false
config.scrollback_lines = 10000

-- Disable audible bell (prevents sound on every keystroke with tmux activity monitoring)
config.audible_bell = "Disabled"

-- Enable kitty graphics protocol for image.nvim
config.enable_kitty_graphics = true

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
  -- Removed Ctrl-f fullscreen binding to avoid conflict with Neovim scrolling
  -- Use macOS native Cmd+Ctrl+F for fullscreen instead
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
  -- Open Claude in new tab (aligned with tmux: Ctrl-s a)
  {
    key = 'a',
    mods = 'CMD',
    action = wezterm.action.SpawnCommandInNewTab {
      args = { '/opt/homebrew/bin/fish', '-c', 'claude' },
    },
  },
  -- Open Neovim in current directory (aligned with tmux: Ctrl-s e)
  {
    key = 'e',
    mods = 'CMD',
    action = wezterm.action.SendString('nvim .\n'),
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
