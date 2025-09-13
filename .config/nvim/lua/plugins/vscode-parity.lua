-- VSCode Feature Parity Plugins
-- Adds functionality present in VSCode extensions but missing in current Neovim setup

return {
  -- ============== GIT ENHANCEMENTS ==============
  
  -- Advanced Git integration (like GitLens)
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit Status" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit Commit" },
    },
  },

  -- Git diff view (like Git Graph)
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch History" },
    },
  },

  -- ============== MARKDOWN ENHANCEMENTS ==============
  
  -- Markdown preview with Mermaid support
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function() vim.fn["mkdp#util#install"]() end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
    },
    config = function()
      vim.g.mkdp_filetypes = { "markdown", "mermaid" }
      vim.g.mkdp_theme = 'dark'
      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = { theme = 'dark' },
        disable_sync_scroll = 0,
        sync_scroll_type = 'middle'
      }
    end,
    ft = { "markdown" },
  },

  -- Markdown task lists and checkboxes
  {
    "ixru/nvim-markdown",
    ft = "markdown",
    config = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_conceal = 0
      vim.g.vim_markdown_frontmatter = 1
      vim.g.vim_markdown_strikethrough = 1
      vim.g.vim_markdown_new_list_item_indent = 2
    end,
  },

  -- ============== JUPYTER/NOTEBOOK SUPPORT ==============
  
  -- Jupyter notebook integration
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
    end,
    keys = {
      { "<leader>mi", ":MoltenInit<CR>", desc = "Initialize Molten" },
      { "<leader>me", ":MoltenEvaluateOperator<CR>", desc = "Evaluate Operator" },
      { "<leader>ml", ":MoltenEvaluateLine<CR>", desc = "Evaluate Line" },
      { "<leader>mr", ":MoltenReevaluateCell<CR>", desc = "Re-evaluate Cell" },
      { "<leader>md", ":MoltenDelete<CR>", desc = "Delete Cell" },
    },
  },

  -- ============== REMOTE DEVELOPMENT ==============
  
  -- Remote file editing over SSH
  {
    "chipsenkbeil/distant.nvim",
    branch = 'v0.3',
    config = function()
      require('distant'):setup()
    end,
    cmd = { "DistantConnect", "DistantOpen", "DistantLaunch" },
  },

  -- ============== REST CLIENT IMPROVEMENTS ==============
  
  -- Modern REST client (alternative to rest.nvim)
  {
    "mistweaverco/kulala.nvim",
    config = function()
      require('kulala').setup({
        default_view = "headers_body",
        debug = false,
      })
    end,
    keys = {
      { "<leader>kr", function() require('kulala').run() end, desc = "Run REST request" },
      { "<leader>kc", function() require('kulala').copy() end, desc = "Copy as cURL" },
      { "<leader>ki", function() require('kulala').inspect() end, desc = "Inspect request" },
    },
  },

  -- ============== BOOKMARKS & NAVIGATION ==============
  
  -- Better marks visualization (like VSCode bookmarks)
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    config = function()
      require("marks").setup({
        default_mappings = true,
        signs = true,
        mappings = {
          toggle = "m,",
          next = "m]",
          prev = "m[",
          delete_buf = "dm-",
        }
      })
    end,
  },

  -- Project-specific navigation (enhanced bookmarks)
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup()
      
      vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end, { desc = "Add to Harpoon" })
      vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon Menu" })
      vim.keymap.set("n", "<leader>h1", function() harpoon:list():select(1) end, { desc = "Harpoon 1" })
      vim.keymap.set("n", "<leader>h2", function() harpoon:list():select(2) end, { desc = "Harpoon 2" })
      vim.keymap.set("n", "<leader>h3", function() harpoon:list():select(3) end, { desc = "Harpoon 3" })
      vim.keymap.set("n", "<leader>h4", function() harpoon:list():select(4) end, { desc = "Harpoon 4" })
    end,
  },

  -- ============== SQL IMPROVEMENTS ==============
  
  -- SQL helper plugin for better SQL editing
  -- (SQL LSP is configured in lsp-devops.lua)
  {
    "nanotee/sqls.nvim",
    dependencies = { "neovim/nvim-lspconfig" },
    ft = { "sql", "mysql", "postgres" },
    config = function()
      -- This adds additional SQL editing helpers to the existing sqls LSP
      require('sqls').setup({})
    end,
  },

  -- ============== VISUAL ENHANCEMENTS ==============
  
  -- Indent guides with color (like indent-rainbow)
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = { enabled = false },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      },
    },
  },

  -- ============== FILE COMPARISON ==============
  
  -- Enhanced diff mode
  {
    "AndrewRadev/linediff.vim",
    cmd = { "Linediff", "LinediffReset" },
    keys = {
      { "<leader>ld", ":Linediff<CR>", desc = "Mark for Diff", mode = "v" },
      { "<leader>lr", ":LinediffReset<CR>", desc = "Reset Diff" },
    },
  },

  -- ============== ADDITIONAL PRODUCTIVITY ==============
  
  -- Auto-rename HTML/XML tags (like VSCode's auto-rename-tag)
  {
    "windwp/nvim-ts-autotag",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require('nvim-ts-autotag').setup({
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = true
        },
      })
    end,
    ft = { "html", "xml", "jsx", "tsx", "vue", "svelte", "php" },
  },

  -- Package.json enhancement (like npm-intellisense)
  {
    "vuki656/package-info.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    config = function()
      require('package-info').setup()
    end,
    event = { "BufRead package.json" },
  },

  -- Theme switcher for quick theme changes
  {
    "andrew-george/telescope-themes",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("themes")
    end,
    keys = {
      { "<leader>tt", ":Telescope themes<CR>", desc = "Theme Switcher" },
    },
  },
}