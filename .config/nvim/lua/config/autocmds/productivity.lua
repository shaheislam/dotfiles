-- Productivity Autocmds - Workflow enhancements and automation
-- These autocmds boost productivity through smart automation and enhanced features

local M = {}

local function augroup(name)
  return vim.api.nvim_create_augroup("productivity_" .. name, { clear = true })
end

function M.setup()
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
        0put ='IFS=$''\\n\\t'''
        0put =''
        0put ='# Script: ' . expand('%:t')
        0put ='# Description: '
        0put ='# Author: ' . $USER
        0put ='# Date: ' . strftime('%Y-%m-%d')
        0put =''
        $d
        normal! 7GA
        startinsert!
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
        0put ='Module: ' . expand('%:t:r')
        0put ='Description: '
        0put ='Author: ' . $USER
        0put ='Date: ' . strftime('%Y-%m-%d')
        0put ='\"\"\"'
        0put =''
        $d
        normal! 4GA
        startinsert!
      ]])
    end,
  })

  -- Template for new Dockerfiles
  vim.api.nvim_create_autocmd("BufNewFile", {
    group = augroup("template_dockerfile"),
    pattern = "Dockerfile",
    callback = function()
      vim.cmd([[
        0put ='# Build stage'
        0put ='FROM alpine:latest AS builder'
        0put =''
        0put ='# Runtime stage'
        0put ='FROM alpine:latest'
        0put =''
        0put ='# Metadata'
        0put ='LABEL maintainer=\"' . $USER . '\"'
        0put ='LABEL created=\"' . strftime('%Y-%m-%d') . '\"'
        0put =''
        0put ='# Install dependencies'
        0put ='RUN apk add --no-cache \\'
        0put ='    ca-certificates'
        0put =''
        0put ='# Copy application'
        0put ='COPY --from=builder /app /app'
        0put =''
        0put ='# Set working directory'
        0put ='WORKDIR /app'
        0put =''
        0put ='# Run application'
        0put ='CMD [\"/app/main\"]'
        $d
        normal! gg
      ]])
    end,
  })

  -- ============================================================================
  -- Test Navigation
  -- ============================================================================

  -- Toggle between test and implementation files
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("test_navigation"),
    pattern = { "python", "go", "typescript", "javascript", "rust" },
    callback = function()
      vim.keymap.set("n", "<leader>gt", function()
        local current_file = vim.fn.expand("%")
        local test_patterns = {
          -- Python patterns
          { from = "(.+)%.py$", to = "test_%1.py" },
          { from = "test_(.+)%.py$", to = "%1.py" },
          { from = "(.+)%.py$", to = "%1_test.py" },
          { from = "(.+)_test%.py$", to = "%1.py" },
          -- Go patterns
          { from = "(.+)%.go$", to = "%1_test.go" },
          { from = "(.+)_test%.go$", to = "%1.go" },
          -- TypeScript/JavaScript patterns
          { from = "(.+)%.ts$", to = "%1.test.ts" },
          { from = "(.+)%.test%.ts$", to = "%1.ts" },
          { from = "(.+)%.js$", to = "%1.test.js" },
          { from = "(.+)%.test%.js$", to = "%1.js" },
          { from = "(.+)%.tsx$", to = "%1.test.tsx" },
          { from = "(.+)%.test%.tsx$", to = "%1.tsx" },
          -- Rust patterns
          { from = "src/(.+)%.rs$", to = "tests/%1_test.rs" },
          { from = "tests/(.+)_test%.rs$", to = "src/%1.rs" },
        }

        for _, pattern in ipairs(test_patterns) do
          local test_file = current_file:gsub(pattern.from, pattern.to)
          if test_file ~= current_file and vim.fn.filereadable(test_file) == 1 then
            vim.cmd("edit " .. test_file)
            return
          end
        end

        vim.notify("No corresponding test/implementation file found", vim.log.levels.WARN)
      end, { desc = "Toggle between test and implementation", buffer = true })
    end,
  })

  -- ============================================================================
  -- Smart Comments
  -- ============================================================================

  -- Highlight TODO, FIXME, NOTE, WARNING comments
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = augroup("todo_comments"),
    callback = function()
      vim.fn.matchadd("Todo", [[\<\(TODO\|FIXME\|CHANGED\|XXX\|IDEA\|HACK\):]])
      vim.fn.matchadd("Debug", [[\<\(NOTE\|INFO\|IDEA\):]])
      vim.fn.matchadd("ErrorMsg", [[\<\(BUG\|ERROR\|DANGER\|CRITICAL\):]])
      vim.fn.matchadd("WarningMsg", [[\<\(WARNING\|CAUTION\|DEPRECATED\|OBSOLETE\):]])
    end,
  })

  -- ============================================================================
  -- URL Handling
  -- ============================================================================

  -- Highlight URLs in comments and strings
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = augroup("url_highlight"),
    pattern = "*",
    callback = function()
      -- Highlight URLs with protocol
      vim.fn.matchadd("Underlined", [[\v<(https?|ftp|file)://[^ \t\n\r]+]])
      -- Highlight URLs starting with www.
      vim.fn.matchadd("Underlined", "\\v<www\\.[a-zA-Z0-9][-a-zA-Z0-9._]+[a-zA-Z0-9/]")
      -- Highlight domain-like patterns (e.g., google.com)
      vim.fn.matchadd("Underlined", "\\v<[a-zA-Z0-9][-a-zA-Z0-9]+\\.[a-zA-Z]{2,}(/[^ \\t\\n\\r]*)?")
    end,
  })

  -- Open URL under cursor with gx (improved)
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("open_url"),
    pattern = "*",
    callback = function()
      vim.keymap.set("n", "gx", function()
        local url = vim.fn.expand("<cWORD>")
        -- Remove surrounding quotes and brackets
        url = url:gsub("^[\"'<({[]", ""):gsub("[\"'>)}]$", "")

        -- Check if it's already a valid URL with protocol
        if url:match("^https?://") or url:match("^ftp://") then
          vim.fn.system({ "open", url })
          vim.notify("Opening: " .. url, vim.log.levels.INFO)
        -- Check if it looks like a URL without protocol
        elseif url:match("^www%.") or url:match("%.%w+$") then
          -- Add https:// prefix for URLs without protocol
          local full_url = "https://" .. url
          vim.fn.system({ "open", full_url })
          vim.notify("Opening: " .. full_url, vim.log.levels.INFO)
        else
          vim.notify("No URL found under cursor", vim.log.levels.WARN)
        end
      end, { buffer = true, desc = "Open URL under cursor" })
    end,
  })

  -- ============================================================================
  -- Smart Indent Detection
  -- ============================================================================

  -- Smart indent detection based on file content (improved)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("detect_indent"),
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(100, vim.api.nvim_buf_line_count(0)), false)
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
        vim.notify("Detected: tabs (width 4)", vim.log.levels.INFO)
      elseif spaces_2 > spaces_4 then
        vim.opt_local.expandtab = true
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.notify("Detected: 2 spaces", vim.log.levels.INFO)
      elseif spaces_4 > 0 then
        vim.opt_local.expandtab = true
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
        vim.notify("Detected: 4 spaces", vim.log.levels.INFO)
      end
    end,
  })

  -- ============================================================================
  -- Smart Session Management (Improved)
  -- ============================================================================

  -- Save folds when leaving buffer (only if nvim-ufo is not loaded)
  if not pcall(require, "ufo") then
    vim.api.nvim_create_autocmd("BufWinLeave", {
      group = augroup("save_folds"),
      pattern = "*.*",
      callback = function()
        pcall(vim.cmd, "silent! mkview")
      end,
    })

    -- Restore folds when entering buffer
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = augroup("restore_folds"),
      pattern = "*.*",
      callback = function()
        pcall(vim.cmd, "silent! loadview")
      end,
    })
  end

  -- ============================================================================
  -- Project-Specific Settings
  -- ============================================================================

  -- Load project-specific settings from .nvim.lua or .nvimrc
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
    group = augroup("project_settings"),
    callback = function()
      local config_file = vim.fn.findfile(".nvim.lua", ".;")
      if config_file ~= "" then
        vim.schedule(function()
          local ok, err = pcall(dofile, config_file)
          if ok then
            vim.notify("Loaded project config: " .. config_file, vim.log.levels.INFO)
          else
            vim.notify("Failed to load project config: " .. err, vim.log.levels.ERROR)
          end
        end)
      end
    end,
  })

  -- ============================================================================
  -- Quick Notes
  -- ============================================================================

  -- Quick note-taking in a scratch buffer
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("quick_notes"),
    pattern = "markdown",
    callback = function()
      vim.keymap.set("n", "<leader>nn", function()
        -- Create a new note with timestamp
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        vim.cmd("normal! o")
        vim.cmd("normal! o## " .. timestamp)
        vim.cmd("normal! o")
        vim.cmd("startinsert!")
      end, { buffer = true, desc = "Insert timestamped note" })
    end,
  })

  -- ============================================================================
  -- Smart Pairs
  -- ============================================================================

  -- Auto-close brackets and quotes
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = augroup("smart_pairs"),
    callback = function()
      local char = vim.v.char
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local next_char = line:sub(col + 1, col + 1)

      -- Skip if next character is the same closing character
      if (char == ")" and next_char == ")") or
         (char == "]" and next_char == "]") or
         (char == "}" and next_char == "}") or
         (char == '"' and next_char == '"') or
         (char == "'" and next_char == "'") then
        vim.v.char = ""
        vim.cmd("normal! l")
      end
    end,
  })

  -- ============================================================================
  -- Mason Auto-Update (Optimized)
  -- ============================================================================

  -- Automatically update Mason packages in the background (optimized version)
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup("mason_auto_update"),
    callback = function()
      local update_interval_hours = 24
      local notify_on_update = true
      local data_path = vim.fn.stdpath("data") .. "/mason_last_update"

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

      local function save_timestamp()
        vim.fn.writefile({ tostring(os.time()) }, data_path)
      end

      if should_update() then
        vim.defer_fn(function()
          local ok, mason = pcall(require, "mason")
          if not ok then
            return
          end

          -- Use Mason's registry to check for updates
          local registry = require("mason-registry")

          registry.refresh(function()
            save_timestamp()

            local outdated = {}
            for _, pkg in ipairs(registry.get_installed_packages()) do
              if pkg:check_new_version() then
                table.insert(outdated, pkg.name)
              end
            end

            if #outdated > 0 then
              vim.schedule(function()
                for _, name in ipairs(outdated) do
                  local pkg = registry.get_package(name)
                  pkg:install({ force = false })
                end

                if notify_on_update then
                  vim.notify(
                    string.format("Updated %d Mason packages", #outdated),
                    vim.log.levels.INFO,
                    { title = "Mason Auto-Update" }
                  )
                end
              end)
            end
          end)
        end, 2000) -- Wait 2 seconds after VimEnter
      end
    end,
  })
end

return M