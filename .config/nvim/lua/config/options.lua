-- ~/.config/nvim/lua/config/options.lua

-- Set Snacks as the default picker for LazyVim
vim.g.lazyvim_picker = "snacks"

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

-- Additional vim options can go here
-- vim.opt.wrap = false
