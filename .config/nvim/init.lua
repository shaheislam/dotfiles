-- Basic settings
vim.cmd('syntax on')  -- Enable syntax highlighting
vim.opt.number = true  -- Show line numbers
vim.opt.relativenumber = true  -- Show relative line numbers
vim.opt.incsearch = true
vim.opt.clipboard = 'unnamed'

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
vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { desc = 'Find Files' })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { desc = 'Live Grep' })
vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = 'Find Buffers' })
vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', { desc = 'Help Tags' })
vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<cr>', { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>/', '<cmd>Telescope current_buffer_fuzzy_find<cr>', { desc = 'Search in Buffer' })

-- Oil.nvim keymap
vim.keymap.set('n', '<leader>e', '<cmd>Oil<cr>', { desc = 'Open File Browser' })

-- Harpoon keymaps (using Ctrl + ASDF - left hand home row)
vim.keymap.set('n', '<leader>a', function() require('harpoon'):list():add() end, { desc = 'Harpoon add file' })
vim.keymap.set('n', '<C-e>', function() require('harpoon').ui:toggle_quick_menu(require('harpoon'):list()) end, { desc = 'Harpoon toggle menu' })
vim.keymap.set('n', '<C-a>', function() require('harpoon'):list():select(1) end, { desc = 'Harpoon file 1' })
vim.keymap.set('n', '<C-s>', function() require('harpoon'):list():select(2) end, { desc = 'Harpoon file 2' })
vim.keymap.set('n', '<C-d>', function() require('harpoon'):list():select(3) end, { desc = 'Harpoon file 3' })
vim.keymap.set('n', '<C-f>', function() require('harpoon'):list():select(4) end, { desc = 'Harpoon file 4' })

-- Autocmd for Terraform files
vim.api.nvim_create_autocmd({'BufRead', 'BufNewFile'}, {
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
  'ap/vim-css-color',
  'hashivim/vim-terraform',
  'junegunn/rainbow_parentheses.vim',
  'michaeljsmith/vim-indent-object',
  'nathanaelkane/vim-indent-guides',
  'psliwka/vim-smoothie',
  'tpope/vim-abolish',
  'tpope/vim-sleuth',
  'tpope/vim-surround',

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
        spacing = 3, -- spacing between columns
      },
      spec = {
        -- Using new spec format
        { "<leader>f", group = "Find" },
        { "<leader>f/", desc = "Search in Buffer" },
        { "<leader>fb", desc = "Find Buffers" },
        { "<leader>ff", desc = "Find Files" },
        { "<leader>fg", desc = "Live Grep" },
        { "<leader>fh", desc = "Help Tags" },
        { "<leader>fr", desc = "Recent Files" },
        { "<leader>s", group = "Substitute" },
        { "<leader>ss", desc = "Substitute Word Range" },
        { "<leader>a", desc = "Harpoon Add File" },
        { "<leader>e", desc = "Open File Browser" },
        { "<C-e>", desc = "Harpoon Toggle Menu" },
        { "<C-a>", desc = "Harpoon File 1" },
        { "<C-s>", desc = "Harpoon File 2" },
        { "<C-d>", desc = "Harpoon File 3" },
        { "<C-f>", desc = "Harpoon File 4" },
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
})

-- Macros
vim.fn.setreg('f', '0cwfixup\\<Esc>j')
