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
        ["<leader>f"] = {
          desc = "Fuzzy find files",
          callback = function()
            require("telescope.builtin").find_files({
              cwd = require("oil").get_current_dir()
            })
          end,
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
  "simnalamburt/vim-mundo",

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
  "psliwka/vim-smoothie",
  "tpope/vim-abolish",
  "tpope/vim-sleuth",
  "tpope/vim-surround",
  "tpope/vim-repeat",

  -- FZF integration
  {
    "junegunn/fzf",
    build = function()
      vim.fn['fzf#install']()
    end
  },
  "junegunn/fzf.vim",

  -- Custom search exclusions for Telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = {
            "node_modules",
            "^.git/",  -- Only ignore .git directory itself, not .github or .gitignore
            "dist",
            "build",
            "%.lock",
            "package%-lock%.json",
            "yarn%.lock",
            "%.log",
            "%.cache",
            "%.min%.js",
            "%.min%.css"
          },
          -- Enable multi-selection and better search
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            "--glob=!.git/*",
          },
        },
        pickers = {
          find_files = {
            -- Remove custom find_command to use default fuzzy finder
            hidden = true,
            -- Add these options for better search
            find_command = nil, -- Use default telescope finder
          },
          -- Enhanced git pickers configuration
          git_commits = {
            previewer = require("telescope.previewers").git_commit_diff_as_was.new({}),
            layout_config = {
              horizontal = {
                preview_width = 0.6,
              },
            },
          },
          git_bcommits = {
            previewer = require("telescope.previewers").git_commit_diff_as_was.new({}),
            layout_config = {
              horizontal = {
                preview_width = 0.6,
              },
            },
          },
          git_branches = {
            previewer = require("telescope.previewers").git_branch_log.new({}),
            -- Don't use dropdown theme with custom layout_config
          },
          git_status = {
            previewer = require("telescope.previewers").git_file_diff.new({}),
            layout_config = {
              horizontal = {
                preview_width = 0.6,
              },
            },
          },
        },
      })

      -- Load fzf extension for better fuzzy finding
      require("telescope").load_extension("fzf")
    end,
    keys = {
      -- Custom search exclusions
      { "<leader>fG", function()
        require("telescope.builtin").live_grep({
          additional_args = function()
            return {"--glob", "!*test*", "--glob", "!*spec*", "--glob", "!*.min.*"}
          end
        })
      end, desc = "Live Grep (No Tests)" },

      { "<leader>fF", function()
        require("telescope.builtin").find_files({
          hidden = true,
          no_ignore = false,
          follow = true,
        })
      end, desc = "Find Files (Custom)" },
    },
  },

  -- Macros
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      -- Add your custom which-key mappings
      if opts.spec then
        vim.list_extend(opts.spec, {
          { "<leader>fF", desc = "Find Files (Custom)" },
          { "<leader>fG", desc = "Live Grep (No Tests)" },
        })
      end
    end,
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    opts = {
      manual_mode = false,
      detection_methods = { "lsp", "pattern" },
      patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", "Cargo.toml" },
      show_hidden = false,
      silent_chdir = true,
    },
    event = "VeryLazy",
    config = function(_, opts)
      require("project_nvim").setup(opts)
      require("telescope").load_extension("projects")
    end,
    keys = {
      { "<leader>fp", "<cmd>Telescope projects<cr>", desc = "Projects" },
    },
  },

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
}
