-- ~/.config/nvim/lua/plugins/git.lua
return {
  -- Gitsigns for visual git indicators and inline operations
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = '│' },
        change       = { text = '│' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
        untracked    = { text = '┆' },
      },
      signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
      numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
      linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
      word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
      watch_gitdir = {
        interval = 1000,
        follow_files = true
      },
      attach_to_untracked = true,
      current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
        delay = 1000,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil, -- Use default
      max_file_length = 40000, -- Disable if file is longer than this (in lines)
      preview_config = {
        -- Options passed to nvim_open_win
        border = 'single',
        style = 'minimal',
        relative = 'cursor',
        row = 0,
        col = 1
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation between hunks (]c and [c for next/previous change)
        map('n', ']c', function()
          if vim.wo.diff then return ']c' end
          vim.schedule(function() gs.next_hunk() end)
          return '<Ignore>'
        end, {expr=true, desc = "Next Git hunk"})

        map('n', '[c', function()
          if vim.wo.diff then return '[c' end
          vim.schedule(function() gs.prev_hunk() end)
          return '<Ignore>'
        end, {expr=true, desc = "Previous Git hunk"})

        -- Hunk actions (using <leader>h prefix to avoid conflicts with Neogit)
        map('n', '<leader>hs', gs.stage_hunk, { desc = "Stage hunk" })
        map('n', '<leader>hr', gs.reset_hunk, { desc = "Reset hunk" })
        map('v', '<leader>hs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = "Stage selected hunk" })
        map('v', '<leader>hr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = "Reset selected hunk" })
        map('n', '<leader>hS', gs.stage_buffer, { desc = "Stage buffer" })
        map('n', '<leader>hu', gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map('n', '<leader>hR', gs.reset_buffer, { desc = "Reset buffer" })
        map('n', '<leader>hp', gs.preview_hunk, { desc = "Preview hunk" })
        map('n', '<leader>hb', function() gs.blame_line{full=true} end, { desc = "Blame line (full)" })
        map('n', '<leader>hB', gs.toggle_current_line_blame, { desc = "Toggle blame line" })
        map('n', '<leader>hd', gs.diffthis, { desc = "Diff this" })
        map('n', '<leader>hD', function() gs.diffthis('~') end, { desc = "Diff this ~" })
        map('n', '<leader>ht', gs.toggle_deleted, { desc = "Toggle deleted" })

        -- Text object for hunks (ih = inner hunk, ah = around hunk)
        map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = "Select inner hunk" })
        map({'o', 'x'}, 'ah', ':<C-U>Gitsigns select_hunk<CR>', { desc = "Select around hunk" })
      end
    },
  },

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
      -- LazyDocker integration
      { "<leader>gd", function()
        local Terminal = require('toggleterm.terminal').Terminal
        local lazydocker = Terminal:new({
          cmd = "lazydocker",
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
        lazydocker:toggle()
      end, desc = "LazyDocker" },
    },
  },

  -- Neogit with floating window support
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("neogit").setup({
        -- Main window as floating
        kind = "floating",

        -- Configure floating window properties
        floating = {
          relative = "editor",
          width = 0.9,
          height = 0.8,
          style = "minimal",
          border = "rounded",
        },

        -- Commit editor configuration
        commit_editor = {
          kind = "floating",
          show_staged_diff = false,
          spell_check = false,
        },
        commit_view = {
          kind = "floating",
          verify_commit = false,
        },
        commit_popup = {
          kind = "floating",
        },
        editor = {
          kind = "floating",
        },

        -- Visual configuration
        signs = {
          section = { ">", "v" },
          item = { ">", "v" },
          hunk = { "", "" },
        },

        -- Integrations
        integrations = {
          telescope = true,
          diffview = true,
        },

        -- Graph style
        graph_style = "unicode",

        -- Additional settings
        disable_line_numbers = false,
        console_timeout = 5000,
        auto_show_console = false,
        disable_insert_on_commit = true,
        process = {
          silent = true,
        },
        notification_icon = "󰊢",
      })
    end,
    keys = {
      { "<leader>ng", "<cmd>Neogit<cr>", desc = "Neogit Status" },
      { "<leader>nc", "<cmd>Neogit kind=floating commit<cr>", desc = "Neogit Commit" },
      { "<leader>np", "<cmd>Neogit kind=floating push<cr>", desc = "Neogit Push" },
      { "<leader>nl", "<cmd>Neogit kind=floating pull<cr>", desc = "Neogit Pull" },
      { "<leader>nb", "<cmd>Neogit kind=floating branch<cr>", desc = "Neogit Branch" },
    },
  },

  -- Enable fugitive for :Git commands (works alongside Neogit)
  {
    "tpope/vim-fugitive",
    config = function()
      -- Create command abbreviation so :git expands to :Git
      vim.cmd([[
        " Command-line abbreviation for git -> Git
        cnoreabbrev <expr> git (getcmdtype() == ':' && getcmdline() =~ '^git$') ? 'Git' : 'git'
      ]])
    end,
  },
  
  -- Keep rhubarb for GitHub integration
  "tpope/vim-rhubarb",
}
