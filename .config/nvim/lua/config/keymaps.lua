-- ~/.config/nvim/lua/config/keymaps.lua
-- Override LazyVim default keymaps

-- Force Oil.nvim to take control of file explorer keybindings
-- This will override any existing neo-tree keybindings
vim.keymap.set("n", "<leader>fe", "<cmd>Oil<cr>", { desc = "Open File Browser", silent = true })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory", silent = true })

-- Additional custom keymaps
-- Removed <leader>qq as LazyVim already provides this
vim.keymap.set("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save file", silent = true })

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

-- Terminal mode keymaps
-- Double-tap Esc to exit terminal mode (preserves single Esc for shell operations)
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = "Exit terminal mode" })

-- Fix <leader>fT to actually open terminal in CWD
-- LazyVim's default doesn't pass cwd option despite the description saying it should
vim.keymap.set('n', '<leader>fT', function()
  require('snacks').terminal(nil, { cwd = vim.fn.getcwd() })
end, { desc = "Terminal (cwd)" })

-- Disable LazyVim's LazyGit keybindings
pcall(vim.keymap.del, "n", "<leader>gg")
pcall(vim.keymap.del, "n", "<leader>gG")
pcall(vim.keymap.del, "n", "<leader>gL")
