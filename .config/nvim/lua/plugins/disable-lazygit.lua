-- Disable LazyGit integration completely
return {
  -- Configure Snacks to disable lazygit
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        enabled = false, -- Disable lazygit integration
      },
    },
    -- Override the lazygit keymaps specifically
    keys = {
      { "<leader>gg", false },
      { "<leader>gG", false },
      { "<leader>gf", false }, -- Disable default git files if Snacks sets it
      { "<leader>gF", false }, -- Disable any other git file variants
      { "<leader>gL", false },
      { "<leader>gB", false },
    },
  },
}