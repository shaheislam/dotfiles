-- ~/.config/nvim/lua/plugins/git.lua
return {
  -- Disable LazyVim's default gitsigns since you don't want it
  { "lewis6991/gitsigns.nvim", enabled = false },

  -- Enhanced toggleterm with lazygit integration
  {
    "akinsho/toggleterm.nvim",
    opts = {
      size = 20,
      hide_numbers = true,
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = 'float',
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = 'curved',
        winblend = 0,
        highlights = {
          border = 'Normal',
          background = 'Normal',
        },
      },
    },
    keys = {
      { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
      -- Lazygit integration
      { "<leader>gg", function()
        local Terminal = require('toggleterm.terminal').Terminal
        local lazygit = Terminal:new({
          cmd = "lazygit",
          dir = "git_dir",
          direction = "float",
          float_opts = {
            border = "curved",
          },
          on_open = function(term)
            vim.cmd("startinsert!")
            vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
          end,
          on_close = function(term)
            vim.cmd("startinsert!")
          end,
        })
        lazygit:toggle()
      end, desc = "Lazygit" },
    },
  },

  -- Git fugitive (LazyVim includes this but we'll ensure our keymaps)
  {
    "tpope/vim-fugitive",
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "Git Status" },
      { "<leader>gp", "<cmd>Git push<cr>", desc = "Git Push" },
      { "<leader>gl", "<cmd>Git pull<cr>", desc = "Git Pull" },
      { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git Blame" },
    },
  },

  -- Ensure rhubarb for GitHub integration
  "tpope/vim-rhubarb",
}
