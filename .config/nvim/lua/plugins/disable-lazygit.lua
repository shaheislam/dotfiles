-- Disable LazyGit integration completely
return {
  -- Disable LazyGit keymaps from LazyVim
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Remove LazyGit keymaps
      vim.keymap.del("n", "<leader>gg", { silent = true })
      vim.keymap.del("n", "<leader>gG", { silent = true })

      -- Alternative: you can remap these to something else if you prefer
      -- vim.keymap.set("n", "<leader>gg", "<cmd>Git<cr>", { desc = "Git status (fugitive)" })
    end,
  },

  -- Configure Snacks to disable lazygit
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        enabled = false, -- Disable lazygit integration
      },
    },
  },

  -- Remove toggleterm's lazygit integration if you have it
  {
    "akinsho/toggleterm.nvim",
    opts = function(_, opts)
      -- Remove any lazygit terminal configurations
      if opts.terminals then
        opts.terminals = vim.tbl_filter(function(term)
          return not (term.cmd and term.cmd:match("lazygit"))
        end, opts.terminals or {})
      end
      return opts
    end,
  },
}