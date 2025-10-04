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
          -- Layout configuration
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              preview_width = 0.6,
              preview_cutoff = 120,
            },
            vertical = {
              preview_height = 0.5,
            },
            width = 0.9,
            height = 0.9,
          },
          -- Ensure syntax highlighting in previews
          preview = {
            treesitter = true,
            syntax = true,
          },
        },
        pickers = {
          find_files = {
            -- Remove custom find_command to use default fuzzy finder
            hidden = true,
            -- Add these options for better search
            find_command = nil, -- Use default telescope finder
          },
          -- Git picker specific configurations
          git_commits = {
            layout_config = {
              preview_width = 0.7,
            },
          },
          git_bcommits = {
            layout_config = {
              preview_width = 0.7,
            },
          },
          git_branches = {
            layout_config = {
              preview_width = 0.6,
            },
            show_remote_tracking_branches = false,
          },
          git_status = {
            layout_config = {
              preview_width = 0.6,
            },
          },
          git_stash = {
            layout_config = {
              preview_width = 0.7,
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

  -- Telescope-zoxide integration with oil.nvim
  {
    "jvgrootveld/telescope-zoxide",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "stevearc/oil.nvim",
    },
    config = function()
      require("telescope").load_extension("zoxide")
    end,
    keys = {
      -- Zoxide jump that changes pwd AND opens oil.nvim
      { "<leader>cd", function()
        require("telescope").extensions.zoxide.list({
          attach_mappings = function(_, map)
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")

            -- Override enter to change directory AND open oil
            map("i", "<CR>", function(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if selection and selection.path then
                -- Change working directory first
                vim.cmd("cd " .. vim.fn.fnameescape(selection.path))
                -- Then open oil in that directory
                require("oil").open(selection.path)
              end
            end)

            -- Also map for normal mode
            map("n", "<CR>", function(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if selection and selection.path then
                -- Change working directory first
                vim.cmd("cd " .. vim.fn.fnameescape(selection.path))
                -- Then open oil in that directory
                require("oil").open(selection.path)
              end
            end)

            return true
          end,
        })
      end, desc = "Zoxide jump to Oil" },

      -- Alternative: Zoxide with default behavior (changes cwd)
      { "<leader>cD", "<cmd>Telescope zoxide list<cr>", desc = "Zoxide jump (default)" },
    },
  },

  -- Telescope undo removed - using Snacks undo instead
  -- Snacks provides undo functionality through the snacks_picker extra
  -- Access it with <leader>su (default LazyVim binding)

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

  -- Window resize mode for easier split resizing
  {
    "Dimfred/resize-mode.nvim",
    keys = {
      { "<leader>wr", function() require("resize-mode").start() end, desc = "Resize Mode" },
    },
    opts = {
      horizontal_amount = 3,  -- resize amount for h/l
      vertical_amount = 2,    -- resize amount for j/k
      quit_key = "<ESC>",
      enable_mapping = true,
      resize_keys = {
        "h", "j", "k", "l",   -- increase left/down/up/right
        "H", "J", "K", "L",   -- decrease left/down/up/right
      },
      hooks = {
        on_enter = function()
          vim.notify("Resize Mode", vim.log.levels.INFO)
        end,
      },
    },
  },
}
