-- ~/.config/nvim/lua/plugins/misc.lua
return {
  -- Override LazyVim's default colorscheme to Catppuccin Mocha
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
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
      vim.cmd([[colorscheme catppuccin-mocha]])
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
          python = { 'isort', 'black' },
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
    keys = { { "<leader>u", "<cmd>MundoToggle<cr>", desc = "Undo Tree" } },
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

      { "<leader>fg", function()
        require("telescope.builtin").live_grep({
          additional_args = function()
            return {"--glob", "!*test*", "--glob", "!*spec*", "--glob", "!*.min.*"}
          end
        })
      end, desc = "Live Grep (No Tests)" },
    },
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        defaults = {
          file_ignore_patterns = {
            "node_modules", ".git", "dist", "build", "%.lock", "package%-lock%.json",
            "yarn%.lock", "%.log", "%.cache", "%.min%.js", "%.min%.css"
          },
          layout_config = {
            horizontal = { preview_width = 0.6 },
          },
        },
      })
    end,
  },

  -- {
  --   "typicode/bg.nvim",
  --   lazy = false,
  -- },
}
