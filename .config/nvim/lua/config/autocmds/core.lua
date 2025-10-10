-- Core Autocmds - Essential functionality
-- These autocmds are always loaded and provide fundamental editor behavior

local M = {}

local function augroup(name)
  return vim.api.nvim_create_augroup("core_" .. name, { clear = true })
end

function M.setup()
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

  -- Auto-create parent directories when saving a file
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("auto_create_dir"),
    callback = function(event)
      if event.match:match("^%w%w+://") then
        return
      end
      local file = vim.loop.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
  })

  -- Auto-reload files changed outside vim
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    group = augroup("checktime"),
    callback = function()
      if vim.o.buftype ~= "nofile" then
        vim.cmd("checktime")
      end
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

  -- Highlight on yank
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function()
      vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
    end,
  })

  -- Auto-resize splits when window is resized
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup("resize_splits"),
    callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
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
      vim.opt_local.textwidth = 72
      vim.opt_local.colorcolumn = "50,72"
      vim.cmd("normal! gg")
      vim.cmd("startinsert")
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

  -- Auto-close certain windows with q
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
      "qf",
      "help",
      "man",
      "notify",
      "lspinfo",
      "spectre_panel",
      "startuptime",
      "tsplayground",
      "PlenaryTestPopup",
    },
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
    end,
  })

  -- ============================================================================
  -- Session Management
  -- ============================================================================

  -- Restore cursor position when opening files
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("restore_cursor"),
    callback = function(event)
      local exclude = { "gitcommit" }
      local buf = event.buf
      if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
        return
      end
      vim.b[buf].lazyvim_last_loc = true
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      local lcount = vim.api.nvim_buf_line_count(buf)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })

  -- ============================================================================
  -- Misc Enhancements
  -- ============================================================================

  -- Wrap and check for spell in text filetypes
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("wrap_spell"),
    pattern = { "gitcommit", "markdown", "text" },
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.spell = true
    end,
  })

  -- Fix conceallevel for json files
  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = augroup("json_conceal"),
    pattern = { "json", "jsonc", "json5" },
    callback = function()
      vim.opt_local.conceallevel = 0
    end,
  })
end

return M