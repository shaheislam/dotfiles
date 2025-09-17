#!/bin/bash
# Ultra-lightweight Neovim installer for pods
# Installs nvim with minimal config (oil + telescope + tokyonight)

NAMESPACE="${1:-default}"
POD="$2"
CONTAINER="${3:-}"

if [ -z "$POD" ]; then
    exit 1
fi

# Build kubectl exec command
EXEC_CMD="kubectl exec -n $NAMESPACE $POD"
[ -n "$CONTAINER" ] && EXEC_CMD="$EXEC_CMD -c $CONTAINER"

# Check if already installed
CHECK=$($EXEC_CMD -- sh -c 'command -v nvim' 2>/dev/null)
if [ -n "$CHECK" ]; then
    exit 0
fi

# Create installer script
cat > /tmp/nvim-install.sh << 'EOF'
#!/bin/sh
# Install neovim
if command -v apk >/dev/null 2>&1; then
    apk add --no-cache neovim git curl 2>/dev/null
elif command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y neovim git curl 2>/dev/null
elif command -v yum >/dev/null 2>&1; then
    yum install -y neovim git 2>/dev/null
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y neovim git 2>/dev/null
fi

# Only continue if nvim installed
if ! command -v nvim >/dev/null 2>&1; then
    exit 0
fi

# Create minimal config
mkdir -p ~/.config/nvim
cat > ~/.config/nvim/init.lua << 'NVIMCFG'
-- Minimal config for containers
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.wrap = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({"git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath})
end
vim.opt.rtp:prepend(lazypath)

-- Minimal plugins
require("lazy").setup({
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
  {
    "stevearc/oil.nvim",
    keys = {
      { "<leader>e", function() require("oil").open() end, desc = "Explorer" },
      { "-", function() require("oil").open() end, desc = "Parent" },
    },
    opts = {
      default_file_explorer = true,
      keymaps = {
        ["<CR>"] = "actions.select",
        ["-"] = "actions.parent",
        ["q"] = "actions.close",
      },
      use_default_keymaps = false,
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Files" },
      { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
      { "<leader>,", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
    opts = {
      defaults = {
        mappings = { i = { ["<esc>"] = "close" } },
      },
    },
  },
})

-- Basic keymaps
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Down window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Up window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Right window" })
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")
NVIMCFG

# Install plugins silently
if command -v git >/dev/null 2>&1; then
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi
EOF

# Copy and run installer
kubectl cp /tmp/nvim-install.sh $NAMESPACE/$POD:/tmp/nvim-install.sh ${CONTAINER:+-c $CONTAINER} 2>/dev/null
$EXEC_CMD -- sh -c 'chmod +x /tmp/nvim-install.sh && /tmp/nvim-install.sh' >/dev/null 2>&1