-- ~/.config/nvim/lua/plugins/diagnostic.lua
-- Diagnostic tools for icon and font issues

return {
  -- Font and icon diagnostic command
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      if opts.spec then
        vim.list_extend(opts.spec, {
          { "<leader>di", "<cmd>lua require('diagnostic-icons').test()<cr>", desc = "Test Icons" },
        })
      end
    end,
  },

  -- Custom diagnostic functions
  {
    "folke/lazy.nvim",
    config = function()
      -- Create a user command for icon testing
      vim.api.nvim_create_user_command('IconTest', function()
        local icons_to_test = {
          -- File types
          { "lua", "" },
          { "javascript", "" },
          { "typescript", "" },
          { "python", "" },
          { "rust", "" },
          { "go", "" },
          { "markdown", "" },
          { "json", "" },
          { "yaml", "" },
          { "dockerfile", "" },

          -- Folders and UI
          { "folder", "" },
          { "folder_open", "" },
          { "file", "" },
          { "git", "" },
          { "search", "" },
          { "settings", "" },
        }

        -- Create a new buffer for the test
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, "Icon Test")

        local lines = {
          "=== NEOVIM ICON DIAGNOSTIC TEST ===",
          "",
          "If you see boxes (□) instead of icons, you have font issues.",
          "All items below should show proper icons:",
          "",
        }

        for _, icon_info in ipairs(icons_to_test) do
          table.insert(lines, string.format("  %s  %s", icon_info[2], icon_info[1]))
        end

        table.insert(lines, "")
        table.insert(lines, "=== FONT INFORMATION ===")
        table.insert(lines, "")
        table.insert(lines, "Current TERM: " .. (vim.env.TERM or "unknown"))
        table.insert(lines, "Termguicolors: " .. tostring(vim.opt.termguicolors:get()))
        table.insert(lines, "Has GUI: " .. tostring(vim.fn.has("gui_running") == 1))

        if vim.fn.has("gui_running") == 1 then
          table.insert(lines, "GUI Font: " .. vim.opt.guifont:get())
        end

        -- Set buffer content
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

        -- Open in a new window
        vim.cmd("split")
        vim.api.nvim_win_set_buf(0, buf)

        print("Icon diagnostic test opened. Check the buffer for results.")
      end, { desc = "Test icon display and font configuration" })

      -- Create keymap
      vim.keymap.set('n', '<leader>di', '<cmd>IconTest<cr>', { desc = "Test Icons" })
    end,
  },
}
