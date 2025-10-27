-- ~/.config/nvim/lua/config/options.lua

-- Set fzf-lua as the default picker for LazyVim
vim.g.lazyvim_picker = "fzf-lua"

-- DISABLE auto-formatting globally (both conform.nvim and LSP)
-- Toggle with <leader>uF to re-enable
vim.g.autoformat = false

-- Line numbers: both absolute and relative displayed side by side
vim.opt.number = true
vim.opt.relativenumber = true

-- Statuscolumn with gitsigns count
-- %s = sign column, %C = gitsigns count
vim.opt.statuscolumn = "%s %C%{v:lnum} %{v:relnum}"

-- Python provider configuration
vim.g.python3_host_prog = '/opt/homebrew/bin/python3.11'

-- Font configuration for GUI clients (Neovide, VimR, nvim-qt, etc.)
-- This setting ONLY affects GUI Neovim applications, NOT terminal Neovim
-- Terminal font is controlled by your terminal emulator (WezTerm, etc.)
vim.opt.guifont = "JetBrainsMono Nerd Font:h14"

-- Additional vim options can go here
-- vim.opt.wrap = false
