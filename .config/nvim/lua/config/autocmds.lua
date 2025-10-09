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
-- DevOps & Cloud Formatting
-- ============================================================================

-- Enforce 2-space indentation for YAML/JSON (cloud config standard)
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("yaml_json_indent"),
  pattern = { "yaml", "yml", "json", "jsonc" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- CRITICAL: Makefiles REQUIRE tabs (spaces will break make)
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("makefile_tabs"),
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- ============================================================================
-- Error Handling
-- ============================================================================

-- Auto-open quickfix window when errors are detected
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  group = augroup("quickfix_auto"),
  pattern = "[^l]*",
  callback = function()
    vim.cmd("cwindow")
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

-- ============================================================================
-- LSP Integration
-- ============================================================================

-- Organize imports automatically on save (Python, Go, TypeScript)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("organize_imports"),
  pattern = { "*.py", "*.go", "*.ts", "*.tsx" },
  callback = function()
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
    for _, res in pairs(result or {}) do
      for _, action in pairs(res.result or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
        end
      end
    end
  end,
})

-- Auto-close LSP preview windows when leaving insert mode
vim.api.nvim_create_autocmd("InsertLeave", {
  group = augroup("close_preview"),
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= "" then
        vim.api.nvim_win_close(win, false)
      end
    end
  end,
})

-- ============================================================================
-- Code Quality & Standards
-- ============================================================================

-- Visual indicator for long lines in code files
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("long_line_warning"),
  pattern = { "python", "go", "typescript", "javascript", "lua", "rust" },
  callback = function()
    vim.opt_local.colorcolumn = "80,100,120"
  end,
})

-- ============================================================================
-- Test Navigation
-- ============================================================================

-- Toggle between test and implementation files
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("test_navigation"),
  pattern = { "python", "go", "typescript", "javascript" },
  callback = function()
    vim.keymap.set("n", "<leader>gt", function()
      local current_file = vim.fn.expand("%")
      local test_patterns = {
        -- Python patterns
        { from = "(.+)%.py$", to = "test_%1.py" },
        { from = "test_(.+)%.py$", to = "%1.py" },
        -- Go patterns
        { from = "(.+)%.go$", to = "%1_test.go" },
        { from = "(.+)_test%.go$", to = "%1.go" },
        -- TypeScript/JavaScript patterns
        { from = "(.+)%.ts$", to = "%1.test.ts" },
        { from = "(.+)%.test%.ts$", to = "%1.ts" },
        { from = "(.+)%.js$", to = "%1.test.js" },
        { from = "(.+)%.test%.js$", to = "%1.js" },
      }

      for _, pattern in ipairs(test_patterns) do
        local test_file = current_file:gsub(pattern.from, pattern.to)
        if test_file ~= current_file and vim.fn.filereadable(test_file) == 1 then
          vim.cmd("edit " .. test_file)
          return
        end
      end

      vim.notify("No corresponding test/implementation file found", vim.log.levels.WARN)
    end, { desc = "Toggle between test and implementation" })
  end,
})

-- ============================================================================
-- Session Management
-- ============================================================================

-- Save fold state when leaving buffer
vim.api.nvim_create_autocmd("BufWinLeave", {
  group = augroup("save_folds"),
  pattern = "*.*",
  callback = function()
    vim.cmd("silent! mkview")
  end,
})

-- Restore fold state when entering buffer
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = augroup("restore_folds"),
  pattern = "*.*",
  callback = function()
    vim.cmd("silent! loadview")
  end,
})
