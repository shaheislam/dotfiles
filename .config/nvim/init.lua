-- Basic settings
vim.cmd('syntax on')          -- Enable syntax highlighting
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.incsearch = true
vim.opt.clipboard = 'unnamed'
vim.opt.termguicolors = true -- Enable 24-bit RGB colors
vim.opt.signcolumn = 'yes'   -- Always show sign column
vim.opt.updatetime = 250     -- Faster completion
vim.opt.timeoutlen = 300     -- Faster which-key

-- Set leader key to space
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Plugin configuration variables
vim.g.yoinkIncludeDeleteOperations = 1
vim.g.indent_guides_enable_on_vim_startup = 0

-- Key mappings
-- vim-cutlass using 'm' for cut (Separate cut and delete)
vim.keymap.set('n', 'm', 'd')
vim.keymap.set('x', 'm', 'd')
vim.keymap.set('n', 'mm', 'dd')
vim.keymap.set('n', 'M', 'D')

-- vim-yoink mappings
-- paste mappings (allow cycle through functionality)
vim.keymap.set('n', 'p', '<plug>(YoinkPaste_p)')
vim.keymap.set('n', 'P', '<plug>(YoinkPaste_P)')

-- cycle mappings to cycle through yanks
vim.keymap.set('n', '<c-n>', '<plug>(YoinkPostPasteSwapBack)')
vim.keymap.set('n', '<c-p>', '<plug>(YoinkPostPasteSwapForward)')

-- vim-subversive mappings
-- Basic substitution operator (replacing text with current yank)
vim.keymap.set('n', 's', '<plug>(SubversiveSubstitute)')
vim.keymap.set('n', 'ss', '<plug>(SubversiveSubstituteLine)')
vim.keymap.set('n', 'S', '<plug>(SubversiveSubstituteToEndOfLine)')

-- Range substitution (replacing one text with another across a range)
vim.keymap.set('n', '<leader>s', '<plug>(SubversiveSubstituteRange)')
vim.keymap.set('x', '<leader>s', '<plug>(SubversiveSubstituteRange)')
vim.keymap.set('n', '<leader>ss', '<plug>(SubversiveSubstituteWordRange)')

-- Telescope keymaps
vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').find_files({
    cwd = vim.fn.getcwd()
  })
end, { desc = 'Find Files' })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { desc = 'Live Grep' })
vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = 'Find Buffers' })
vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', { desc = 'Help Tags' })
vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<cr>', { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>/', '<cmd>Telescope current_buffer_fuzzy_find<cr>', { desc = 'Search in Buffer' })

-- Oil.nvim keymap
vim.keymap.set('n', '<leader>e', '<cmd>Oil<cr>', { desc = 'Open File Browser' })

-- Harpoon keymaps (using Ctrl + 1234)
vim.keymap.set('n', '<leader>a', function() require('harpoon'):list():add() end, { desc = 'Harpoon add file' })
vim.keymap.set('n', '<C-e>', function() require('harpoon').ui:toggle_quick_menu(require('harpoon'):list()) end,
  { desc = 'Harpoon toggle menu' })
vim.keymap.set('n', '<C-1>', function() require('harpoon'):list():select(1) end, { desc = 'Harpoon file 1' })
vim.keymap.set('n', '<C-2>', function() require('harpoon'):list():select(2) end, { desc = 'Harpoon file 2' })
vim.keymap.set('n', '<C-3>', function() require('harpoon'):list():select(3) end, { desc = 'Harpoon file 3' })
vim.keymap.set('n', '<C-4>', function() require('harpoon'):list():select(4) end, { desc = 'Harpoon file 4' })

