#!/bin/bash
# Lightweight Neovim installer for pods/containers
# Auto-installs when shelling into containers
# Usage: ./install-nvim-in-pod-lightweight.sh <namespace> <pod> [container]

set -e

NAMESPACE="${1:-default}"
POD="$2"
CONTAINER="${3:-}"

if [ -z "$POD" ]; then
    echo "Usage: $0 <namespace> <pod> [container]"
    exit 1
fi

# Build the kubectl exec command
EXEC_CMD="kubectl exec -n $NAMESPACE $POD"
if [ -n "$CONTAINER" ]; then
    EXEC_CMD="$EXEC_CMD -c $CONTAINER"
fi

# Quick check if nvim is already installed and configured
NVIM_CHECK=$($EXEC_CMD -- sh -c 'if [ -f ~/.config/nvim/.lightweight_installed ] && command -v nvim >/dev/null 2>&1; then echo "installed"; else echo "not-installed"; fi' 2>/dev/null || echo "not-installed")

if [ "$NVIM_CHECK" = "installed" ]; then
    # Already installed, exit silently
    exit 0
fi

# Install and configure
$EXEC_CMD -- sh -c '
# Function to install packages based on available package manager
install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y neovim git curl 2>/dev/null || \
        DEBIAN_FRONTEND=noninteractive apt-get install -y neovim 2>/dev/null
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache neovim git curl 2>/dev/null || \
        apk add --no-cache neovim 2>/dev/null
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release >/dev/null 2>&1 || true
        yum install -y neovim git 2>/dev/null || \
        yum install -y neovim 2>/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y neovim git 2>/dev/null || \
        dnf install -y neovim 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm neovim git 2>/dev/null || \
        pacman -Sy --noconfirm neovim 2>/dev/null
    fi
}

# Install Neovim if not present
if ! command -v nvim >/dev/null 2>&1; then
    install_packages
fi

# Only proceed if nvim is now available
if ! command -v nvim >/dev/null 2>&1; then
    exit 0
fi

# Create config directory
mkdir -p ~/.config/nvim
mkdir -p ~/.local/share/nvim
mkdir -p ~/.cache/nvim

# Create lightweight configuration
cat > ~/.config/nvim/init.lua << '\''NVIM_CONFIG'\''
-- Lightweight Neovim config for containers
-- Minimal plugins: oil, telescope, tokyonight

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Essential settings
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.wrap = false
opt.breakindent = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.undofile = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.completeopt = "menuone,noselect"
opt.clipboard = "unnamedplus"

-- Bootstrap lazy.nvim
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
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- File explorer (oil.nvim)
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", function() require("oil").open() end, desc = "Explorer" },
      { "-", function() require("oil").open() end, desc = "Open parent" },
    },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      keymaps = {
        ["<CR>"] = "actions.select",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["g."] = "actions.toggle_hidden",
        ["q"] = "actions.close",
      },
      use_default_keymaps = false,
    },
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
      { "<leader>,", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      -- find
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      -- search
      { "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
      { "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
      { "<leader>sk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
      { "<leader>sw", "<cmd>Telescope grep_string<cr>", desc = "Word" },
      { "<leader>sd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
    },
    opts = {
      defaults = {
        prompt_prefix = " ",
        selection_caret = " ",
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<esc>"] = "close",
          },
        },
      },
    },
  },

  -- Which-key (minimal)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    config = function()
      local wk = require("which-key")
      wk.setup()
      wk.register({
        ["<leader>f"] = { name = "+file" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>w"] = { name = "+window" },
        ["<leader>b"] = { name = "+buffer" },
      })
    end,
  },

  -- Comment
  {
    "numToStr/Comment.nvim",
    keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    opts = {},
  },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
})

-- Keymaps
local map = vim.keymap.set

-- Better defaults
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit All" })

-- Better navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize with arrows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Windows
map("n", "<leader>ww", "<C-W>p", { desc = "Other window" })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete window" })
map("n", "<leader>w-", "<C-W>s", { desc = "Split below" })
map("n", "<leader>w|", "<C-W>v", { desc = "Split right" })

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
  pattern = "*",
})

print("Lightweight Neovim ready!")
print("  Space+Space : Find files")
print("  Space+/     : Search text")
print("  Space+e     : File explorer")
print("  gc          : Comment")
NVIM_CONFIG

# Mark as installed
touch ~/.config/nvim/.lightweight_installed

# Try to install plugins if git is available
if command -v git >/dev/null 2>&1; then
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi
' >/dev/null 2>&1