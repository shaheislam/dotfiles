-- ~/.config/nvim/lua/plugins/viewport.lua
-- Smart window management with modal interface

return {
  {
    "chancez/viewport.nvim",
    keys = {
      { "<leader>wv", function() require("viewport.resize").start() end, desc = "Viewport Resize Mode" },
      { "<leader>wn", function() require("viewport.navigate").start() end, desc = "Viewport Navigate Mode" },
    },
    config = function()
      -- Setup resize mode
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

      -- Setup navigate mode
      require("viewport.navigate").setup({
        mappings = {
          -- Focus navigation (move to window)
          ['h'] = require('viewport.navigate.actions').focus_left,
          ['j'] = require('viewport.navigate.actions').focus_below,
          ['k'] = require('viewport.navigate.actions').focus_above,
          ['l'] = require('viewport.navigate.actions').focus_right,
          -- Window swapping (swap and follow)
          ['H'] = require('viewport.navigate.actions').swap_left,
          ['J'] = require('viewport.navigate.actions').swap_below,
          ['K'] = require('viewport.navigate.actions').swap_above,
          ['L'] = require('viewport.navigate.actions').swap_right,
          -- Quick select with letter labels
          ['s'] = require('viewport.navigate.actions').select_mode,
          -- Exit navigate mode
          ['<Esc>'] = 'stop',
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
          { "<leader>wn", desc = "Viewport Navigate Mode" },
        })
      end
    end,
  },
}
