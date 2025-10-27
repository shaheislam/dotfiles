-- ~/.config/nvim/lua/plugins/session.lua
-- Session management configuration using nvim-possession
-- Extracted from misc.lua for better organization

return {
  -- Configure nvim-possession for session management
  {
    "gennaro-tedesco/nvim-possession",
    dependencies = {
      "ibhagwan/fzf-lua",
    },
    opts = {
      autoload = false, -- don't auto-load sessions on startup
      autosave = true,  -- auto-save loaded sessions before quitting
      autoswitch = {
        enable = false, -- don't auto-switch sessions on directory change
      },
      sessions = {
        sessions_icon = "📌 ", -- icon shown in prompt and statusline
        sessions_prompt = "Sessions: ", -- fzf prompt text
      },
      -- Clean up invalid buffers before saving session
      save_hook = function()
        -- Delete invalid/unloaded buffers before saving
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end
        end
      end,
      -- Clean up invalid buffers after loading session
      post_hook = function()
        -- Delete invalid/unloaded buffers
        vim.schedule(function()
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(bufnr) and not vim.api.nvim_buf_is_loaded(bufnr) then
              pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end
          end
        end)
      end,
      -- Configure fzf-lua window for better display
      fzf_winopts = {
        width = 0.8,  -- 80% width instead of default 50%
        height = 0.6, -- 60% height
        preview = {
          layout = "vertical",
          vertical = "down:45%", -- preview takes 45% of height
        },
        border = "rounded",
      },
      -- Highlight groups for better visuals
      fzf_hls = {
        normal = "Normal",
        preview_normal = "Normal",
        border = "FloatBorder",
        preview_border = "FloatBorder",
      },
    },
    keys = {
      { "<leader>ssl", function() require("nvim-possession").list() end, desc = "List sessions" },
      { "<leader>ssn", function() require("nvim-possession").new() end, desc = "New session" },
      { "<leader>ssu", function() require("nvim-possession").update() end, desc = "Update session" },
      { "<leader>ssd", function() require("nvim-possession").delete() end, desc = "Delete session" },
    },
  },
}
