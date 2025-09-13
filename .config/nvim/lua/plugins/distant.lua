return {
  {
    "chipsenkbeil/distant.nvim",
    branch = "v0.3",
    lazy = false,  -- Load immediately
    priority = 1000,  -- Load early
    config = function()
      require("distant"):setup()
    end,
    cmd = {
      "DistantInstall",
      "DistantConnect",
      "DistantOpen",
      "DistantShell",
      "DistantSearch",
      "DistantSessionInfo",
      "DistantLaunch",
      "DistantCopy",
      "DistantRename",
      "DistantRemove",
      "DistantMkdir",
    },
    -- Key mappings
    keys = {
      { "<leader>dc", "<cmd>DistantConnect<cr>", desc = "Connect to remote server" },
      { "<leader>do", "<cmd>DistantOpen<cr>", desc = "Open remote file/directory" },
      { "<leader>ds", "<cmd>DistantShell<cr>", desc = "Open remote shell" },
      { "<leader>dS", "<cmd>DistantSearch<cr>", desc = "Search remote files" },
      { "<leader>di", "<cmd>DistantSessionInfo<cr>", desc = "Show session info" },
    },
  },
}