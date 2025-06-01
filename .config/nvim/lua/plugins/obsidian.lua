-- ~/.config/nvim/lua/plugins/obsidian.lua
return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New Obsidian note", ft = "markdown" },
    { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian app", ft = "markdown" },
    { "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Show ObsidianBacklinks", ft = "markdown" },
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert Obsidian template", ft = "markdown" },
    { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search Obsidian notes", ft = "markdown" },
    { "<leader>oq", "<cmd>ObsidianQuickSwitch<cr>", desc = "Quick Switch", ft = "markdown" },
    { "<leader>ol", "<cmd>ObsidianLinks<cr>", desc = "Show ObsidianLinks", ft = "markdown" },
    { "<leader>of", "<cmd>ObsidianFollowLink<cr>", desc = "Follow link under cursor", ft = "markdown" },
    { "<leader>op", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image from clipboard", ft = "markdown" },
    { "<leader>or", "<cmd>ObsidianRename<cr>", desc = "Rename note", ft = "markdown" },
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/Documents/Obsidian Vault",
      },
    },
    completion = {
      nvim_cmp = false,
      min_chars = 2,
    },
    new_notes_location = "notes_subdir",
    wiki_link_func = "use_alias_only",
    preferred_link_style = "wiki",
    finder = "telescope.nvim",
    sort_by = "modified",
    sort_reversed = true,
    open_notes_in = "current",
    templates = {
      folder = "Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },
    ui = {
      enable = true,
    },
    mappings = {},
  },
}
