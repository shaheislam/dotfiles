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

-- Theme cycling function
local function CycleTheme()
  local themes = { "catppuccin-mocha", "onedark", "tokyonight-storm" }
  local current = vim.g.colors_name

  -- Find current theme index
  local current_index = 1
  for i, theme in ipairs(themes) do
    if theme == current then
      current_index = i
      break
    end
  end

  -- Cycle to next theme (wrap around)
  local next_index = (current_index % #themes) + 1
  vim.cmd("colorscheme " .. themes[next_index])
end

vim.keymap.set('n', '<leader>tt', CycleTheme, { desc = "Cycle themes" })

-- Disable LazyVim's LazyGit keybindings
pcall(vim.keymap.del, "n", "<leader>gg")
pcall(vim.keymap.del, "n", "<leader>gG")
pcall(vim.keymap.del, "n", "<leader>gL")
pcall(vim.keymap.del, "n", "<leader>gB")
