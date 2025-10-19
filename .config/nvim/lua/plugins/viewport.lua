-- ~/.config/nvim/lua/plugins/viewport.lua
-- Smart window management with modal interface

return {
  {
    "chancez/viewport.nvim",
    lazy = false, -- Load immediately since we need setup
    config = function()
      local viewport = require("viewport")

      -- Setup viewport with both modes
      viewport.setup({
        resize_mode = {
          resize_amount = 2, -- Amount to resize by for each keypress
          mappings = {
            preset = "relative", -- Use relative mode for smart position-aware resizing
            -- In relative mode:
            -- h = shrink width (smart)
            -- l = grow width (smart)
            -- j = grow height (smart)
            -- k = shrink height (smart)
            -- <Esc> = exit resize mode
          },
        },
        navigate_mode = {
          mappings = {
            preset = "default", -- Use default navigation mappings
            -- Default mappings include:
            -- h/j/k/l = focus navigation
            -- H/J/K/L = swap windows
            -- s = select mode
            -- <Esc> = exit navigate mode
          },
        },
      })

      -- Set up keymaps
      vim.keymap.set('n', '<leader>wv', viewport.start_resize_mode, { desc = "Viewport Resize Mode" })
      vim.keymap.set('n', '<leader>wn', viewport.start_navigate_mode, { desc = "Viewport Navigate Mode" })
      vim.keymap.set('n', '<leader>ws', viewport.start_select_mode, { desc = "Viewport Select Mode" })
    end,
  },

  -- Add which-key integration for viewport menu
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      if opts.spec then
        vim.list_extend(opts.spec, {
          { "<leader>wv", desc = "Viewport Resize Mode" },
          { "<leader>wn", desc = "Viewport Navigate Mode" },
          { "<leader>ws", desc = "Viewport Select Mode" },
        })
      end
    end,
  },
}
