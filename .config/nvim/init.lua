-- Basic settings
vim.cmd('syntax on')  -- Enable syntax highlighting
vim.opt.number = true  -- Show line numbers
vim.opt.relativenumber = true  -- Show relative line numbers
vim.opt.incsearch = true
vim.opt.clipboard = 'unnamed'

-- Plugin configuration variables
vim.g.yoinkIncludeDeleteOperations = 1
vim.g.indent_guides_enable_on_vim_startup = 0

-- Key mappings
-- vim-cutlass using 'x' for cut (Separate cut and delete)
vim.keymap.set('n', 'x', 'd')
vim.keymap.set('x', 'x', 'd')
vim.keymap.set('n', 'xx', 'dd')
vim.keymap.set('n', 'X', 'D')

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

-- Harpoon keymaps
vim.keymap.set('n', '<leader>a', function() require('harpoon'):list():add() end, { desc = 'Harpoon add file' })
vim.keymap.set('n', '<C-e>', function() require('harpoon').ui:toggle_quick_menu(require('harpoon'):list()) end, { desc = 'Harpoon toggle menu' })
vim.keymap.set('n', '<C-h>', function() require('harpoon'):list():select(1) end, { desc = 'Harpoon file 1' })
vim.keymap.set('n', '<C-t>', function() require('harpoon'):list():select(2) end, { desc = 'Harpoon file 2' })
vim.keymap.set('n', '<C-n>', function() require('harpoon'):list():select(3) end, { desc = 'Harpoon file 3' })
vim.keymap.set('n', '<C-s>', function() require('harpoon'):list():select(4) end, { desc = 'Harpoon file 4' })

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
  
  -- Which-key for keybinding hints
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    config = function()
      local wk = require('which-key')
      
      wk.setup({
        -- Your configuration options here
        window = {
          border = "rounded", -- none, single, double, shadow
          position = "bottom", -- bottom, top
        },
        layout = {
          height = { min = 4, max = 25 }, -- min and max height of the columns
          width = { min = 20, max = 50 }, -- min and max width of the columns
          spacing = 3, -- spacing between columns
        },
      })

      -- Register your key mappings with descriptions
      wk.register({
        ["<leader>f"] = {
          name = "Find", -- group name
          f = { "Find Files" },
          g = { "Live Grep" },
          b = { "Find Buffers" },
          h = { "Help Tags" },
          r = { "Recent Files" },
          ["/"] = { "Search in Buffer" },
        },
        ["<leader>s"] = {
          name = "Substitute", -- group name
          s = { "Substitute Word Range" },
        },
        ["<leader>a"] = { "Harpoon Add File" },
      })

      -- Register some of your other mappings
      wk.register({
        ["<C-e>"] = { "Harpoon Toggle Menu" },
        ["<C-h>"] = { "Harpoon File 1" },
        ["<C-t>"] = { "Harpoon File 2" },
        ["<C-n>"] = { "Harpoon File 3" },
        ["<C-s>"] = { "Harpoon File 4" },
      })
    end,
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
  
  -- Avante - AI pair programming
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    lazy = false,
    version = false,
    opts = {
      provider = "claude", -- You can change to "openai", "azure", "gemini", etc.
    },
    build = 'make',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      --- The below dependencies are optional,
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      'zbirenbaum/copilot.lua', -- for providers='copilot'
      {
        -- support for image pasting
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
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
