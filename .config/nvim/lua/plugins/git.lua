-- ~/.config/nvim/lua/plugins/git.lua
return {
  -- Gitsigns for visual git indicators and inline operations
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      -- Telescope git integration keybindings with enhanced configuration
      { "<leader>gf", "<cmd>Telescope git_files<cr>", desc = "Git files" },

      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git commits" },

      { "<leader>gC", "<cmd>Telescope git_bcommits<cr>", desc = "Git buffer commits" },

      { "<leader>gb", function()
        local actions = require("telescope.actions")
        require("telescope.builtin").git_branches({
          attach_mappings = function(_, map)
            -- Custom branch switching with stash handling
            local switch_branch = function(prompt_bufnr)
              local selection = require("telescope.actions.state").get_selected_entry()
              if selection == nil then
                return
              end

              actions.close(prompt_bufnr)
              local branch = selection.value

              -- Check for uncommitted changes
              local has_changes = vim.fn.system("git status --porcelain"):match("%S")

              if has_changes then
                local choice = vim.fn.confirm(
                  "You have uncommitted changes. What would you like to do?",
                  "&Stash and switch\n&Cancel",
                  1
                )

                if choice == 1 then
                  -- Stash changes with a descriptive message
                  local stash_msg = string.format("WIP on %s before switching to %s",
                    vim.fn.system("git branch --show-current"):gsub("\n", ""),
                    branch)
                  vim.fn.system(string.format("git stash push -m '%s'", stash_msg))
                  vim.notify("Changes stashed: " .. stash_msg, vim.log.levels.INFO)

                  -- Now switch branch
                  local result = vim.fn.system(string.format("git checkout %s", branch))
                  if vim.v.shell_error == 0 then
                    vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                  end
                end
              else
                -- No changes, switch directly
                local result = vim.fn.system(string.format("git checkout %s", branch))
                if vim.v.shell_error == 0 then
                  vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                else
                  vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                end
              end
            end

            map("i", "<cr>", switch_branch)
            map("n", "<cr>", switch_branch)
            return true
          end,
        })
      end, desc = "Git branches (smart checkout)" },

      { "<leader>gs", function()
        require("telescope.builtin").git_status({
          previewer = require("telescope.previewers").git_file_diff.new({}),
        })
      end, desc = "Git status" },

      { "<leader>gS", "<cmd>Telescope git_stash<cr>", desc = "Git stash" },

      -- Additional git shortcuts
      { "<leader>gB", function()
        local actions = require("telescope.actions")
        require("telescope.builtin").git_branches({
          show_remote_tracking_branches = true,
          attach_mappings = function(_, map)
            -- Use the same smart branch switcher for remote branches
            local switch_branch = function(prompt_bufnr)
              local selection = require("telescope.actions.state").get_selected_entry()
              if selection == nil then
                return
              end

              actions.close(prompt_bufnr)
              local branch = selection.value

              -- Check for uncommitted changes
              local has_changes = vim.fn.system("git status --porcelain"):match("%S")

              if has_changes then
                local choice = vim.fn.confirm(
                  "You have uncommitted changes. What would you like to do?",
                  "&Stash and switch\n&Cancel",
                  1
                )

                if choice == 1 then
                  -- Stash changes with a descriptive message
                  local stash_msg = string.format("WIP on %s before switching to %s",
                    vim.fn.system("git branch --show-current"):gsub("\n", ""),
                    branch)
                  vim.fn.system(string.format("git stash push -m '%s'", stash_msg))
                  vim.notify("Changes stashed: " .. stash_msg, vim.log.levels.INFO)

                  -- Now switch branch
                  local result = vim.fn.system(string.format("git checkout %s", branch))
                  if vim.v.shell_error == 0 then
                    vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                  end
                end
              else
                -- No changes, switch directly
                local result = vim.fn.system(string.format("git checkout %s", branch))
                if vim.v.shell_error == 0 then
                  vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                else
                  vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                end
              end
            end

            map("i", "<cr>", switch_branch)
            map("n", "<cr>", switch_branch)
            return true
          end,
        })
      end, desc = "Git branches (with remote)" },

      { "<leader>gl", "<cmd>Telescope git_commits<cr>", desc = "Git log" },

      { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Git status" },
      { "<leader>gS", "<cmd>Telescope git_stash<cr>", desc = "Git stash" },
    },
    config = function()
      require('gitsigns').setup({
        signs = {
          add          = { text = '│' },
          change       = { text = '│' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        -- Staged signs configuration (shows different signs for staged changes)
        signs_staged = {
          add          = { text = '▎' },  -- Left thick bar for staged adds
          change       = { text = '▎' },  -- Left thick bar for staged changes
          delete       = { text = '▸' },  -- Triangle for staged deletions
          topdelete    = { text = '▾' },  -- Down triangle for staged top deletions
          changedelete = { text = '▊' },  -- Block for staged change+delete
        },
        signs_staged_enable = true,  -- Enable staged signs display
        numhl      = true,  -- Line number highlighting
        linehl     = false,  -- No line background highlighting
        word_diff  = true,  -- Word-level diff
        max_file_length = 40000,  -- Support word diff on larger files

        -- Current line blame in virtual text
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
          delay = 1000,
          ignore_whitespace = false,
          virt_text_priority = 100,
        },
        current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',

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

        -- Toggle highlighting features
        map('n', '<leader>hn', gs.toggle_numhl, { desc = "Toggle line number highlighting" })
        map('n', '<leader>hl', gs.toggle_linehl, { desc = "Toggle line highlighting" })
        map('n', '<leader>hw', gs.toggle_word_diff, { desc = "Toggle word diff" })
        map('n', '<leader>hg', gs.toggle_signs, { desc = "Toggle git signs" })

        -- Quickfix/Location list integration
        map('n', '<leader>hq', function() gs.setqflist() end, { desc = "Send all hunks to quickfix" })
        map('n', '<leader>hQ', function() gs.setqflist('all') end, { desc = "Send hunks from all buffers to quickfix" })
        map('n', '<leader>hL', function() gs.setloclist() end, { desc = "Send hunks to location list" })

        -- Note: gitsigns doesn't have a general actions picker
        -- All actions are available through individual keybindings above

          -- Text object for hunks
          map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = "Select hunk" })
        end
      })

      -- Set word diff highlights
      vim.api.nvim_set_hl(0, 'GitSignsChangeInline', { fg = '#ffdb69', bg = '#3a3a2a' })
      vim.api.nvim_set_hl(0, 'GitSignsChangeLnInline', { fg = '#ffdb69', bg = '#3a3a2a' })
      vim.api.nvim_set_hl(0, 'GitSignsAddInline', { fg = '#9ece6a', bg = '#1f2231' })
      vim.api.nvim_set_hl(0, 'GitSignsAddLnInline', { fg = '#9ece6a', bg = '#1f2231' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteInline', { fg = '#f7768e', bg = '#2d202a' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteLnInline', { fg = '#f7768e', bg = '#2d202a' })

      -- Set staged signs highlights - muted but distinct colors
      vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { fg = '#73c991', bold = true })           -- Soft mint green for staged adds
      vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { fg = '#e0af68', bold = true })        -- Soft amber for staged changes
      vim.api.nvim_set_hl(0, 'GitSignsStagedDelete', { fg = '#bb7a8c', bold = true })        -- Dusty rose for staged deletes
      vim.api.nvim_set_hl(0, 'GitSignsStagedTopdelete', { fg = '#bb7a8c', bold = true })     -- Dusty rose for staged topdeletes
      vim.api.nvim_set_hl(0, 'GitSignsStagedChangedelete', { fg = '#c8917a', bold = true })  -- Soft terracotta for staged changedeletes
      vim.api.nvim_set_hl(0, 'GitSignsStagedAddNr', { fg = '#73c991', bold = true })         -- Soft mint green for line numbers
      vim.api.nvim_set_hl(0, 'GitSignsStagedChangeNr', { fg = '#e0af68', bold = true })      -- Soft amber for line numbers
      vim.api.nvim_set_hl(0, 'GitSignsStagedDeleteNr', { fg = '#bb7a8c', bold = true })      -- Dusty rose for line numbers

      -- Also set in ColorScheme autocmd for persistence
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, 'GitSignsChangeInline', { fg = '#ffdb69', bg = '#3a3a2a' })
          vim.api.nvim_set_hl(0, 'GitSignsChangeLnInline', { fg = '#ffdb69', bg = '#3a3a2a' })
          vim.api.nvim_set_hl(0, 'GitSignsAddInline', { fg = '#9ece6a', bg = '#1f2231' })
          vim.api.nvim_set_hl(0, 'GitSignsAddLnInline', { fg = '#9ece6a', bg = '#1f2231' })
          vim.api.nvim_set_hl(0, 'GitSignsDeleteInline', { fg = '#f7768e', bg = '#2d202a' })
          vim.api.nvim_set_hl(0, 'GitSignsDeleteLnInline', { fg = '#f7768e', bg = '#2d202a' })

          -- Staged signs highlights
          vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { fg = '#73c991', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { fg = '#e0af68', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedDelete', { fg = '#bb7a8c', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedTopdelete', { fg = '#bb7a8c', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedChangedelete', { fg = '#c8917a', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedAddNr', { fg = '#73c991', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedChangeNr', { fg = '#e0af68', bold = true })
          vim.api.nvim_set_hl(0, 'GitSignsStagedDeleteNr', { fg = '#bb7a8c', bold = true })
        end
      })
    end,
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
