-- Ensure LazyVim default plugins are properly configured
return {
  -- ts-comments.nvim is included by default in newer LazyVim versions
  -- Let's explicitly configure it to make sure it's loaded
  {
    "folke/ts-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    enabled = true,
    opts = {},
  },

  -- persistence.nvim is included by default in LazyVim
  -- Let's explicitly ensure it's enabled with our preferred settings
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    enabled = true,
    opts = {
      dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"),
      options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
      pre_save = nil, -- a function to call before saving the session
      save_empty = false, -- don't save if there are no open file buffers
    },
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },
}