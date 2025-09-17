-- Netman.nvim test configuration
-- Test plugin for remote file management

return {
  {
    "miversen33/netman.nvim",
    lazy = false, -- Load immediately for testing
    config = function()
      require("netman").setup({
        -- Enable debug logging to see what's happening
        log_level = 2, -- 0 = TRACE, 1 = DEBUG, 2 = INFO, 3 = WARN, 4 = ERROR
      })

      -- Optional: Add keymaps for quick testing
      vim.keymap.set('n', '<leader>nm', ':Nmread ', { desc = "Netman Read" })
      vim.keymap.set('n', '<leader>nw', ':Nmwrite ', { desc = "Netman Write" })
      vim.keymap.set('n', '<leader>nd', ':Nmdelete ', { desc = "Netman Delete" })

      -- Show loaded providers
      vim.keymap.set('n', '<leader>nl', function()
        vim.notify("Netman providers loaded. Check :messages for details")
        vim.cmd('messages')
      end, { desc = "Show Netman status" })
    end,
    dependencies = {
      -- Optional: Neo-tree integration for file browsing
      {
        "nvim-neo-tree/neo-tree.nvim",
        optional = true,
        opts = function(_, opts)
          opts.sources = opts.sources or {}
          table.insert(opts.sources, "netman.ui.neo-tree")
          return opts
        end,
      },
    },
  },
}