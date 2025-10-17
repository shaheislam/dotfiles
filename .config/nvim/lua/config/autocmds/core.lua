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

  -- Auto-save buffer when switching to another buffer
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup("auto_save_buffer_switch"),
    callback = function()
      if vim.bo.modified and not vim.bo.readonly and vim.fn.expand("%") ~= "" then
        vim.cmd("silent! write")
      end
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

  -- Transparent floating windows for all themes
  local function set_transparent_floats()
    -- Make floating windows transparent by linking to Normal
    vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
    vim.api.nvim_set_hl(0, "FloatBorder", { link = "Normal" })
    -- Optional: Make diagnostic floating windows specifically transparent
    vim.api.nvim_set_hl(0, "DiagnosticFloatingError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "DiagnosticFloatingWarn", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "DiagnosticFloatingInfo", { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "DiagnosticFloatingHint", { link = "DiagnosticHint" })
  end

  -- Apply on colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup("transparent_floats"),
    callback = set_transparent_floats,
  })

  -- Also apply on startup after colorscheme is loaded
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup("transparent_floats_init"),
    callback = function()
      vim.defer_fn(set_transparent_floats, 100) -- Small delay to ensure theme is fully loaded
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
  -- Note: Snacks.nvim handles auto_close for its terminals via configuration
  vim.api.nvim_create_autocmd("TermOpen", {
    group = augroup("term_settings"),
    callback = function()
      vim.cmd("startinsert")
      vim.opt_local.number = true
      vim.opt_local.relativenumber = true
      vim.opt_local.statuscolumn = "%s %{v:lnum} %{v:relnum}"
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

  -- Auto-refresh quickfix when a buffer in the list is modified
  -- Uses debounced timer to wait for LSP diagnostics and batch rapid saves
  local qf_refresh_timer = vim.loop.new_timer()

  -- Configurable delay (ms) to wait for LSP diagnostics before refreshing
  -- Increase to 200-250ms if you have slow LSP servers
  local QF_REFRESH_DELAY = vim.g.qf_refresh_delay or 150

  -- Cleanup timer on exit to prevent resource leaks
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup("quickfix_cleanup"),
    callback = function()
      if qf_refresh_timer then
        qf_refresh_timer:stop()
        qf_refresh_timer:close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup("quickfix_auto_refresh"),
    callback = function(event)
      -- Early exit: Check if quickfix window is open
      local qf_wins = vim.fn.getqflist({ winid = 0 })
      if qf_wins.winid == 0 then
        return -- Quickfix not open, nothing to do
      end

      -- Early exit: Check if this buffer is in the quickfix list BEFORE starting timer
      -- This optimization avoids unnecessary timer operations for unrelated buffers
      local bufnr = event.buf
      local qf_list = vim.fn.getqflist()
      local buffer_in_qf = false
      for _, item in ipairs(qf_list) do
        if item.bufnr == bufnr then
          buffer_in_qf = true
          break
        end
      end

      if not buffer_in_qf then
        return -- Buffer not in quickfix, nothing to refresh
      end

      -- Stop any pending refresh (debouncing multiple rapid saves)
      qf_refresh_timer:stop()

      -- Start timer with configurable delay to allow LSP diagnostics to update
      -- vim.schedule_wrap() is CRITICAL for thread safety when calling Vim API from async context
      qf_refresh_timer:start(QF_REFRESH_DELAY, 0, vim.schedule_wrap(function()
        -- Refresh quickfix with error handling (nil = quickfix, not loclist)
        local ok, err = pcall(function()
          require("quicker").refresh(nil, { keep_diagnostics = true })
        end)

        -- Optional: Uncomment to get notifications when refresh happens (useful for debugging)
        -- if ok then
        --   vim.notify("Quickfix refreshed", vim.log.levels.INFO, { title = "Quickfix" })
        -- else
        if not ok then
          vim.notify("Failed to refresh quickfix: " .. tostring(err), vim.log.levels.WARN, { title = "Quickfix" })
        end
      end))
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