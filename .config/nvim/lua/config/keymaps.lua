-- ~/.config/nvim/lua/config/keymaps.lua
-- Override LazyVim default keymaps

-- Force Oil.nvim to take control of file explorer keybindings
-- This will override any existing neo-tree keybindings
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open File Browser", silent = true })
vim.keymap.set("n", "<leader>fe", "<cmd>Oil<cr>", { desc = "Open File Browser", silent = true })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory", silent = true })

-- Additional custom keymaps
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all", silent = true })
vim.keymap.set("n", "<leader>ww", "<cmd>w<cr>", { desc = "Save file", silent = true })
