-- ~/.config/nvim/lua/config/options.lua

-- Set Snacks as the default picker for LazyVim
vim.g.lazyvim_picker = "snacks"

-- Additional vim options can go here
-- vim.opt.relativenumber = true
-- vim.opt.wrap = false

-- Use bash for terminal commands to avoid Fish compatibility issues
-- This fixes issues with git checkout and other terminal commands
if vim.fn.executable("/bin/bash") == 1 then
  vim.o.shell = "/bin/bash"
elseif vim.fn.executable("/usr/bin/bash") == 1 then
  vim.o.shell = "/usr/bin/bash"
end
