-- ~/.config/nvim/lua/plugins/misc.lua
return {
  -- Catppuccin Mocha theme (available for toggling)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 999,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = false,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
        },
        which_key = true,
        indent_blankline = {
          enabled = true,
          scope_color = "",
          colored_indent_levels = false,
        },
        dashboard = true,
        neotree = true,
        noice = true,
        hop = false,
        markdown = true,
        mason = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
    end,
  },

  -- OneDark theme (default theme)
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000, -- Highest priority to load as default
    opts = {
      style = 'dark',
      transparent = true, -- Match catppuccin transparency
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,
      code_style = {
        comments = 'italic',
        keywords = 'none',
        functions = 'none',
        strings = 'none',
        variables = 'none'
      },
    },
    config = function(_, opts)
      require("onedark").setup(opts)
      vim.cmd([[colorscheme onedark]])
    end,
  },

  -- Tokyo Night Storm theme (third theme for cycling)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 998,
    opts = {
      style = "storm",
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
      },
    },
  },

  -- Kanagawa theme - Japanese art inspired
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 997,
    opts = {
      transparent = true,
      terminal_colors = true,
      colors = {
        theme = {
          all = {
            ui = {
              bg_gutter = "none"
            }
          }
        }
      },
    },
  },

  -- Rose Pine theme - Elegant warm palette
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 996,
    opts = {
      variant = "main", -- main, moon, or dawn
      dark_variant = "main",
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      styles = {
        bold = true,
        italic = true,
        transparency = true,
      },
    },
  },

  -- Nightfox theme - Multiple variants
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 995,
    opts = {
      options = {
        transparent = true,
        terminal_colors = true,
        dim_inactive = false,
        styles = {
          comments = "italic",
          keywords = "bold",
          types = "italic,bold",
        },
      },
    },
  },

  -- Gruvbox Material theme - Modern Gruvbox
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 994,
    config = function()
      vim.g.gruvbox_material_background = "medium" -- soft, medium, hard
      vim.g.gruvbox_material_transparent_background = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_enable_bold = 1
    end,
  },

  -- Everforest theme - Comfortable green forest
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 993,
    config = function()
      vim.g.everforest_background = "medium" -- hard, medium, soft
      vim.g.everforest_transparent_background = 1
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_better_performance = 1
    end,
  },

  -- GitHub theme - GitHub's color schemes
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 992,
    config = function()
      require("github-theme").setup({
        options = {
          transparent = true,
          terminal_colors = true,
          dim_inactive = false,
          styles = {
            comments = "italic",
            keywords = "bold",
            types = "italic,bold",
          },
        },
      })
    end,
  },

  -- Cyberdream theme - Modern cyberpunk aesthetic
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 991,
    opts = {
      transparent = true,
      italic_comments = true,
      hide_fillchars = true,
      borderless_telescope = true,
    },
  },

  -- Nord theme - Arctic bluish theme
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 990,
    config = function()
      vim.g.nord_contrast = true
      vim.g.nord_borders = false
      vim.g.nord_disable_background = true -- Transparent background
      vim.g.nord_italic = true
      vim.g.nord_bold = false
    end,
  },

  -- Terraform support (autocmd for .tf files)
  {
    "hashivim/vim-terraform",
    ft = "terraform",
    config = function()
      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.tf',
        callback = function()
          vim.bo.filetype = 'terraform'
        end,
      })
    end,
  },

  -- Configure conform.nvim (LazyVim includes this but we'll add your formatters)
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        formatters_by_ft = {
          lua = { 'stylua' },
          python = { 'ruff_organize_imports', 'ruff_format' }, -- Use ruff for both import sorting and formatting
          javascript = { 'prettierd', 'prettier', stop_after_first = true },
          typescript = { 'prettierd', 'prettier', stop_after_first = true },
          json = { 'prettierd', 'prettier', stop_after_first = true },
          yaml = { 'prettierd', 'prettier', stop_after_first = true },
          terraform = { 'terraform_fmt' },
          go = { 'goimports', 'gofmt' },
          rust = { 'rustfmt' },
          markdown = { 'prettierd', 'prettier', stop_after_first = true },
        },
      })
    end,
  },

  -- Configure persistence.nvim for session management
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Stop Session" },
    },
  },

  -- Configure nvim-spectre for search and replace
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>sr", function() require("spectre").toggle() end, desc = "Search and Replace" },
    },
    opts = {},
  },

  -- Set up macros and other miscellaneous configurations
  {
    "folke/lazy.nvim",
    config = function()
      -- Your custom macro
      vim.fn.setreg('f', '0cwfixup\\<Esc>j')
    end,
  },

  -- Better lazy loading for rarely used plugins
  {
    "junegunn/vim-peekaboo",
    event = "VeryLazy",
  },
  {
    "easymotion/vim-easymotion",
    keys = "<leader><leader>", -- Only load when actually using easymotion
  },
  {
    "simnalamburt/vim-mundo",
    cmd = { "MundoToggle", "MundoShow" },
    keys = { { "<leader>U", "<cmd>MundoToggle<cr>", desc = "Undo Tree" } },
  },

  -- Telescope configuration
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- Override LazyVim defaults with your custom versions
      { "<leader>ff", function()
        require("telescope.builtin").find_files({
          hidden = true,
          no_ignore = false,
          follow = true,
        })
      end, desc = "Find Files (Custom)" },

      -- <leader>fg mapping moved to telescope-live-grep-args.lua for better grep functionality

      -- Marks integration
      { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Find marks" },
    },
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        defaults = {
          file_ignore_patterns = {
            "node_modules", "^.git/", "dist", "/build/", "%.lock", "package%-lock%.json",
            "yarn%.lock", "%.log", "%.cache", "%.min%.js", "%.min%.css"
          },
          layout_config = {
            horizontal = { preview_width = 0.6 },
          },
        },
      })
    end,
  },

  -- marks.nvim - Enhanced marks with visual indicators
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      -- Enable default mappings (m{char} to set, dm{char} to delete)
      default_mappings = true,
      -- Enable signs in the sign column
      signs = true,
      -- Built-in mappings
      mappings = {
        set_next = "m,",           -- Set next available lowercase mark
        toggle = false,            -- Disable toggle to avoid conflicts
        next = "m]",              -- Move to next mark
        prev = "m[",              -- Move to previous mark
        preview = "m:",           -- Preview marks in floating window
        delete = "dm",            -- Delete mark (dm{char})
        delete_line = false,      -- Disable line deletion
        delete_buf = "dm<space>", -- Delete all marks in buffer
        next_bookmark = "m}",     -- Next bookmark
        prev_bookmark = "m{",     -- Previous bookmark
        delete_bookmark = "dm=",  -- Delete bookmark at cursor
      },
      -- Which builtin marks to show (. = last change, ^ = last insert)
      builtin_marks = { ".", "<", ">", "^" },
      -- Whether to remember marks between sessions
      cyclic = true,
      -- Force display marks in these filetypes
      force_write_shada = false,
      -- Refresh marks when these events occur
      refresh_interval = 250,
      -- Sign priorities
      sign_priority = { lower=10, upper=15, builtin=8, bookmark=20 },
      -- Bookmark groups (0-9) with custom signs
      bookmark_0 = {
        sign = "⚑",
        virt_text = "mark",
      },
      -- Exclude these filetypes
      excluded_filetypes = {
        "neo-tree",
        "TelescopePrompt",
        "lazy",
        "mason",
        "dashboard",
        "alpha",
        "terminal",
        "toggleterm",
      },
      -- Exclude these buffer types
      excluded_buftypes = {
        "terminal",
        "nofile",
        "quickfix",
      },
    },
  },

  -- {
  --   "typicode/bg.nvim",
  --   lazy = false,
  -- },
}
