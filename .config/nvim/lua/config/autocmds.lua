-- ~/.config/nvim/lua/config/autocmds.lua
-- Custom autocmds to complement LazyVim defaults

local function augroup(name)
  return vim.api.nvim_create_augroup("custom_" .. name, { clear = true })
end

-- ============================================================================
-- Automatic Cleanup
-- ============================================================================

-- Remove trailing whitespace on save (excludes markdown/diff where trailing spaces matter)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("trim_whitespace"),
  pattern = "*",
  callback = function()
    -- Skip for certain filetypes where trailing spaces matter
    local ft = vim.bo.filetype
    if ft == "markdown" or ft == "diff" then
      return
    end
    -- Save cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- Remove trailing whitespace
    vim.cmd([[%s/\s\+$//e]])
    -- Restore cursor position
    vim.api.nvim_win_set_cursor(0, cursor)
  end,
})

-- ============================================================================
-- File Management
-- ============================================================================

-- Auto-save all buffers when switching away from Neovim
vim.api.nvim_create_autocmd("FocusLost", {
  group = augroup("auto_save"),
  callback = function()
    vim.cmd("silent! wa")
  end,
})

-- ============================================================================
-- Template Insertion
-- ============================================================================

-- Insert shebang and boilerplate for new shell scripts
vim.api.nvim_create_autocmd("BufNewFile", {
  group = augroup("template_sh"),
  pattern = "*.sh",
  callback = function()
    vim.cmd([[
      0put ='#!/usr/bin/env bash'
      0put =''
      0put ='set -euo pipefail'
      0put =''
      $d
      normal! G
      startinsert
    ]])
  end,
})

-- Insert shebang and docstring template for new Python files
vim.api.nvim_create_autocmd("BufNewFile", {
  group = augroup("template_py"),
  pattern = "*.py",
  callback = function()
    vim.cmd([[
      0put ='#!/usr/bin/env python3'
      0put ='\"\"\"'
      0put ='\"\"\"'
      0put =''
      $d
      normal! 2G
      startinsert!
    ]])
  end,
})

-- ============================================================================
-- UI Enhancements
-- ============================================================================

-- Only show cursorline in active window
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = augroup("cursorline_focus"),
  callback = function()
    local ft = vim.bo.filetype
    if ft ~= "neo-tree" and ft ~= "Trouble" and ft ~= "toggleterm" then
      vim.opt_local.cursorline = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
  group = augroup("cursorline_unfocus"),
  callback = function()
    vim.opt_local.cursorline = false
  end,
})

-- ============================================================================
-- Terminal Integration
-- ============================================================================

-- Automatically enter insert mode when opening terminal + clean UI
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("term_settings"),
  callback = function()
    vim.cmd("startinsert")
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

-- ============================================================================
-- Git Integration
-- ============================================================================

-- Git commit message helper: spell check + cursor positioning
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("git_commit"),
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.spell = true
    vim.cmd("normal! gg")
    vim.cmd("startinsert")
  end,
})

-- ============================================================================
-- Performance Optimizations
-- ============================================================================

-- Disable expensive features for large files (>1MB)
vim.api.nvim_create_autocmd("BufReadPre", {
  group = augroup("large_file"),
  callback = function()
    local file_size = vim.fn.getfsize(vim.fn.expand("%"))
    if file_size > 1000000 then -- 1MB
      vim.opt_local.syntax = "off"
      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
      vim.notify("Large file detected - disabled syntax, swap, and undo", vim.log.levels.WARN)
    end
  end,
})
