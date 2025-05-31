-- ~/.config/nvim/lua/plugins/misc.lua
return {
  -- Override LazyVim's default colorscheme to your preference
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      vim.cmd([[colorscheme tokyonight-night]])
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
          javascript = { { 'prettierd', 'prettier' } },
          typescript = { { 'prettierd', 'prettier' } },
          json = { { 'prettierd', 'prettier' } },
          yaml = { { 'prettierd', 'prettier' } },
          terraform = { 'terraform_fmt' },
          go = { 'goimports', 'gofmt' },
          rust = { 'rustfmt' },
          markdown = { { 'prettierd', 'prettier' } },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
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
          find_command = { 'rg', '--files', '--hidden', '--glob', '!.git/*', '--glob', '!node_modules/*', '--glob', '!dist/*' }
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

  -- Oil.nvim integration with telescope
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Oil",
    opts = {
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = false,
      view_options = {
        show_hidden = false,
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
        ["<C-h>"] = false, -- Remove conflict with window navigation
        ["<C-l>"] = false, -- Remove conflict with window navigation
        ["<leader>ff"] = {
          desc = "Find files in current directory",
          callback = function()
            require("telescope.builtin").find_files({
              cwd = require("oil").get_current_dir()
            })
          end,
        },
      },
    },
    keys = {
      { "<leader>e", "<cmd>Oil<cr>", desc = "Open File Browser" },
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
  },
}
