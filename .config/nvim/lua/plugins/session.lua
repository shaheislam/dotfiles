-- ~/.config/nvim/lua/plugins/session.lua
-- Session management configuration using persistence.nvim
-- Extracted from misc.lua for better organization

return {
  -- Configure persistence.nvim for session management
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Stop Session" },
    },
  },
}
