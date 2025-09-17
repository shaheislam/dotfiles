#!/bin/bash
# Intelligent Neovim installation for Kubernetes pods/containers
# Automatically installs modern Neovim if needed and sets up LazyVim config
# Usage: ./install-nvim-in-pod.sh <namespace> <pod> [container]

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

echo "🚀 Setting up Neovim in pod $POD..."

# Install and configure Neovim
$EXEC_CMD -- sh -c '
# Check current Neovim version if installed
NEED_UPGRADE=0
if command -v nvim >/dev/null 2>&1; then
    CURRENT_VERSION=$(nvim --version | head -1 | grep -oE "[0-9]+\.[0-9]+" | head -1)
    echo "📊 Current Neovim version: $CURRENT_VERSION"

    # Check if version is modern enough (0.8+ for plugins)
    MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
    MINOR=$(echo $CURRENT_VERSION | cut -d. -f2)

    if [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 8 ]; then
        echo "⚠️  Neovim $CURRENT_VERSION is too old for plugins, attempting upgrade..."
        NEED_UPGRADE=1
    else
        echo "✅ Neovim $CURRENT_VERSION is modern enough!"
    fi
else
    echo "📦 Neovim not found, installing..."
    NEED_UPGRADE=1
fi

# Try to upgrade to modern Neovim if needed
if [ "$NEED_UPGRADE" -eq 1 ]; then
    # Detect architecture
    ARCH=$(uname -m)
    echo "🔍 Detected architecture: $ARCH"

    # First, try to install modern Neovim from AppImage or binary
    INSTALLED_MODERN=0

    # Try AppImage for x86_64 and aarch64
    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ]; then
        echo "📦 Attempting to install modern Neovim..."

        # Download URL based on architecture
        if [ "$ARCH" = "x86_64" ]; then
            NVIM_TARBALL_URL="https://github.com/neovim/neovim/releases/download/v0.10.2/nvim-linux64.tar.gz"
        else
            NVIM_TARBALL_URL=""  # ARM builds are less common
        fi

        # Try to download pre-built binary
        if [ -n "$NVIM_TARBALL_URL" ]; then
            echo "   Downloading pre-built binary..."
            if command -v curl >/dev/null 2>&1; then
                curl -L -o /tmp/nvim.tar.gz "$NVIM_TARBALL_URL" 2>/dev/null || true
            elif command -v wget >/dev/null 2>&1; then
                wget -q -O /tmp/nvim.tar.gz "$NVIM_TARBALL_URL" 2>/dev/null || true
            fi

            if [ -f /tmp/nvim.tar.gz ]; then
                echo "   Extracting Neovim..."
                tar -xzf /tmp/nvim.tar.gz -C /tmp/ 2>/dev/null || true
                if [ -d /tmp/nvim-linux64 ]; then
                    # Try to install system-wide first
                    if [ -w /usr/local/bin ]; then
                        cp -r /tmp/nvim-linux64/* /usr/local/ 2>/dev/null || true
                        INSTALLED_MODERN=1
                    else
                        # Install in user directory
                        mkdir -p ~/.local
                        cp -r /tmp/nvim-linux64 ~/.local/
                        mkdir -p ~/.local/bin
                        ln -sf ~/.local/nvim-linux64/bin/nvim ~/.local/bin/nvim
                        export PATH="$HOME/.local/bin:$PATH"
                        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc 2>/dev/null || true
                        INSTALLED_MODERN=1
                    fi
                    echo "✅ Modern Neovim installed successfully!"
                fi
                rm -rf /tmp/nvim.tar.gz /tmp/nvim-linux64
            fi
        fi
    fi

    # If modern binary installation failed, try package managers
    if [ "$INSTALLED_MODERN" -eq 0 ]; then
        echo "📦 Trying package managers for Neovim..."

        if command -v apt-get >/dev/null 2>&1; then
            echo "   Using apt-get..."
            apt-get update >/dev/null 2>&1
            # Try to add Neovim PPA for newer version
            DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || true
            add-apt-repository ppa:neovim-ppa/stable -y >/dev/null 2>&1 || true
            apt-get update >/dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt-get install -y neovim git curl 2>/dev/null || \
            DEBIAN_FRONTEND=noninteractive apt-get install -y neovim 2>/dev/null || true
        elif command -v apk >/dev/null 2>&1; then
            echo "   Using apk..."
            apk add --no-cache neovim git curl 2>/dev/null || \
            apk add --no-cache neovim 2>/dev/null || true
        elif command -v yum >/dev/null 2>&1; then
            echo "   Using yum..."
            yum install -y epel-release >/dev/null 2>&1 || true
            yum install -y neovim git curl 2>/dev/null || \
            yum install -y neovim 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            echo "   Using dnf..."
            dnf install -y epel-release >/dev/null 2>&1 || true
            dnf install -y neovim git curl 2>/dev/null || \
            dnf install -y neovim 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            echo "   Using pacman..."
            pacman -Sy --noconfirm neovim git curl 2>/dev/null || \
            pacman -Sy --noconfirm neovim 2>/dev/null || true
        fi
    fi
fi

# Ensure git is installed for plugins (if we have a package manager)
if ! command -v git >/dev/null 2>&1; then
    echo "📦 Installing git for plugin management..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y git 2>/dev/null || true
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache git 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y git 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y git 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm git 2>/dev/null || true
    fi
fi

# Install ripgrep and fd for Telescope functionality
echo "🔍 Installing search tools for Telescope..."

# Install build tools for telescope-fzf-native
echo "   Installing build tools for fzf extension..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y make gcc g++ 2>/dev/null || apt-get install -y make gcc 2>/dev/null || true
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache make gcc g++ musl-dev 2>/dev/null || apk add --no-cache make gcc 2>/dev/null || true
elif command -v yum >/dev/null 2>&1; then
    yum install -y make gcc gcc-c++ 2>/dev/null || yum install -y make gcc 2>/dev/null || true
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y make gcc gcc-c++ 2>/dev/null || dnf install -y make gcc 2>/dev/null || true
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm base-devel 2>/dev/null || pacman -Sy --noconfirm make gcc 2>/dev/null || true
fi

# Install ripgrep (for live_grep)
if ! command -v rg >/dev/null 2>&1; then
    echo "   Installing ripgrep..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y ripgrep 2>/dev/null || true
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache ripgrep 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y ripgrep 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ripgrep 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm ripgrep 2>/dev/null || true
    fi
fi

# Install fd (for find_files)
if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
    echo "   Installing fd..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y fd-find 2>/dev/null || true
        # Create fd symlink on Debian/Ubuntu
        if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
            ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || \
            ln -sf $(which fdfind) ~/.local/bin/fd 2>/dev/null || true
        fi
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache fd 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y fd-find 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y fd-find 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm fd 2>/dev/null || true
    fi
fi

# Make sure PATH includes local bin if we installed there
export PATH="$HOME/.local/bin:$PATH"

# Check final Neovim version
FINAL_VERSION="0.0"
if command -v nvim >/dev/null 2>&1; then
    FINAL_VERSION=$(nvim --version | head -1 | grep -oE "[0-9]+\.[0-9]+" | head -1)
    echo ""
    echo "📊 Final Neovim version: $FINAL_VERSION"
else
    echo "❌ Failed to install Neovim"
    exit 1
fi

# Create Neovim config directory
echo "📝 Setting up Neovim configuration..."
mkdir -p ~/.config/nvim
mkdir -p ~/.local/share/nvim
mkdir -p ~/.cache/nvim

# Create intelligent configuration that adapts to Neovim version
cat > ~/.config/nvim/init.lua << '\''NVIM_CONFIG'\''
-- Intelligent Neovim configuration
-- Automatically adapts to Neovim version

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ============== VERSION DETECTION ==============
local is_nvim_07_plus = vim.fn.has("nvim-0.7") == 1
local is_nvim_08_plus = vim.fn.has("nvim-0.8") == 1
local is_nvim_09_plus = vim.fn.has("nvim-0.9") == 1
local is_nvim_010_plus = vim.fn.has("nvim-0.10") == 1
local can_use_plugins = is_nvim_08_plus  -- Plugins require 0.8+

-- ============== BASIC SETTINGS ==============
local opt = vim.opt

-- Universal settings that work on all versions
opt.autowrite = true
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
opt.completeopt = "menu,menuone,noselect"
opt.conceallevel = 2
opt.confirm = true
opt.cursorline = true
opt.expandtab = true
opt.foldlevel = 99
opt.foldmethod = "indent"
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"
opt.ignorecase = true
opt.linebreak = true
opt.list = true
opt.mouse = "a"
opt.number = true
opt.pumheight = 10
opt.relativenumber = true
opt.scrolloff = 4
opt.shiftround = true
opt.shiftwidth = 2
opt.showmode = false
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.splitbelow = true
opt.splitright = true
opt.tabstop = 2
opt.termguicolors = true
opt.timeoutlen = 300
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200
opt.virtualedit = "block"
opt.wildmode = "longest:full,full"
opt.winminwidth = 5
opt.wrap = false

-- Settings that might need special handling
pcall(function() opt.formatoptions = "jcroqlnt" end)
pcall(function() opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" } end)
pcall(function() opt.shortmess:append({ W = true, I = true, c = true, C = true }) end)
pcall(function() opt.spelllang = { "en" } end)

-- Neovim 0.7+ specific options
if is_nvim_07_plus then
  pcall(function() opt.laststatus = 3 end)
  pcall(function() opt.pumblend = 10 end)
  pcall(function()
    opt.fillchars = {
      foldopen = "",
      foldclose = "",
      fold = " ",
      foldsep = " ",
      diff = "╱",
      eob = " ",
    }
  end)
else
  opt.laststatus = 2
end

-- Neovim 0.8+ specific options
if is_nvim_08_plus then
  pcall(function() opt.splitkeep = "screen" end)
  pcall(function() opt.inccommand = "nosplit" end)
end

-- Neovim 0.9+ specific options
if is_nvim_09_plus then
  pcall(function() opt.jumpoptions = "view" end)
end

-- Neovim 0.10+ specific options
if is_nvim_010_plus then
  pcall(function() opt.smoothscroll = true end)
end

-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0

-- ============== PLUGIN SYSTEM ==============
if can_use_plugins then
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

  -- Enhanced plugin setup for containers (closer to LazyVim experience)
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.setup({
      -- Essential plugins with LazyVim-like visuals
      {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
          require("tokyonight").setup({
            style = "night",
            transparent = false,
            terminal_colors = true,
            styles = {
              comments = { italic = true },
              keywords = { italic = true },
              sidebars = "dark",
              floats = "dark",
            },
            sidebars = { "qf", "help", "terminal", "packer" },
            day_brightness = 0.3,
            hide_inactive_statusline = false,
            dim_inactive = false,
            lualine_bold = false,
          })
          vim.cmd.colorscheme("tokyonight-night")
        end,
      },
      -- Statusline for better visual feedback
      {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = {
          options = {
            theme = "tokyonight",
            icons_enabled = true,
            component_separators = "|",
            section_separators = "",
            globalstatus = true,
          },
          sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch", "diff", "diagnostics" },
            lualine_c = { { "filename", path = 1 } },
            lualine_x = { "encoding", "fileformat", "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" }
          },
        },
      },
      -- Buffer line for tab-like experience
      {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        opts = {
          options = {
            mode = "buffers",
            themable = true,
            numbers = "none",
            close_command = "bdelete! %d",
            right_mouse_command = "bdelete! %d",
            indicator = {
              icon = "▎",
              style = "icon",
            },
            buffer_close_icon = "✗",
            modified_icon = "●",
            close_icon = "✗",
            left_trunc_marker = "",
            right_trunc_marker = "",
            diagnostics = "nvim_lsp",
            diagnostics_indicator = function(count, level)
              local icon = level:match("error") and " " or " "
              return " " .. icon .. count
            end,
            offsets = {
              {
                filetype = "oil",
                text = "File Explorer",
                text_align = "left",
                separator = true,
              }
            },
            color_icons = true,
            show_buffer_icons = true,
            show_buffer_close_icons = true,
            show_close_icon = true,
            show_tab_indicators = true,
            separator_style = "thin",
            always_show_bufferline = true,
          },
        },
      },
      -- Better UI elements
      {
        "stevearc/dressing.nvim",
        event = "VeryLazy",
        opts = {
          input = {
            enabled = true,
            default_prompt = "Input:",
            prompt_align = "left",
            insert_only = true,
            border = "rounded",
            relative = "cursor",
            prefer_width = 40,
            width = nil,
            max_width = { 140, 0.9 },
            min_width = { 20, 0.2 },
            win_options = {
              winblend = 0,
            },
          },
          select = {
            enabled = true,
            backend = { "telescope", "builtin" },
            builtin = {
              border = "rounded",
              relative = "editor",
              win_options = {
                winblend = 10,
              },
            },
          },
        },
      },
      -- Indent guides for better code visibility
      {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = "VeryLazy",
        opts = {
          indent = {
            char = "│",
            tab_char = "│",
          },
          scope = { enabled = false },
          exclude = {
            filetypes = {
              "help",
              "alpha",
              "dashboard",
              "lazy",
              "mason",
              "notify",
              "toggleterm",
            },
          },
        },
      },
      -- Which-key for discovering keybindings
      {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
          local wk = require("which-key")
          wk.setup({
            plugins = {
              marks = false,
              registers = false,
              spelling = { enabled = false },
              presets = {
                operators = false,
                motions = false,
                text_objects = false,
                windows = false,
                nav = false,
                z = false,
                g = false,
              },
            },
            key_labels = {
              ["<space>"] = "SPC",
              ["<cr>"] = "RET",
              ["<tab>"] = "TAB",
            },
            window = {
              border = "rounded",
              position = "bottom",
              margin = { 1, 0, 1, 0 },
              padding = { 2, 2, 2, 2 },
              winblend = 0,
            },
            layout = {
              height = { min = 4, max = 25 },
              width = { min = 20, max = 50 },
              spacing = 3,
              align = "left",
            },
          })
          -- Register key groups
          wk.register({
            ["<leader>"] = {
              f = { name = "+find" },
              g = { name = "+git" },
              b = { name = "+buffer" },
              c = { name = "+code" },
            }
          })
        end,
      },
      {
        "nvim-telescope/telescope.nvim",
        cmd = "Telescope",
        dependencies = {
          "nvim-lua/plenary.nvim",
          {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make || cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
          },
        },
        keys = {
          { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
          { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
          { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
          { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
          { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent Files" },
          { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files (quick)" },
          { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep (quick)" },
        },
        config = function()
          local telescope = require("telescope")
          telescope.setup({
            defaults = {
              prompt_prefix = " ",
              selection_caret = " ",
              layout_config = {
                horizontal = {
                  prompt_position = "top",
                  preview_width = 0.55,
                },
                width = 0.87,
                height = 0.80,
              },
              sorting_strategy = "ascending",
              file_ignore_patterns = { "node_modules", ".git/" },
            },
            extensions = {
              fzf = {
                fuzzy = true,
                override_generic_sorter = true,
                override_file_sorter = true,
                case_mode = "smart_case",
              },
            },
          })
          -- Load fzf extension for better fuzzy finding
          telescope.load_extension("fzf")
        end,
      },
      -- Oil.nvim file explorer (fast and simple)
      {
        "stevearc/oil.nvim",
        keys = {
          { "<leader>e", function() require("oil").open() end, desc = "File Explorer" },
          { "-", function() require("oil").open() end, desc = "Open parent directory" },
        },
        opts = {
          default_file_explorer = true,
          columns = {
            "icon",
            "permissions",
            "size",
            "mtime",
          },
          buf_options = {
            buflisted = false,
            bufhidden = "hide",
          },
          win_options = {
            wrap = false,
            signcolumn = "no",
            cursorcolumn = false,
            foldcolumn = "0",
            spell = false,
            list = false,
            conceallevel = 3,
            concealcursor = "nvic",
          },
          delete_to_trash = false,
          skip_confirm_for_simple_edits = false,
          prompt_save_on_select_new_entry = true,
          cleanup_delay_ms = 2000,
          keymaps = {
            ["g?"] = "actions.show_help",
            ["<CR>"] = "actions.select",
            ["<C-s>"] = "actions.select_vsplit",
            ["<C-h>"] = "actions.select_split",
            ["<C-t>"] = "actions.select_tab",
            ["<C-p>"] = "actions.preview",
            ["<C-c>"] = "actions.close",
            ["<C-l>"] = "actions.refresh",
            ["-"] = "actions.parent",
            ["_"] = "actions.open_cwd",
            ["`"] = "actions.cd",
            ["~"] = "actions.tcd",
            ["gs"] = "actions.change_sort",
            ["gx"] = "actions.open_external",
            ["g."] = "actions.toggle_hidden",
            ["g\\"] = "actions.toggle_trash",
          },
          use_default_keymaps = true,
          view_options = {
            show_hidden = false,
            is_hidden_file = function(name, bufnr)
              return vim.startswith(name, ".")
            end,
            is_always_hidden = function(name, bufnr)
              return false
            end,
            sort = {
              { "type", "asc" },
              { "name", "asc" },
            },
          },
          float = {
            padding = 2,
            max_width = 0,
            max_height = 0,
            border = "rounded",
            win_options = {
              winblend = 0,
            },
            override = function(conf)
              return conf
            end,
          },
        },
      },
      {
        "lewis6991/gitsigns.nvim",
        event = "VeryLazy",
        opts = {
          signs = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "" },
            topdelete = { text = "" },
            changedelete = { text = "▎" },
            untracked = { text = "▎" },
          },
          signcolumn = true,
          numhl = false,
          linehl = false,
          word_diff = false,
          watch_gitdir = {
            interval = 1000,
            follow_files = true,
          },
          attach_to_untracked = true,
          current_line_blame = false,
          current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol",
            delay = 1000,
          },
          sign_priority = 6,
          update_debounce = 100,
          status_formatter = nil,
          max_file_length = 40000,
          preview_config = {
            border = "single",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1,
          },
        },
      },
      {
        "numToStr/Comment.nvim",
        keys = {
          { "gcc", desc = "Comment line" },
          { "gc", mode = { "n", "v" }, desc = "Comment" },
        },
        opts = {},
      },
      {
        "echasnovski/mini.nvim",
        version = false,
        event = "VeryLazy",
        config = function()
          require("mini.pairs").setup()
          require("mini.surround").setup()
          require("mini.ai").setup()
        end,
      },
    })
    print("Enhanced LazyVim-like configuration loaded!")
  else
    print("Failed to load lazy.nvim")
  end
else
  -- No plugins for older Neovim
  print("Neovim " .. vim.fn.matchstr(vim.fn.execute("version"), "NVIM v\\zs[^\\n]*"))
  print("Plugins require Neovim 0.8+")
  print("Basic configuration loaded without plugins")

  -- Set a basic colorscheme
  vim.cmd [[
    try
      colorscheme slate
    catch
      colorscheme default
    endtry
  ]]
end

-- ============== KEYMAPS ==============
-- Create universal keymap function
local map = vim.keymap or {}
if not vim.keymap then
  -- Fallback for older Neovim
  map.set = function(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    opts.desc = nil  -- Remove desc for older versions

    if type(mode) == "table" then
      for _, m in ipairs(mode) do
        vim.api.nvim_set_keymap(m, lhs, rhs, opts)
      end
    else
      vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
    end
  end
end

-- Essential keymaps
map.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map.set("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit All" })

-- Window navigation
map.set("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map.set("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map.set("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map.set("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Buffer navigation
map.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- Better indenting
map.set("v", "<", "<gv", {})
map.set("v", ">", ">gv", {})

-- Clear search with <esc>
map.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Clear search" })

-- File explorer (fallback for no plugins)
if not can_use_plugins then
  map.set("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File Explorer" })
  map.set("n", "-", "<cmd>Explore<cr>", { desc = "Open parent directory" })
  map.set("n", "<leader><space>", ":e ", { desc = "Open file" })
  map.set("n", "<leader>/", "/", { desc = "Search" })
end

-- ============== AUTOCOMMANDS ==============
-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = vim.api.nvim_create_augroup("json_conceal", {}),
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

print("")
print("Ready! Press <Space> for leader key")
NVIM_CONFIG

# Final summary
echo ""
echo "✅ Neovim setup complete!"

# Show what was installed
MAJOR=$(echo $FINAL_VERSION | cut -d. -f1)
MINOR=$(echo $FINAL_VERSION | cut -d. -f2)

if [ "$MAJOR" -gt 0 ] || [ "$MINOR" -ge 8 ]; then
    echo "   Version: $FINAL_VERSION (with plugins)"

    # Try to install plugins if git is available
    if command -v git >/dev/null 2>&1 && command -v nvim >/dev/null 2>&1; then
        echo "   Installing plugins..."
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
else
    echo "   Version: $FINAL_VERSION (basic config, no plugins)"
fi

echo ""
echo "💡 Key mappings:"
echo "   <Space>       - Leader key"
echo "   <Space>e      - File explorer"
echo "   <Space>w      - Save file"
echo "   <Space>q      - Quit"

if [ "$MAJOR" -gt 0 ] || [ "$MINOR" -ge 8 ]; then
    echo "   <Space>ff     - Find files (Telescope)"
    echo "   <Space>fg     - Live grep (Telescope)"
    echo "   <Space>fb     - Buffers (Telescope)"
    echo "   <Space>fr     - Recent files (Telescope)"
    echo "   gcc           - Comment line"
fi
'

echo ""
echo "🎉 Setup complete! You can now use Neovim in the pod:"
echo "   kubectl exec -it -n $NAMESPACE $POD${CONTAINER:+ -c $CONTAINER} -- nvim"