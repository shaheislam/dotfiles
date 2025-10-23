-- ~/.config/nvim/lua/plugins/search-replace.lua
-- Search and replace configuration using nvim-spectre
-- Extracted from misc.lua for better organization

return {
  -- Configure nvim-spectre for search and replace
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>sr", function() require("spectre").toggle() end, desc = "Search and Replace" },
    },
    opts = {},
  },
}
