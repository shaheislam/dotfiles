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

-- ============================================================================
-- Advanced LSP Enhancements
-- ============================================================================

-- Highlight symbol references under cursor
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = augroup("lsp_document_highlight"),
  callback = function()
    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
    for _, client in pairs(clients) do
      if client.server_capabilities.documentHighlightProvider then
        vim.lsp.buf.document_highlight()
      end
    end
  end,
})

-- Clear reference highlights when cursor moves
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = augroup("lsp_document_highlight_clear"),
  callback = function()
    vim.lsp.buf.clear_references()
  end,
})

-- Auto-refresh code lens - DISABLED by default to avoid API errors
-- Uncomment if you want automatic code lens refresh and your LSP servers support it
--[[
vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
  group = augroup("lsp_codelens_refresh"),
  callback = function(args)
    local bufnr = args.buf
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end
    if vim.bo[bufnr].buftype ~= "" then
      return
    end
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    for _, client in pairs(clients) do
      if client.server_capabilities and client.server_capabilities.codeLensProvider then
        pcall(vim.lsp.codelens.refresh)
      end
    end
  end,
})
--]]

-- Show diagnostics in hover window when cursor is on a line with diagnostics
vim.api.nvim_create_autocmd("CursorHold", {
  group = augroup("lsp_diagnostic_hover"),
  callback = function()
    -- Only show if there are diagnostics on the current line
    local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
    if #diagnostics > 0 then
      vim.diagnostic.open_float(nil, {
        focusable = false,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        border = "rounded",
        source = "always",
        prefix = " ",
        scope = "cursor",
      })
    end
  end,
})

-- ============================================================================
-- Code Quality Enhancements
-- ============================================================================

-- Highlight TODO, FIXME, NOTE, WARNING comments
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = augroup("todo_comments"),
  callback = function()
    vim.fn.matchadd("Todo", [[\<\(TODO\|FIXME\|CHANGED\|XXX\|IDEA\|HACK\):]])
    vim.fn.matchadd("Debug", [[\<\(NOTE\|INFO\|IDEA\):]])
    vim.fn.matchadd("ErrorMsg", [[\<\(BUG\|ERROR\|DANGER\):]])
    vim.fn.matchadd("WarningMsg", [[\<\(WARNING\|CAUTION\|DEPRECATED\):]])
  end,
})

-- Highlight URLs in comments and strings
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = augroup("url_highlight"),
  pattern = "*",
  callback = function()
    vim.fn.matchadd("Underlined", [[\v<(https?|ftp|file)://[^ \t\n\r]+]])
  end,
})

-- ============================================================================
-- Smart File Management
-- ============================================================================

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

-- Smart indent detection based on file content
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("detect_indent"),
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)
    local tabs, spaces_2, spaces_4 = 0, 0, 0

    for _, line in ipairs(lines) do
      if line:match("^\t") then
        tabs = tabs + 1
      elseif line:match("^  [^ ]") then
        spaces_2 = spaces_2 + 1
      elseif line:match("^    [^ ]") then
        spaces_4 = spaces_4 + 1
      end
    end

    -- Set indentation based on what's most common
    if tabs > spaces_2 and tabs > spaces_4 then
      vim.opt_local.expandtab = false
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
    elseif spaces_2 > spaces_4 then
      vim.opt_local.expandtab = true
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
    elseif spaces_4 > 0 then
      vim.opt_local.expandtab = true
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
    end
  end,
})

-- ============================================================================
-- Language-Specific Enhancements
-- ============================================================================

-- Python: Auto-activate virtual environment
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = augroup("python_venv"),
  pattern = "*.py",
  callback = function()
    -- Look for venv in project root
    local venv_path = vim.fn.getcwd() .. "/venv"
    local venv_bin = venv_path .. "/bin/activate"
    if vim.fn.filereadable(venv_bin) == 1 then
      vim.env.VIRTUAL_ENV = venv_path
      vim.env.PATH = venv_path .. "/bin:" .. vim.env.PATH
    end
  end,
})

-- Go: Format imports and code on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("go_format"),
  pattern = "*.go",
  callback = function()
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
    for _, res in pairs(result or {}) do
      for _, action in pairs(res.result or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
        end
      end
    end
    vim.lsp.buf.format({ async = false })
  end,
})

-- Rust: Auto-reload when Cargo.toml changes
vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup("cargo_reload"),
  pattern = "Cargo.toml",
  callback = function()
    vim.notify("Cargo.toml updated, reloading workspace...", vim.log.levels.INFO)
    vim.cmd("LspRestart")
  end,
})

-- ============================================================================
-- Performance Monitoring
-- ============================================================================

-- Warn when opening files with extremely long lines (potential performance issue)
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("long_line_warning"),
  callback = function()
    local max_line_length = 0
    local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false) -- Check first 100 lines
    for _, line in ipairs(lines) do
      max_line_length = math.max(max_line_length, #line)
    end
    if max_line_length > 5000 then
      vim.notify(
        string.format("Warning: File contains very long lines (%d chars), performance may be impacted", max_line_length),
        vim.log.levels.WARN
      )
    end
  end,
})

-- ============================================================================
-- Mason Package Manager Auto-Update
-- ============================================================================

-- Automatically update Mason packages in the background
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup("mason_auto_update"),
  callback = function()
    -- Configuration
    local update_interval_hours = 24 -- How often to check for updates
    local notify_on_update = true -- Show notification when updates are found
    local data_path = vim.fn.stdpath("data") .. "/mason_last_update"

    -- Check if enough time has passed since last update
    local function should_update()
      local ok, last_update = pcall(vim.fn.readfile, data_path)
      if not ok or #last_update == 0 then
        return true
      end

      local last_timestamp = tonumber(last_update[1])
      if not last_timestamp then
        return true
      end

      local current_time = os.time()
      local hours_passed = (current_time - last_timestamp) / 3600
      return hours_passed >= update_interval_hours
    end

    -- Save the current timestamp
    local function save_timestamp()
      vim.fn.writefile({ tostring(os.time()) }, data_path)
    end

    -- Run the update if needed
    if should_update() then
      -- Delay execution to ensure Mason is fully loaded
      vim.defer_fn(function()
        -- Check if Mason is available
        local ok, mason = pcall(require, "mason")
        if not ok then
          return
        end

        -- Run MasonUpdate silently in the background
        vim.schedule(function()
          -- Save timestamp before running update
          save_timestamp()

          -- Create a temporary buffer to capture output
          local bufnr = vim.api.nvim_create_buf(false, true)

          -- Run MasonUpdate command silently
          local success = pcall(function()
            -- Temporarily redirect messages
            local old_notify = vim.notify
            local updates_found = false

            vim.notify = function(msg, level)
              -- Check if updates were found
              if msg and msg:match("updated") then
                updates_found = true
              end
              -- Suppress Mason UI messages during update
              if not (msg and msg:match("Mason")) then
                old_notify(msg, level)
              end
            end

            -- Run the update command
            vim.cmd("silent! MasonUpdate")

            -- Restore original notify
            vim.notify = old_notify

            -- Show notification if configured and updates were found
            if notify_on_update and updates_found then
              vim.notify("Mason packages updated successfully", vim.log.levels.INFO, { title = "Mason" })
            end
          end)

          -- Clean up temporary buffer
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end

          if not success and notify_on_update then
            -- Only show error if something actually went wrong
            -- Silently ignore if Mason just isn't ready yet
          end
        end)
      end, 2000) -- Wait 2 seconds after VimEnter to ensure everything is loaded
    end
  end,
})
