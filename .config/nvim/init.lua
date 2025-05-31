-- ~/.config/nvim/init.lua
-- Set leader keys BEFORE loading lazy
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Bootstrap LazyVim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("lazy").setup({
  spec = {
    -- Import LazyVim and its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Import your custom plugins
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- always use the latest git commit
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- Custom macro setup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.fn.setreg('f', '0cwfixup\\<Esc>j')
  end,
})

-- Custom settings
vim.opt.clipboard = "unnamed" -- Your preference
vim.opt.relativenumber = true -- LazyVim has this but ensuring it's set

-- Plugin configuration variables for your custom plugins
vim.g.yoinkIncludeDeleteOperations = 1
vim.g.indent_guides_enable_on_vim_startup = 0
