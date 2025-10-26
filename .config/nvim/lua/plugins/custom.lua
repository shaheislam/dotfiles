-- ~/.config/nvim/lua/plugins/custom.lua
return {
  -- Completely disable LazyVim's default file explorer (neo-tree)
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },

  -- Oil.nvim - Your preferred file browser with aggressive keybinding override
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false, -- Load immediately to override neo-tree
    cmd = { "Oil" }, -- Ensure Oil command is available from cmdline
    opts = {
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = false,
      view_options = {
        show_hidden = true,
        is_hidden_file = function(name, bufnr)
          return vim.startswith(name, ".")
        end,
      },
      float = {
        padding = 2,
        max_width = 0,
        max_height = 0,
        border = "rounded",
        win_options = {
          winblend = 0,
        },
      },
      keymaps = {
        -- Oil-specific fzf-lua mappings that use Oil's current directory
        ["<leader>ff"] = {
          function()
            require("fzf-lua").files({
              cwd = require("oil").get_current_dir(),
              prompt = "Find Files (Oil Directory)> ",
            })
          end,
          desc = "Find files in Oil directory",
        },
        ["<leader>fg"] = {
          function()
            require("fzf-lua").live_grep({
              cwd = require("oil").get_current_dir(),
              prompt = "Live Grep (Oil Directory)> ",
            })
          end,
          desc = "Live grep in Oil directory",
        },
      },
    },
    keys = {
      { "<leader>e", "<cmd>Oil<cr>", desc = "Open File Browser", mode = { "n", "v" } },
      { "<leader>fe", "<cmd>Oil<cr>", desc = "Open File Browser" },
    },
    init = function()
      -- Override any existing <leader>e mappings immediately
      vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open File Browser", silent = true })
    end,
    config = function(_, opts)
      require("oil").setup(opts)

      -- Create custom :Cd command that changes directory and opens oil
      vim.api.nvim_create_user_command("Cd", function(cmd_opts)
        local path = cmd_opts.args
        if path == "" then
          path = vim.fn.expand("~")
        end

        -- Expand path (handle ~, ., .., etc.)
        path = vim.fn.fnamemodify(path, ":p")

        -- Change directory
        vim.cmd("cd " .. vim.fn.fnameescape(path))

        -- Open oil in the new directory
        require("oil").open(path)
      end, {
        nargs = "?",
        complete = "dir",
        desc = "Change directory and open in Oil",
      })

      -- Make :cd automatically use our custom Cd command
      vim.cmd("cabbrev cd Cd")
    end,
  },


  -- Your custom clipboard/editing workflow
  {
    "svermeulen/vim-cutlass",
    config = function()
      -- vim-cutlass using 'm' for cut (Separate cut and delete)
      vim.keymap.set('n', 'm', 'd')
      vim.keymap.set('x', 'm', 'd')
      vim.keymap.set('n', 'mm', 'dd')
      vim.keymap.set('n', 'M', 'D')
    end,
  },

  {
    "svermeulen/vim-yoink",
    dependencies = { "svermeulen/vim-cutlass" },
    config = function()
      -- Enable delete operations to be added to yank history when using cutlass
      vim.g.yoinkIncludeDeleteOperations = 1

      -- vim-yoink mappings
      vim.keymap.set('n', 'p', '<plug>(YoinkPaste_p)')
      vim.keymap.set('n', 'P', '<plug>(YoinkPaste_P)')
      vim.keymap.set('n', '<c-n>', '<plug>(YoinkPostPasteSwapBack)')
      vim.keymap.set('n', '<c-p>', '<plug>(YoinkPostPasteSwapForward)')
    end,
  },

  -- vim-subversive removed - was causing treesitter query errors
  -- Use LazyVim's built-in substitute features instead

  -- Additional plugins you had that aren't in LazyVim
  "inkarkat/vim-ingo-library",
  "inkarkat/vim-ReplaceWithRegister",
  "inkarkat/vim-ReplaceWithSameIndentRegister",
  "inkarkat/vim-visualrepeat",
  "christoomey/vim-sort-motion",
  "junegunn/vim-peekaboo",
  "tpope/vim-rsi",

  -- Missing plugins from your original config
  -- "ap/vim-css-color", -- Disabled: causing E121 errors with undefined b:css_color_pat

  -- Modern CSS color highlighter replacement
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      filetypes = { "*" },
      user_default_options = {
        RGB = true,
        RRGGBB = true,
        names = true,
        RRGGBBAA = true,
        AARRGGBB = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
        mode = "background",
        tailwind = true,
        virtualtext = "■",
      },
    },
  },

  "junegunn/rainbow_parentheses.vim",
  "michaeljsmith/vim-indent-object",
  "nathanaelkane/vim-indent-guides",
  "tpope/vim-abolish",
  "tpope/vim-sleuth",
  "tpope/vim-surround",
  "tpope/vim-repeat",

  -- FZF integration (legacy compatibility)
  {
    "junegunn/fzf",
    build = function()
      vim.fn['fzf#install']()
    end
  },
  "junegunn/fzf.vim",

  -- Kai-Neovim Claude AI Integration (disabled - missing config)
  -- {
  --   dir = vim.fn.stdpath("config") .. "/lua/config",
  --   name = "kai-neovim",
  --   lazy = false,
  --   config = function()
  --     require("config.kai-neovim").setup()
  --   end,
  --   keys = {
  --     { "<leader>ai", mode = { "n", "v" }, desc = "Kai AI Assistant (Claude)" }
  --   },
  -- },

  -- Octo.nvim - GitHub integration for issues, PRs, and code reviews
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>gi", "<cmd>Octo issue list<cr>", desc = "List Issues" },
      { "<leader>gp", "<cmd>Octo pr list<cr>", desc = "List PRs" },
      { "<leader>gc", "<cmd>Octo pr create<cr>", desc = "Create PR" },
      { "<leader>gr", "<cmd>Octo review start<cr>", desc = "Start Review" },
    },
    opts = {
      enable_builtin = true,
      default_remote = {"upstream", "origin"},
      default_merge_method = "squash",
      picker = "telescope",
      use_local_fs = false,
      github_hostname = "github.com",
      ssh_aliases = {
        ["github.com-personal"] = "github.com",
        ["github.com-dfe"] = "github.com",
      },
      suppress_missing_scope = {
        projects_v2 = true,
      },
      mappings = {
        issue = {
          close_issue = { lhs = "<space>ic", desc = "close issue" },
          reopen_issue = { lhs = "<space>io", desc = "reopen issue" },
          list_issues = { lhs = "<space>il", desc = "list open issues" },
          reload = { lhs = "<C-r>", desc = "reload issue" },
          open_in_browser = { lhs = "<C-b>", desc = "open in browser" },
          copy_url = { lhs = "<C-y>", desc = "copy url" },
          add_assignee = { lhs = "<space>aa", desc = "add assignee" },
          remove_assignee = { lhs = "<space>ad", desc = "remove assignee" },
          create_label = { lhs = "<space>lc", desc = "create label" },
          add_label = { lhs = "<space>la", desc = "add label" },
          remove_label = { lhs = "<space>ld", desc = "remove label" },
          goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
          add_comment = { lhs = "<space>ca", desc = "add comment" },
          delete_comment = { lhs = "<space>cd", desc = "delete comment" },
          next_comment = { lhs = "]c", desc = "go to next comment" },
          prev_comment = { lhs = "[c", desc = "go to previous comment" },
          react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
          react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
          react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
          react_thumbsup = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
          react_thumbsdown = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
          react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
          react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
          react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
        },
        pull_request = {
          checkout_pr = { lhs = "<space>po", desc = "checkout PR" },
          merge_pr = { lhs = "<space>pm", desc = "merge commit PR" },
          squash_and_merge_pr = { lhs = "<space>psm", desc = "squash and merge PR" },
          list_commits = { lhs = "<space>pc", desc = "list PR commits" },
          list_changed_files = { lhs = "<space>pf", desc = "list PR changed files" },
          show_pr_diff = { lhs = "<space>pd", desc = "show PR diff" },
          add_reviewer = { lhs = "<space>va", desc = "add reviewer" },
          remove_reviewer = { lhs = "<space>vd", desc = "remove reviewer" },
          close_issue = { lhs = "<space>ic", desc = "close PR" },
          reopen_issue = { lhs = "<space>io", desc = "reopen PR" },
          list_issues = { lhs = "<space>il", desc = "list open issues" },
          reload = { lhs = "<C-r>", desc = "reload PR" },
          open_in_browser = { lhs = "<C-b>", desc = "open in browser" },
          copy_url = { lhs = "<C-y>", desc = "copy url" },
          goto_file = { lhs = "gf", desc = "go to file" },
          add_assignee = { lhs = "<space>aa", desc = "add assignee" },
          remove_assignee = { lhs = "<space>ad", desc = "remove assignee" },
          create_label = { lhs = "<space>lc", desc = "create label" },
          add_label = { lhs = "<space>la", desc = "add label" },
          remove_label = { lhs = "<space>ld", desc = "remove label" },
          goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
          add_comment = { lhs = "<space>ca", desc = "add comment" },
          delete_comment = { lhs = "<space>cd", desc = "delete comment" },
          next_comment = { lhs = "]c", desc = "go to next comment" },
          prev_comment = { lhs = "[c", desc = "go to previous comment" },
          react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
          react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
          react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
          react_thumbsup = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
          react_thumbsdown = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
          react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
          react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
          react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
        },
        review_thread = {
          goto_issue = { lhs = "<space>gi", desc = "navigate to a local repo issue" },
          add_comment = { lhs = "<space>ca", desc = "add comment" },
          add_suggestion = { lhs = "<space>sa", desc = "add suggestion" },
          delete_comment = { lhs = "<space>cd", desc = "delete comment" },
          next_comment = { lhs = "]c", desc = "go to next comment" },
          prev_comment = { lhs = "[c", desc = "go to previous comment" },
          select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
          select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
          close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
          react_hooray = { lhs = "<space>rp", desc = "add/remove 🎉 reaction" },
          react_heart = { lhs = "<space>rh", desc = "add/remove ❤️ reaction" },
          react_eyes = { lhs = "<space>re", desc = "add/remove 👀 reaction" },
          react_thumbsup = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
          react_thumbsdown = { lhs = "<space>r-", desc = "add/remove 👎 reaction" },
          react_rocket = { lhs = "<space>rr", desc = "add/remove 🚀 reaction" },
          react_laugh = { lhs = "<space>rl", desc = "add/remove 😄 reaction" },
          react_confused = { lhs = "<space>rc", desc = "add/remove 😕 reaction" },
        },
        submit_win = {
          approve_review = { lhs = "<C-a>", desc = "approve review" },
          comment_review = { lhs = "<C-m>", desc = "comment review" },
          request_changes = { lhs = "<C-r>", desc = "request changes review" },
          close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
        },
        review_diff = {
          add_review_comment = { lhs = "<space>ca", desc = "add a new review comment" },
          add_review_suggestion = { lhs = "<space>sa", desc = "add a new review suggestion" },
          focus_files = { lhs = "<leader>e", desc = "move focus to changed file panel" },
          toggle_files = { lhs = "<leader>b", desc = "hide/show changed files panel" },
          next_thread = { lhs = "]t", desc = "move to next thread" },
          prev_thread = { lhs = "[t", desc = "move to previous thread" },
          select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
          select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
          close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
          toggle_viewed = { lhs = "<leader><space>", desc = "toggle viewer viewed state" },
          goto_file = { lhs = "gf", desc = "go to file" },
        },
        file_panel = {
          next_entry = { lhs = "j", desc = "move to next changed file" },
          prev_entry = { lhs = "k", desc = "move to previous changed file" },
          select_entry = { lhs = "<cr>", desc = "show selected changed file diffs" },
          refresh_files = { lhs = "R", desc = "refresh changed files panel" },
          focus_files = { lhs = "<leader>e", desc = "move focus to changed file panel" },
          toggle_files = { lhs = "<leader>b", desc = "hide/show changed files panel" },
          select_next_entry = { lhs = "]q", desc = "move to previous changed file" },
          select_prev_entry = { lhs = "[q", desc = "move to next changed file" },
          close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
          toggle_viewed = { lhs = "<leader><space>", desc = "toggle viewer viewed state" },
        },
      },
    },
  },
}
