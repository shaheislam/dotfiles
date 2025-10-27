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
    },
    keys = {
      { "<leader>sl", function() require("nvim-possession").list() end, desc = "List sessions" },
      { "<leader>sn", function() require("nvim-possession").new() end, desc = "New session" },
      { "<leader>su", function() require("nvim-possession").update() end, desc = "Update session" },
      { "<leader>sd", function() require("nvim-possession").delete() end, desc = "Delete session" },
    },
  },
}
