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
    },
  },
}