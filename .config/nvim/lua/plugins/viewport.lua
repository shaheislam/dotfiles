-- ~/.config/nvim/lua/plugins/viewport.lua
-- Smart window resizing with modal interface

return {
  {
    "chancez/viewport.nvim",
    keys = {
      { "<leader>wv", function() require("viewport.resize").start() end, desc = "Viewport Resize Mode" },
    },
    config = function()
      require("viewport.resize").setup({
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
      })
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
        })
      end
    end,
  },
}
