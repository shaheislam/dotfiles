-- ~/.config/nvim/lua/plugins/custom.lua
return {
  -- Completely disable LazyVim's default file explorer (neo-tree)
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },

  -- Oil.nvim - Your preferred file browser with aggressive keybinding override
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false, -- Load immediately to override neo-tree
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

  -- Harpoon v2 - Your quick navigation setup
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("harpoon"):setup()
    end,
    keys = {
      { "<leader>a", function() require("harpoon"):list():add() end, desc = "Harpoon add file" },
      { "<C-e>", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon toggle menu" },
      { "<C-1>", function() require("harpoon"):list():select(1) end, desc = "Harpoon file 1" },
      { "<C-2>", function() require("harpoon"):list():select(2) end, desc = "Harpoon file 2" },
      { "<C-3>", function() require("harpoon"):list():select(3) end, desc = "Harpoon file 3" },
      { "<C-4>", function() require("harpoon"):list():select(4) end, desc = "Harpoon file 4" },
    },
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

  {
    "svermeulen/vim-subversive",
    config = function()
      -- vim-subversive mappings
      vim.keymap.set('n', 's', '<plug>(SubversiveSubstitute)')
      vim.keymap.set('n', 'ss', '<plug>(SubversiveSubstituteLine)')
      vim.keymap.set('n', 'S', '<plug>(SubversiveSubstituteToEndOfLine)')
      vim.keymap.set('n', '<leader>s', '<plug>(SubversiveSubstituteRange)')
      vim.keymap.set('x', '<leader>s', '<plug>(SubversiveSubstituteRange)')
      vim.keymap.set('n', '<leader>ss', '<plug>(SubversiveSubstituteWordRange)')
    end,
  },

  -- Additional plugins you had that aren't in LazyVim
  "inkarkat/vim-ingo-library",
  "inkarkat/vim-ReplaceWithRegister",
  "inkarkat/vim-ReplaceWithSameIndentRegister",
  "inkarkat/vim-visualrepeat",
  "christoomey/vim-sort-motion",
  "junegunn/vim-peekaboo",
  "easymotion/vim-easymotion",
  "tpope/vim-rsi",
  "simnalamburt/vim-mundo",

  -- Missing plugins from your original config
  "ap/vim-css-color",
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
    opts = {
      defaults = {
        file_ignore_patterns = {
          "node_modules",
          ".git",
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
      },
    },
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
          find_command = { 'rg', '--files', '--hidden', '--glob', '!.git/*', '--glob', '!node_modules/*', '--glob', '!dist/*' }
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
}
