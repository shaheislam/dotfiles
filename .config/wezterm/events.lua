-- WezTerm Events Configuration
-- Event handlers for tab titles, window titles, and other WezTerm events

local wezterm = require('wezterm')

local M = {}

-- Format tab title with better styling
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  local pane_title = tab.active_pane.title

  -- Use tab title if set, otherwise use pane title
  if title and #title > 0 then
    title = title
  else
    title = pane_title
  end

  -- Truncate title if too long
  if #title > 16 then
    title = title:sub(1, 13) .. '...'
  end

  -- Add indicators
  local indicators = ''
  if tab.active_pane.is_zoomed then
    indicators = indicators .. ' 🔍'
  end

  if tab.tab_index == 0 then
    indicators = indicators .. ' 🏠'
  end

  -- Style active vs inactive tabs
  if tab.is_active then
    return {
      { Text = ' ' .. title .. indicators .. ' ' },
    }
  else
    return {
      { Text = ' ' .. title .. indicators .. ' ' },
    }
  end
end)

-- Format window title with useful information
wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  local zoomed = ''
  if tab.active_pane.is_zoomed then
    zoomed = '[ZOOMED] '
  end

  local index = ''
  if #tabs > 1 then
    index = string.format('[%d/%d] ', tab.tab_index + 1, #tabs)
  end

  local workspace = ''
  local workspace_name = wezterm.mux.get_active_workspace()
  if workspace_name and workspace_name ~= 'default' then
    workspace = string.format('[%s] ', workspace_name)
  end

  return zoomed .. workspace .. index .. tab.active_pane.title
end)

-- Update status when leader key is active
wezterm.on('update-right-status', function(window, pane)
  local name = window:active_key_table()
  if name then
    name = 'TABLE: ' .. name
  end
  window:set_right_status(name or '')
end)

-- GUI startup event for initial setup
wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

-- Bell event handling
wezterm.on('bell', function(window, pane)
  wezterm.log_info('Bell activated!')
end)

-- New tab button styling
wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
  if default_action and button == 'Left' then
    window:perform_action(default_action, pane)
  end

  if button == 'Right' then
    window:perform_action(
      wezterm.action.ShowLauncherArgs({
        flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS',
      }),
      pane
    )
  end
  return false
end)

-- Window configuration based on domain
wezterm.on('window-config-reloaded', function(window, pane)
  wezterm.log_info('Configuration reloaded')
end)

return M
