-- ~/.config/nvim/lua/config/autocmds.lua
-- Modular Autocmd System for Neovim
-- This file loads modular autocmd configurations for better organization and performance

-- ============================================================================
-- Configuration Options
-- ============================================================================

-- You can disable specific modules or features by setting these to false
local config = {
  -- Module loading
  load_core = true, -- Essential autocmds (recommended to keep enabled)
  load_lsp = true, -- LSP-related autocmds
  load_performance = true, -- Performance optimizations
  load_productivity = true, -- Productivity enhancements
  load_languages = true, -- Language-specific settings

  -- Feature flags (used by various modules)
  auto_refresh_codelens = false, -- Enable auto-refresh of code lens (may cause issues with some LSPs)
  toggle_inlay_hints_on_insert = false, -- Toggle inlay hints when entering/leaving insert mode
  mason_auto_update = true, -- Enable automatic Mason package updates
  smart_fold_management = true, -- Enable smart fold management
}

-- Set global flags for modules to use
for key, value in pairs(config) do
  vim.g[key] = value
end

-- ============================================================================
-- Load Modules
-- ============================================================================

local function load_module(name, enabled)
  if not enabled then
    vim.notify("Autocmd module '" .. name .. "' is disabled", vim.log.levels.DEBUG)
    return
  end

  local ok, module = pcall(require, "config.autocmds." .. name)
  if ok and module.setup then
    module.setup()
    vim.notify("Loaded autocmd module: " .. name, vim.log.levels.DEBUG)
  elseif not ok then
    vim.notify("Failed to load autocmd module: " .. name .. "\n" .. module, vim.log.levels.ERROR)
  end
end

-- Load all enabled modules
load_module("core", config.load_core)
load_module("lsp", config.load_lsp)
load_module("performance", config.load_performance)
load_module("productivity", config.load_productivity)
load_module("languages", config.load_languages)

-- ============================================================================
-- Module Information
-- ============================================================================

-- The autocmd system is now modularized for better organization and performance.
-- Each module contains related autocmds:
--
-- * core.lua         - Essential functionality (cleanup, UI, terminal, git)
-- * lsp.lua          - Language Server Protocol integration
-- * performance.lua  - Performance optimizations and resource management
-- * productivity.lua - Workflow enhancements and automation
-- * languages.lua    - Language-specific settings and keymaps
--
-- You can disable any module by setting the corresponding config option to false above.
--
-- To add new autocmds:
-- 1. Identify the appropriate module for your autocmd
-- 2. Add it to the relevant file in ~/.config/nvim/lua/config/autocmds/
-- 3. Follow the existing patterns and use the module's augroup function
--
-- For debugging autocmds:
-- :verbose autocmd <event> - Show all autocmds for an event
-- :verbose autocmd <group> - Show all autocmds in a group
-- :autocmd! <group> - Remove all autocmds in a group