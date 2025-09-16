return {
  {
    "chipsenkbeil/distant.nvim",
    branch = "main",  -- Use main branch for latest compatibility
    lazy = true,     -- Load on demand to avoid early loading issues
    config = function()
      -- Simple setup with minimal configuration
      local ok, distant = pcall(require, "distant")
      if not ok then
        vim.notify("Failed to load distant.nvim", vim.log.levels.ERROR)
        return
      end

      -- Use simple default setup without non-existent settings module
      distant:setup()
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