-- Performance Autocmds - Optimization and resource management
-- These autocmds focus on improving Neovim performance and managing resources

local M = {}

local function augroup(name)
  return vim.api.nvim_create_augroup("performance_" .. name, { clear = true })
end

function M.setup()
  -- ============================================================================
  -- Large File Handling
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
        vim.opt_local.foldmethod = "manual"
        vim.opt_local.spell = false
        vim.opt_local.list = false
        vim.opt_local.relativenumber = false
        vim.opt_local.colorcolumn = ""
        vim.notify("Large file detected - disabled syntax, swap, undo, and other features", vim.log.levels.WARN)

        -- Disable LSP for very large files
        if file_size > 5000000 then -- 5MB
          vim.cmd("LspStop")
          vim.notify("Very large file - LSP disabled", vim.log.levels.WARN)
        end
      end
    end,
  })

  -- Warn when opening files with extremely long lines (potential performance issue)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("long_line_warning"),
    callback = function()
      local max_line_length = 0
      local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(100, vim.api.nvim_buf_line_count(0)), false)
      for _, line in ipairs(lines) do
        max_line_length = math.max(max_line_length, #line)
      end
      if max_line_length > 5000 then
        vim.notify(
          string.format("Warning: File contains very long lines (%d chars), performance may be impacted", max_line_length),
          vim.log.levels.WARN
        )
        -- Disable features that struggle with long lines
        vim.opt_local.cursorline = false
        vim.opt_local.cursorcolumn = false
        vim.opt_local.relativenumber = false
        vim.opt_local.wrap = false
      end
    end,
  })

  -- ============================================================================
  -- Memory Management
  -- ============================================================================

  -- Cleanup old buffers periodically
  vim.api.nvim_create_autocmd("BufHidden", {
    group = augroup("buffer_cleanup"),
    callback = function(event)
      local bufnr = event.buf
      -- Don't clean up special buffers
      if vim.bo[bufnr].buftype ~= "" then
        return
      end

      -- Clean up buffers that haven't been used in a while
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) and not vim.api.nvim_buf_get_option(bufnr, "modified") then
          local last_used = vim.fn.getbufvar(bufnr, "&buflisted")
          if last_used == 0 then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
          end
        end
      end, 60000) -- Clean up after 1 minute of inactivity
    end,
  })

  -- ============================================================================
  -- Lazy Loading
  -- ============================================================================

  -- Defer loading of certain plugins until idle
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    group = augroup("lazy_load"),
    callback = function()
      -- Load heavy features after startup
      vim.schedule(function()
        -- Enable additional features that aren't critical at startup
        if vim.fn.exists(":TSUpdate") == 2 then
          vim.cmd("silent! TSUpdate")
        end
      end)
    end,
  })

  -- ============================================================================
  -- Fold Optimization
  -- ============================================================================

  -- Smart fold management - only calculate folds when needed
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
    group = augroup("fold_optimization"),
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local line_count = vim.api.nvim_buf_line_count(bufnr)

      -- For large files, use simpler fold methods
      if line_count > 10000 then
        vim.opt_local.foldmethod = "indent"
      elseif line_count > 5000 then
        vim.opt_local.foldmethod = "syntax"
      end

      -- Don't auto-calculate folds for large files
      if line_count > 5000 then
        vim.opt_local.foldenable = false
      end
    end,
  })

  -- ============================================================================
  -- Undo File Management
  -- ============================================================================

  -- Clean up old undo files periodically
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup("undo_cleanup"),
    callback = function()
      vim.defer_fn(function()
        local undo_dir = vim.fn.stdpath("data") .. "/undo"
        if vim.fn.isdirectory(undo_dir) == 1 then
          -- Remove undo files older than 90 days
          vim.fn.system(string.format("find '%s' -type f -mtime +90 -delete", undo_dir))
        end
      end, 5000) -- Run 5 seconds after startup
    end,
  })

  -- ============================================================================
  -- Swap File Management
  -- ============================================================================

  -- Clean up orphaned swap files on startup
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup("swap_cleanup"),
    callback = function()
      vim.defer_fn(function()
        local swap_dir = vim.fn.stdpath("data") .. "/swap"
        if vim.fn.isdirectory(swap_dir) == 1 then
          -- Remove swap files older than 7 days
          vim.fn.system(string.format("find '%s' -type f -name '*.swp' -mtime +7 -delete", swap_dir))
        end
      end, 5000) -- Run 5 seconds after startup
    end,
  })

  -- ============================================================================
  -- Treesitter Performance
  -- ============================================================================

  -- Disable treesitter for large files
  vim.api.nvim_create_autocmd("BufReadPre", {
    group = augroup("treesitter_performance"),
    callback = function()
      local file_size = vim.fn.getfsize(vim.fn.expand("%"))
      local line_count = vim.fn.line("$")

      -- Disable for large files or files with many lines
      if file_size > 500000 or line_count > 10000 then
        pcall(vim.cmd, "TSBufDisable highlight")
        pcall(vim.cmd, "TSBufDisable indent")
        vim.notify("Large file - Treesitter disabled", vim.log.levels.INFO)
      end
    end,
  })

  -- ============================================================================
  -- Completion Performance
  -- ============================================================================

  -- Optimize completion menu performance
  vim.api.nvim_create_autocmd("CompleteDone", {
    group = augroup("completion_cleanup"),
    callback = function()
      -- Close preview window after completion
      if vim.fn.pumvisible() == 0 then
        pcall(vim.cmd, "pclose")
      end
    end,
  })

  -- ============================================================================
  -- Diagnostic Performance
  -- ============================================================================

  -- Throttle diagnostic updates in insert mode
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup("diagnostic_throttle"),
    callback = function()
      vim.diagnostic.config({
        update_in_insert = false,
        virtual_text = false,
      })
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup("diagnostic_restore"),
    callback = function()
      vim.diagnostic.config({
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
      })
    end,
  })

  -- ============================================================================
  -- Syntax Performance
  -- ============================================================================

  -- Reset syntax highlighting if it gets out of sync
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup("syntax_sync"),
    callback = function()
      if vim.bo.syntax ~= "" and vim.fn.line("$") < 10000 then
        vim.cmd("syntax sync fromstart")
      end
    end,
  })

  -- ============================================================================
  -- CursorHold Performance
  -- ============================================================================

  -- Dynamically adjust updatetime based on file size
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = augroup("updatetime_adjust"),
    callback = function()
      local line_count = vim.fn.line("$")
      if line_count > 10000 then
        vim.opt_local.updatetime = 1000 -- 1 second for large files
      elseif line_count > 5000 then
        vim.opt_local.updatetime = 500 -- 500ms for medium files
      else
        vim.opt_local.updatetime = 300 -- Default for small files
      end
    end,
  })
end

return M