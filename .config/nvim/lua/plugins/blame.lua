return {
  {
    "f-person/git-blame.nvim",
    opts = {
      -- Show blame info in virtual text
      enabled = true,
      -- Format for the blame text
      date_format = "%Y-%m-%d %H:%M",
      -- Message when not in a git repo
      message_when_not_committed = "Not Committed Yet",
      -- Highlight group for virtual text
      highlight_group = "Comment",
      -- Display blame info in virtual text (not in status line)
      display_virtual_text = true,
      -- Delay before showing blame info (in milliseconds)
      delay = 500,
      -- Use relative time (e.g., "2 days ago")
      use_relative_time = true,
      -- Virtual text prefix
      virtual_text_prefix = " ■ ",
    },
    keys = {
      { "<leader>gbt", "<cmd>GitBlameToggle<cr>", desc = "Toggle Git Blame" },
      { "<leader>gB", "<cmd>GitBlameCopySHA<cr>", desc = "Copy Git Blame SHA" },
      { "<leader>go", "<cmd>GitBlameOpenCommitURL<cr>", desc = "Open Commit URL" },
    },
  },
}