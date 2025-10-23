-- ~/.config/nvim/lua/plugins/utilities.lua
-- Miscellaneous utility plugins
-- Extracted from misc.lua for better organization

return {
  -- Set up macros and other miscellaneous configurations
  {
    "folke/lazy.nvim",
    config = function()
      -- Your custom macro
      vim.fn.setreg('f', '0cwfixup\\<Esc>j')
    end,
  },

  -- Better lazy loading for rarely used plugins
  {
    "junegunn/vim-peekaboo",
    event = "VeryLazy",
  },
  {
    "easymotion/vim-easymotion",
    keys = "<leader><leader>", -- Only load when actually using easymotion
  },
  {
    "simnalamburt/vim-mundo",
    cmd = { "MundoToggle", "MundoShow" },
    keys = { { "<leader>U", "<cmd>MundoToggle<cr>", desc = "Undo Tree" } },
  },
}