-- Git keymaps (requires lazygit to be installed: https://github.com/jesseduffield/lazygit)
vim.keymap.set('n', '<leader>gs', '<cmd>Git<cr>', { desc = 'Git Status' })
vim.keymap.set('n', '<leader>gp', '<cmd>Git push<cr>', { desc = 'Git Push' })
vim.keymap.set('n', '<leader>gl', '<cmd>Git pull<cr>', { desc = 'Git Pull' })
vim.keymap.set('n', '<leader>gb', '<cmd>Git blame<cr>', { desc = 'Git Blame' })
vim.keymap.set('n', '<leader>gg', function()
  local Terminal = require('toggleterm.terminal').Terminal
  local lazygit = Terminal:new({
    cmd = "lazygit",
    dir = "git_dir",
    direction = "float",
    float_opts = {
      border = "curved",
    },
    on_open = function(term)
      vim.cmd("startinsert!")
      vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
    end,
    on_close = function(term)
      vim.cmd("startinsert!")
    end,
  })
  lazygit:toggle()
end, { desc = 'Lazygit' })

-- Terminal keymap
vim.keymap.set('n', '<leader>t', '<cmd>ToggleTerm<cr>', { desc = 'Toggle Terminal' })

-- Search and replace keymap
vim.keymap.set('n', '<leader>sr', '<cmd>lua require("spectre").toggle()<cr>', { desc = 'Search and Replace' })

-- Session keymaps
vim.keymap.set('n', '<leader>qs', function() require('persistence').load() end, { desc = 'Restore Session' })
vim.keymap.set('n', '<leader>ql', function() require('persistence').load({ last = true }) end,
  { desc = 'Restore Last Session' })
vim.keymap.set('n', '<leader>qd', function() require('persistence').stop() end, { desc = 'Stop Session' })

-- Autocmd for Terraform files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.tf',
  callback = function()
    vim.bo.filetype = 'terraform'
  end,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin setup with lazy.nvim
require("lazy").setup({
  -- Colorschemes
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme tokyonight-night]])
    end,
  },
  'catppuccin/nvim',
  'rose-pine/neovim',

  -- LSP & Completion
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    lazy = true,
    config = false,
    init = function()
      -- Disable automatic setup, we are doing it manually
      vim.g.lsp_zero_extend_cmp = 0
      vim.g.lsp_zero_extend_lspconfig = 0
    end,
  },
  {
    'williamboman/mason.nvim',
    lazy = false,
    config = true,
  },
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      { 'L3MON4D3/LuaSnip' },
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'hrsh7th/cmp-buffer' },
      { 'hrsh7th/cmp-path' },
      { 'saadparwaiz1/cmp_luasnip' },
    },
    config = function()
      local lsp_zero = require('lsp-zero')
      lsp_zero.extend_cmp()

      local cmp = require('cmp')
      local cmp_action = lsp_zero.cmp_action()

      cmp.setup({
        formatting = lsp_zero.cmp_format(),
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-u>'] = cmp.mapping.scroll_docs(-4),
          ['<C-d>'] = cmp.mapping.scroll_docs(4),
          ['<C-f>'] = cmp_action.luasnip_jump_forward(),
          ['<C-b>'] = cmp_action.luasnip_jump_backward(),
        })
      })
    end
  },
  {
    'neovim/nvim-lspconfig',
    cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'williamboman/mason-lspconfig.nvim' },
    },
    config = function()
      local lsp_zero = require('lsp-zero')
      lsp_zero.extend_lspconfig()

      lsp_zero.on_attach(function(client, bufnr)
        lsp_zero.default_keymaps({ buffer = bufnr })
      end)

      require('mason-lspconfig').setup({
        ensure_installed = { 'lua_ls', 'tsserver', 'rust_analyzer', 'gopls', 'pyright' },
        handlers = {
          lsp_zero.default_setup,
          lua_ls = function()
            local lua_opts = lsp_zero.nvim_lua_ls()
            require('lspconfig').lua_ls.setup(lua_opts)
          end,
        }
      })
    end
  },

  -- Treesitter for better syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { "lua", "vim", "vimdoc", "javascript", "typescript", "python", "rust", "go", "terraform", "json", "yaml" },
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = '<C-space>',
            node_incremental = '<C-space>',
            scope_incremental = false,
            node_decremental = '<bs>',
          },
        },
      })
    end,
  },
  'nvim-treesitter/nvim-treesitter-textobjects',

  -- Git integration
  'tpope/vim-fugitive',
  'tpope/vim-rhubarb',

  -- UI Enhancements
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'tokyonight',
          component_separators = '|',
          section_separators = '',
        },
        sections = {
          lualine_x = {
            {
              require("lazy.status").updates,
              cond = require("lazy.status").has_updates,
              color = { fg = "#ff9e64" },
            },
            'encoding',
            'fileformat',
            'filetype'
          },
        },
      })
    end,
  },
  {
    'rcarriga/nvim-notify',
    config = function()
      vim.notify = require('notify')
      require('notify').setup({
        stages = 'fade_in_slide_out',
        background_colour = 'FloatShadow',
        timeout = 3000,
      })
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    config = function()
      require('ibl').setup({
        indent = {
          char = '│',
          tab_char = '│',
        },
        scope = { enabled = false },
        exclude = {
          filetypes = {
            'help',
            'alpha',
            'dashboard',
            'neo-tree',
            'Trouble',
            'trouble',
            'lazy',
            'mason',
            'notify',
            'toggleterm',
            'lazyterm',
          },
        },
      })
    end,
  },

  -- Productivity plugins
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end,
  },
  {
    'nmac427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup({})
    end,
  },
  {
    'nvim-pack/nvim-spectre',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('spectre').setup()
    end,
  },
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    config = function()
      require('persistence').setup()
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
      require('toggleterm').setup({
        size = 20,
        open_mapping = [[<c-\>]],
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
      })
    end,
  },
  {
    'stevearc/conform.nvim',
    config = function()
      require('conform').setup({
        formatters_by_ft = {
          lua = { 'stylua' },
          python = { 'isort', 'black' },
          javascript = { { 'prettierd', 'prettier' } },
          typescript = { { 'prettierd', 'prettier' } },
          json = { { 'prettierd', 'prettier' } },
          yaml = { { 'prettierd', 'prettier' } },
          terraform = { 'terraform_fmt' },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
    end,
  },

  -- Original plugins
  'ap/vim-css-color',
  'hashivim/vim-terraform',
  'junegunn/rainbow_parentheses.vim',
  'michaeljsmith/vim-indent-object',
  'nathanaelkane/vim-indent-guides',
  'psliwka/vim-smoothie',
  'tpope/vim-abolish',
  'tpope/vim-sleuth',
  'tpope/vim-surround',
  'tpope/vim-fugitive',
  -- Undo tree visualiser
  'simnalamburt/vim-mundo',

  -- FZF for Vim
  {
    'junegunn/fzf',
    build = function()
      vim.fn['fzf#install']()
    end
  },
  'junegunn/fzf.vim',

  -- Telescope - Fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git", "dist" },
          hidden = true,
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
      })
    end,
  },

  -- Telescope fzf native for better performance
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    config = function()
      require('telescope').load_extension('fzf')
    end,
  },

  -- Oil.nvim - Modern file browser
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('oil').setup({
        -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
        default_file_explorer = true,
        -- Buffer-local options to use for oil buffers
        buf_options = {
          buflisted = false,
          bufhidden = "hide",
        },
        -- Window-local options to use for oil buffers
        win_options = {
          wrap = false,
          signcolumn = "no",
          cursorcolumn = false,
          foldcolumn = "0",
          spell = false,
          list = false,
          conceallevel = 3,
          concealcursor = "nvic",
        },
        -- Send deleted files to the trash instead of permanently deleting them
        delete_to_trash = true,
        -- Skip the confirmation popup for simple operations
        skip_confirm_for_simple_edits = false,
        -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
        prompt_save_on_select_new_entry = true,
        -- Oil will automatically delete hidden buffers after this delay
        cleanup_delay_ms = 2000,
        lsp_file_methods = {
          -- Time to wait for LSP file operations to complete before skipping
          timeout_ms = 1000,
          -- Set to true to autosave buffers that are updated with LSP willRenameFiles
          autosave_changes = false,
        },
        -- Constrain the cursor to the editable parts of the oil buffer
        constrain_cursor = "editable",
        -- Set to true to watch the filesystem for changes and reload oil
        watch_for_changes = false,
        -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-v>"] = "actions.select_vsplit",
          ["<C-h>"] = "actions.select_split",
          ["<C-t>"] = "actions.select_tab",
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["<C-l>"] = "actions.refresh",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = "actions.tcd",
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
          ["<leader>f"] = {
            desc = "Fuzzy find files",
            callback = function()
              require("telescope.builtin").find_files({
                cwd = require("oil").get_current_dir()
              })
            end,
          },
        },
        -- Set to false to disable all of the above keymaps
        use_default_keymaps = true,
        view_options = {
          -- Show files and directories that start with "."
          show_hidden = false,
          -- This function defines what is considered a "hidden" file
          is_hidden_file = function(name, bufnr)
            return vim.startswith(name, ".")
          end,
          -- This function defines what will never be shown, even when `show_hidden` is set
          is_always_hidden = function(name, bufnr)
            return false
          end,
          sort = {
            -- sort order can be "asc" or "desc"
            -- see :help oil-columns to see which columns are sortable
            { "type", "asc" },
            { "name", "asc" },
          },
        },
        -- Configuration for the floating window in oil.open_float
        float = {
          -- Padding around the floating window
          padding = 2,
          max_width = 0,
          max_height = 0,
          border = "rounded",
          win_options = {
            winblend = 0,
          },
          -- This is the config that will be passed to nvim_open_win.
          -- Change values here to customize the layout
          override = function(conf)
            return conf
          end,
        },
        -- Configuration for the actions floating preview window
        preview = {
          -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
          -- min_width and max_width can be a single value or a list of mixed integer/float types.
          max_width = 0.9,
          -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
          min_width = { 40, 0.4 },
          -- optionally define an integer/float for the exact width of the preview window
          width = nil,
          -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
          -- min_height and max_height can be a single value or a list of mixed integer/float types.
          max_height = 0.9,
          min_height = { 5, 0.1 },
          -- optionally define an integer/float for the exact height of the preview window
          height = nil,
          border = "rounded",
          win_options = {
            winblend = 0,
          },
        },
        -- Configuration for the floating progress window
        progress = {
          max_width = 0.9,
          min_width = { 40, 0.4 },
          width = nil,
          max_height = { 10, 0.9 },
          min_height = { 5, 0.1 },
          height = nil,
          border = "rounded",
          minimized_border = "none",
          win_options = {
            winblend = 0,
          },
        },
      })
    end,
  },

  -- Which-key for keybinding hints
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      -- Fixed configuration
      win = {
        border = "rounded", -- none, single, double, shadow
      },
      layout = {
        height = { min = 4, max = 25 }, -- min and max height of the columns
        width = { min = 20, max = 50 }, -- min and max width of the columns
        spacing = 3,                    -- spacing between columns
      },
      spec = {
        -- Using new spec format
        { "<leader>f",  group = "Find" },
        { "<leader>f/", desc = "Search in Buffer" },
        { "<leader>fb", desc = "Find Buffers" },
        { "<leader>ff", desc = "Find Files" },
        { "<leader>fg", desc = "Live Grep" },
        { "<leader>fh", desc = "Help Tags" },
        { "<leader>fr", desc = "Recent Files" },
        { "<leader>s",  group = "Substitute" },
        { "<leader>ss", desc = "Substitute Word Range" },
        { "<leader>sr", desc = "Search and Replace" },
        { "<leader>a",  desc = "Harpoon Add File" },
        { "<leader>e",  desc = "Open File Browser" },
        { "<leader>t",  desc = "Toggle Terminal" },
        { "<leader>g",  group = "Git" },
        { "<leader>gs", desc = "Git Status" },
        { "<leader>gg", desc = "Lazygit" },
        { "<leader>gp", desc = "Git Push" },
        { "<leader>gl", desc = "Git Pull" },
        { "<leader>gb", desc = "Git Blame" },
        { "<leader>q",  group = "Session" },
        { "<leader>qs", desc = "Restore Session" },
        { "<leader>ql", desc = "Restore Last Session" },
        { "<leader>qd", desc = "Stop Session" },
        { "<C-e>",      desc = "Harpoon Toggle Menu" },
        { "<C-1>",      desc = "Harpoon File 1" },
        { "<C-2>",      desc = "Harpoon File 2" },
        { "<C-3>",      desc = "Harpoon File 3" },
        { "<C-4>",      desc = "Harpoon File 4" },
      },
    },
  },

  -- Harpoon for quick file navigation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('harpoon'):setup()
    end,
  },

  -- Allows traversing motions without numbers easier
  'easymotion/vim-easymotion',

  -- Allows unix readline commands in vim
  'tpope/vim-rsi',

  -- Register sidebar '@ or "'
  'junegunn/vim-peekaboo',

  -- Auto close brackets
  'jiangmiao/auto-pairs',

  -- Use gs after indenting a block to sort (Useful for Terraform variables)
  'christoomey/vim-sort-motion',

  -- Using Vim-EasyClip
  'svermeulen/vim-cutlass',    -- Separates delete and cut functionality
  'svermeulen/vim-yoink',      -- Maintains a yank history
  'svermeulen/vim-subversive', -- Provides substitute operator functionality

  -- Required dependency
  'inkarkat/vim-ingo-library',

  -- The main plugin (depends on ReplaceWithRegister)
  'inkarkat/vim-ReplaceWithRegister',
  'inkarkat/vim-ReplaceWithSameIndentRegister',

  -- Optional dependencies for enhanced functionality
  'tpope/vim-repeat',
  'inkarkat/vim-visualrepeat',

  -- Web dev icons (dependency for many plugins)
  'nvim-tree/nvim-web-devicons',
})

-- Macros
vim.fn.setreg('f', '0cwfixup\\<Esc>j')
