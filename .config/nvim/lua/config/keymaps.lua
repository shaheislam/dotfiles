-- ~/.config/nvim/lua/config/keymaps.lua
-- Override LazyVim default keymaps

-- Force Oil.nvim to take control of file explorer keybindings
-- This will override any existing neo-tree keybindings
vim.keymap.set("n", "<leader>fe", "<cmd>Oil<cr>", { desc = "Open File Browser", silent = true })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory", silent = true })

-- Additional custom keymaps
-- Removed <leader>qq as LazyVim already provides this
vim.keymap.set("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save file", silent = true })

-- Theme toggling removed - now using fzf-lua colorscheme picker

-- Fix <leader>fT to actually open terminal in CWD
-- LazyVim's default doesn't pass cwd option despite the description saying it should
vim.keymap.set('n', '<leader>fT', function()
  require('snacks').terminal(nil, {
    cwd = vim.fn.getcwd(),
    auto_close = true,  -- Ensure buffer closes when shell exits with <C-d>
  })
end, { desc = "Terminal (cwd)" })

-- Disable LazyVim's LazyGit keybindings
pcall(vim.keymap.del, "n", "<leader>gg")
pcall(vim.keymap.del, "n", "<leader>gG")
pcall(vim.keymap.del, "n", "<leader>gL")

-- Custom scrolling keymaps
-- Remap Ctrl-f to scroll up (half-page) instead of full-page down
vim.keymap.set({'n', 'v'}, '<C-f>', '<C-u>', { desc = "Scroll up (half-page)", silent = true })
-- Keep Ctrl-d for scroll down (half-page) - LazyVim default
