#!/bin/bash
# Fix Neovim configuration in pods that have compatibility issues
# Usage: ./fix-nvim-in-pod.sh <namespace> <pod> [container]

set -e

NAMESPACE="${1:-default}"
POD="$2"
CONTAINER="${3:-}"

if [ -z "$POD" ]; then
    echo "Usage: $0 <namespace> <pod> [container]"
    echo "Example: $0 default my-pod my-container"
    exit 1
fi

# Build the kubectl exec command
EXEC_CMD="kubectl exec -n $NAMESPACE $POD"
if [ -n "$CONTAINER" ]; then
    EXEC_CMD="$EXEC_CMD -c $CONTAINER"
fi

echo "🔧 Fixing Neovim configuration in pod $POD..."

# Apply the fix
$EXEC_CMD -- sh -c '
# Backup existing config
if [ -f ~/.config/nvim/init.lua ]; then
    cp ~/.config/nvim/init.lua ~/.config/nvim/init.lua.backup
    echo "📦 Backed up existing config to init.lua.backup"
fi

# Create ultra-minimal configuration that works on ANY Neovim version
cat > ~/.config/nvim/init.lua << '\''NVIM_CONFIG'\''
-- Ultra-minimal Neovim configuration
-- Works with ANY Neovim version

vim.g.mapleader = " "

-- ============== BASIC SETTINGS ==============
-- Using vim.cmd for maximum compatibility
vim.cmd [[
set autowrite
set clipboard=unnamedplus
set completeopt=menu,menuone,noselect
set confirm
set cursorline
set expandtab
set foldlevel=99
set foldmethod=indent
set ignorecase
set laststatus=2
set linebreak
set list
set mouse=a
set number
set relativenumber
set scrolloff=4
set shiftround
set shiftwidth=2
set showmode
set sidescrolloff=8
set signcolumn=yes
set smartcase
set smartindent
set splitbelow
set splitright
set tabstop=2
set termguicolors
set timeoutlen=300
set undofile
set undolevels=10000
set updatetime=200
set virtualedit=block
set wildmode=longest:full,full
set winminwidth=5
set nowrap
]]

-- ============== KEYMAPS ==============
local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap == nil and true or opts.noremap
  -- Remove 'desc' which older Neovim doesn't support
  opts.desc = nil
  vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
end

-- better up/down
map("n", "j", "gj", { silent = true })
map("n", "k", "gk", { silent = true })

-- Move to window using the <ctrl> hjkl keys
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase Window Height" })
map("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase Window Width" })

-- buffers
map("n", "<S-h>", ":bprevious<CR>", { desc = "Prev Buffer" })
map("n", "<S-l>", ":bnext<CR>", { desc = "Next Buffer" })
map("n", "[b", ":bprevious<CR>", { desc = "Prev Buffer" })
map("n", "]b", ":bnext<CR>", { desc = "Next Buffer" })
map("n", "<leader>bb", ":e #<CR>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete Buffer" })

-- Clear search with <esc>
map("n", "<Esc>", ":noh<CR><Esc>", { desc = "Clear search" })

-- save file
map("n", "<C-s>", ":w<CR>", { desc = "Save File" })
map("i", "<C-s>", "<Esc>:w<CR>a", { desc = "Save File" })

-- better indenting
map("v", "<", "<gv", {})
map("v", ">", ">gv", {})

-- new file
map("n", "<leader>fn", ":enew<CR>", { desc = "New File" })

-- quit
map("n", "<leader>qq", ":qa<CR>", { desc = "Quit All" })

-- windows
map("n", "<leader>ww", "<C-W>p", { desc = "Other Window" })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window" })
map("n", "<leader>w-", "<C-W>s", { desc = "Split Window Below" })
map("n", "<leader>w|", "<C-W>v", { desc = "Split Window Right" })
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below" })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right" })

-- tabs
map("n", "<leader><tab>l", ":tablast<CR>", { desc = "Last Tab" })
map("n", "<leader><tab>f", ":tabfirst<CR>", { desc = "First Tab" })
map("n", "<leader><tab><tab>", ":tabnew<CR>", { desc = "New Tab" })
map("n", "<leader><tab>]", ":tabnext<CR>", { desc = "Next Tab" })
map("n", "<leader><tab>d", ":tabclose<CR>", { desc = "Close Tab" })
map("n", "<leader><tab>[", ":tabprevious<CR>", { desc = "Previous Tab" })

-- File explorer
map("n", "<leader>e", ":Explore<CR>", { desc = "File Explorer" })
map("n", "-", ":Explore<CR>", { desc = "Open parent directory" })

-- Search
map("n", "<leader>/", "/", { desc = "Search" })

-- ============== COLORSCHEME ==============
vim.cmd [[
  try
    colorscheme slate
  catch
    colorscheme default
  endtry
]]

print("Ultra-minimal Neovim configuration loaded!")
print("Compatible with ANY Neovim version")
print("")
print("Key mappings:")
print("  <Space>e       - File explorer")
print("  <Space>/       - Search")
print("  <C-s>          - Save file")
print("  <Space>qq      - Quit all")
print("  Shift+h/l      - Navigate buffers")
NVIM_CONFIG

echo "✅ Fixed Neovim configuration!"
echo "The config should now work without any errors."
'

echo ""
echo "💡 Configuration fixed! Try running nvim again:"
echo "   kubectl exec -it -n $NAMESPACE $POD${CONTAINER:+ -c $CONTAINER} -- nvim"