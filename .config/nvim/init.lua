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
