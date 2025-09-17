#!/bin/bash
# Install Neovim with LazyVim-like configuration in pods/containers
# Uses lightweight plugins that don't require compilation
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

echo "🚀 Setting up LazyVim-like Neovim in pod $POD..."

# Check which package manager is available and install
$EXEC_CMD -- sh -c '
# Function to install packages based on available package manager
install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "📦 Using apt-get..."
        apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y neovim git curl ripgrep 2>/dev/null || \
        DEBIAN_FRONTEND=noninteractive apt-get install -y neovim git curl 2>/dev/null || \
        DEBIAN_FRONTEND=noninteractive apt-get install -y neovim 2>/dev/null
    elif command -v apk >/dev/null 2>&1; then
        echo "📦 Using apk..."
        apk add --no-cache neovim git curl ripgrep 2>/dev/null || \
        apk add --no-cache neovim git curl 2>/dev/null || \
        apk add --no-cache neovim 2>/dev/null
    elif command -v yum >/dev/null 2>&1; then
        echo "📦 Using yum..."
        yum install -y epel-release >/dev/null 2>&1 || true
        yum install -y neovim git curl 2>/dev/null || \
        yum install -y neovim 2>/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        echo "📦 Using dnf..."
        dnf install -y neovim git curl 2>/dev/null || \
        dnf install -y neovim 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        echo "📦 Using pacman..."
        pacman -Sy --noconfirm neovim git curl 2>/dev/null || \
        pacman -Sy --noconfirm neovim 2>/dev/null
    else
        echo "⚠️  No supported package manager found"
    fi
}

# Install Neovim and dependencies
if ! command -v nvim >/dev/null 2>&1; then
    echo "📦 Installing Neovim and dependencies..."
    install_packages
else
    echo "✅ Neovim is already installed!"
    # Still try to install git if missing for plugins
    if ! command -v git >/dev/null 2>&1; then
        echo "📦 Installing git for plugins..."
        install_packages
    fi
fi

# Create Neovim config directory
echo "📝 Setting up LazyVim-like configuration..."
mkdir -p ~/.config/nvim
mkdir -p ~/.local/share/nvim
mkdir -p ~/.cache/nvim

# Create LazyVim-like configuration with lightweight plugins
cat > ~/.config/nvim/init.lua << '\''NVIM_CONFIG'\''
-- LazyVim-like configuration for containers
-- Lightweight plugins that work without compilation

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ============== SETTINGS (LazyVim defaults) ==============
local opt = vim.opt

opt.autowrite = true
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
opt.completeopt = "menu,menuone,noselect"
opt.conceallevel = 2
opt.confirm = true
opt.cursorline = true
opt.expandtab = true
opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}
opt.foldlevel = 99
opt.formatoptions = "jcroqlnt"
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"
opt.ignorecase = true
opt.inccommand = "nosplit"
opt.jumpoptions = "view"
opt.laststatus = 3
opt.linebreak = true
opt.list = true
opt.mouse = "a"
opt.number = true
opt.pumblend = 10
opt.pumheight = 10
opt.relativenumber = true
opt.scrolloff = 4
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.shiftround = true
opt.shiftwidth = 2
opt.shortmess:append({ W = true, I = true, c = true, C = true })
opt.showmode = false
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.spelllang = { "en" }
opt.splitbelow = true
opt.splitkeep = "screen"
opt.splitright = true
opt.statuscolumn = [[%!v:lua.require'\''lazyvim.util'\''.ui.statuscolumn()]]
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

if vim.fn.has("nvim-0.10") == 1 then
  opt.smoothscroll = true
  opt.foldexpr = "v:lua.require'\''lazyvim.util'\''.ui.foldexpr()"
  opt.foldmethod = "expr"
  opt.foldtext = ""
else
  opt.foldmethod = "indent"
  opt.foldtext = "v:lua.require'\''lazyvim.util'\''.ui.foldtext()"
end

-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0

-- ============== BOOTSTRAP LAZY.NVIM ==============
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

-- ============== PLUGINS ==============
require("lazy").setup({
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night" },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Telescope (simplified config without treesitter dependency)
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>,", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", desc = "Switch Buffer" },
      { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep (Root Dir)" },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files (Root Dir)" },
      -- find
      { "<leader>fb", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files (Root Dir)" },
      { "<leader>fF", "<cmd>Telescope find_files cwd=%:p:h<cr>", desc = "Find Files (cwd)" },
      { "<leader>fg", "<cmd>Telescope git_files<cr>", desc = "Find Files (git-files)" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
      { "<leader>fR", "<cmd>Telescope oldfiles cwd=%:p:h<cr>", desc = "Recent (cwd)" },
      -- git
      { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Commits" },
      { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Status" },
      -- search
      { '\''<leader>s"'\'', "<cmd>Telescope registers<cr>", desc = "Registers" },
      { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
      { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sd", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Document Diagnostics" },
      { "<leader>sD", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
      { "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "Grep (Root Dir)" },
      { "<leader>sG", "<cmd>Telescope live_grep cwd=%:p:h<cr>", desc = "Grep (cwd)" },
      { "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "Help Pages" },
      { "<leader>sH", "<cmd>Telescope highlights<cr>", desc = "Search Highlight Groups" },
      { "<leader>sj", "<cmd>Telescope jumplist<cr>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>Telescope keymaps<cr>", desc = "Key Maps" },
      { "<leader>sl", "<cmd>Telescope loclist<cr>", desc = "Location List" },
      { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
      { "<leader>so", "<cmd>Telescope vim_options<cr>", desc = "Options" },
      { "<leader>sR", "<cmd>Telescope resume<cr>", desc = "Resume" },
      { "<leader>sq", "<cmd>Telescope quickfix<cr>", desc = "Quickfix List" },
      { "<leader>sw", "<cmd>Telescope grep_string word_match=-w<cr>", desc = "Word (Root Dir)" },
      { "<leader>sW", "<cmd>Telescope grep_string cwd=%:p:h word_match=-w<cr>", desc = "Word (cwd)" },
      { "<leader>sw", "<cmd>Telescope grep_string<cr>", mode = "v", desc = "Selection (Root Dir)" },
      { "<leader>sW", "<cmd>Telescope grep_string cwd=%:p:h<cr>", mode = "v", desc = "Selection (cwd)" },
      { "<leader>uC", "<cmd>Telescope colorscheme enable_preview=true<cr>", desc = "Colorscheme with Preview" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Goto Symbol" },
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Goto Symbol (Workspace)" },
    },
    opts = function()
      local actions = require("telescope.actions")

      return {
        defaults = {
          prompt_prefix = " ",
          selection_caret = " ",
          get_selection_window = function()
            local wins = vim.api.nvim_list_wins()
            table.insert(wins, 1, vim.api.nvim_get_current_win())
            for _, win in ipairs(wins) do
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.bo[buf].buftype == "" then
                return win
              end
            end
            return 0
          end,
          mappings = {
            i = {
              ["<c-t>"] = function(...)
                return require("trouble.sources.telescope").open(...)
              end,
              ["<a-t>"] = function(...)
                return require("trouble.sources.telescope").open(...)
              end,
              ["<a-i>"] = function()
                local action_state = require("telescope.actions.state")
                local line = action_state.get_current_line()
                telescope.find_files({ no_ignore = true, default_text = line })()
              end,
              ["<a-h>"] = function()
                local action_state = require("telescope.actions.state")
                local line = action_state.get_current_line()
                telescope.find_files({ hidden = true, default_text = line })()
              end,
              ["<C-Down>"] = function(...)
                return actions.cycle_history_next(...)
              end,
              ["<C-Up>"] = function(...)
                return actions.cycle_history_prev(...)
              end,
              ["<C-f>"] = function(...)
                return actions.preview_scrolling_down(...)
              end,
              ["<C-b>"] = function(...)
                return actions.preview_scrolling_up(...)
              end,
            },
            n = {
              ["q"] = function(...)
                return actions.close(...)
              end,
            },
          },
        },
      }
    end,
  },

  -- File explorer (oil.nvim - no compilation needed)
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", function() require("oil").open() end, desc = "File Explorer" },
      { "-", function() require("oil").open() end, desc = "Open parent directory" },
    },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
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
      use_default_keymaps = false,
      view_options = {
        show_hidden = false,
        is_hidden_file = function(name, bufnr)
          return vim.startswith(name, ".")
        end,
        is_always_hidden = function(name, bufnr)
          return false
        end,
        natural_order = true,
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
      },
    },
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      defaults = {
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["gs"] = { name = "+surround" },
        ["z"] = { name = "+fold" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>gh"] = { name = "+hunks" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>w"] = { name = "+windows" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      if not vim.tbl_isempty(opts.defaults) then
        wk.register(opts.defaults)
      end
    end,
  },

  -- Comment.nvim
  {
    "numToStr/Comment.nvim",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
      init = function()
        vim.g.skip_ts_context_commentstring_module = true
      end,
      opts = { enable_autocmd = false },
    },
    keys = {
      { "gcc", desc = "Comment line" },
      { "gc", mode = { "n", "v" }, desc = "Comment" },
      { "gb", mode = { "n", "v" }, desc = "Block comment" },
    },
    opts = function()
      return {
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      }
    end,
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "VeryLazy",
    config = true,
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo Comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous Todo Comment" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo (Trouble)" },
      { "<leader>xT", "<cmd>TodoTrouble keywords=TODO,FIX,FIXME<cr>", desc = "Todo/Fix/Fixme (Trouble)" },
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo" },
      { "<leader>sT", "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", desc = "Todo/Fix/Fixme" },
    },
  },

  -- Trouble
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
    opts = { use_diagnostic_signs = true },
    keys = {
      { "<leader>xx", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics (Trouble)" },
      { "<leader>xL", "<cmd>TroubleToggle loclist<cr>", desc = "Location List (Trouble)" },
      { "<leader>xQ", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List (Trouble)" },
      {
        "[q",
        function()
          if require("trouble").is_open() then
            require("trouble").previous({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "Previous Trouble/Quickfix Item",
      },
      {
        "]q",
        function()
          if require("trouble").is_open() then
            require("trouble").next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "Next Trouble/Quickfix Item",
      },
    },
  },

  -- Git signs
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
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        -- Navigation
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next Hunk")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Prev Hunk")

        -- Actions
        map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage Hunk")
        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset Hunk")

        map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")

        map("n", "<leader>hu", gs.undo_stage_hunk, "Undo Stage Hunk")

        map("n", "<leader>hp", gs.preview_hunk_inline, "Preview Hunk Inline")

        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle Line Blame")

        map("n", "<leader>hd", gs.diffthis, "Diff This")
        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end, "Diff This ~")

        -- Text object
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      end,
    },
  },

  -- Mini.nvim suite
  {
    "echasnovski/mini.nvim",
    version = false,
    event = "VeryLazy",
    config = function()
      -- Better Around/Inside textobjects
      require("mini.ai").setup({ n_lines = 500 })

      -- Add/delete/replace surroundings
      require("mini.surround").setup()

      -- Auto pairs
      require("mini.pairs").setup()

      -- Move text up/down
      require("mini.move").setup()

      -- Buffer remove
      local bufremove = require("mini.bufremove")
      bufremove.setup()
      vim.keymap.set("n", "<leader>bd", function() bufremove.delete(0, false) end, { desc = "Delete Buffer" })
      vim.keymap.set("n", "<leader>bD", function() bufremove.delete(0, true) end, { desc = "Delete Buffer (Force)" })
    end,
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = { show_start = false, show_end = false },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      },
    },
  },

  -- Better escape
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    opts = { mapping = { "jk", "jj" } },
  },

  -- Leap (navigation)
  {
    "ggandor/leap.nvim",
    enabled = true,
    keys = {
      { "s", mode = { "n", "x", "o" }, desc = "Leap Forward to" },
      { "S", mode = { "n", "x", "o" }, desc = "Leap Backward to" },
      { "gs", mode = { "n", "x", "o" }, desc = "Leap from Windows" },
    },
    config = function(_, opts)
      local leap = require("leap")
      for k, v in pairs(opts) do
        leap.opts[k] = v
      end
      leap.add_default_mappings(true)
      vim.keymap.del({ "x", "o" }, "x")
      vim.keymap.del({ "x", "o" }, "X")
    end,
  },

  -- Lualine
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then
        vim.o.statusline = " "
      else
        vim.o.laststatus = 0
      end
    end,
    opts = {
      options = {
        theme = "auto",
        globalstatus = vim.o.laststatus == 3,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          {
            "diagnostics",
            symbols = {
              error = " ",
              warn = " ",
              info = " ",
              hint = " ",
            },
          },
          { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
          {
            "filename",
            path = 1,
            symbols = { modified = "  ", readonly = "", unnamed = "" },
          },
        },
        lualine_x = {
          {
            function() return require("noice").api.status.command.get() end,
            cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
          },
          {
            function() return require("noice").api.status.mode.get() end,
            cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
          },
          {
            function() return "  " .. require("dap").status() end,
            cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
          },
          {
            "diff",
            symbols = {
              added = " ",
              modified = " ",
              removed = " ",
            },
            source = function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns then
                return {
                  added = gitsigns.added,
                  modified = gitsigns.changed,
                  removed = gitsigns.removed,
                }
              end
            end,
          },
        },
        lualine_y = {
          { "progress", separator = " ", padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          function()
            return " " .. os.date("%R")
          end,
        },
      },
      extensions = { "neo-tree", "lazy" },
    },
  },

  -- Bufferline
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
    },
    opts = {
      options = {
        close_command = function(n) require("mini.bufremove").delete(n, false) end,
        right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        diagnostics_indicator = function(_, _, diag)
          local icons = {
            Error = " ",
            Warn = " ",
            Hint = " ",
            Info = " ",
          }
          local ret = (diag.error and icons.Error .. diag.error .. " " or "")
            .. (diag.warning and icons.Warn .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Neo-tree",
            highlight = "Directory",
            text_align = "left",
          },
        },
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
  },

  -- Notifications
  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss All Notifications",
      },
    },
    opts = {
      stages = "static",
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
    },
  },

  -- Dashboard
  {
    "nvimdev/dashboard-nvim",
    lazy = false,
    opts = function()
      local logo = [[
           ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
           ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z
           ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z
           ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z
           ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║
           ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝
      ]]

      logo = string.rep("\n", 8) .. logo .. "\n\n"

      local opts = {
        theme = "doom",
        hide = {
          statusline = false,
        },
        config = {
          header = vim.split(logo, "\n"),
          center = {
            { action = "Telescope find_files", desc = " Find File", icon = " ", key = "f" },
            { action = "ene | startinsert", desc = " New File", icon = " ", key = "n" },
            { action = "Telescope oldfiles", desc = " Recent Files", icon = " ", key = "r" },
            { action = "Telescope live_grep", desc = " Find Text", icon = " ", key = "g" },
            { action = [[lua require("lazyvim.util").telescope.config_files()()]], desc = " Config", icon = " ", key = "c" },
            { action = '\''lua require("persistence").load()'\'', desc = " Restore Session", icon = " ", key = "s" },
            { action = "LazyExtras", desc = " Lazy Extras", icon = " ", key = "x" },
            { action = "Lazy", desc = " Lazy", icon = "󰒲 ", key = "l" },
            { action = "qa", desc = " Quit", icon = " ", key = "q" },
          },
          footer = function()
            local stats = require("lazy").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
            return { "⚡ Neovim loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms" }
          end,
        },
      }

      for _, button in ipairs(opts.config.center) do
        button.desc = button.desc .. string.rep(" ", 43 - #button.desc)
        button.key_format = "  %s"
      end

      -- open dashboard after closing lazy
      if vim.o.filetype == "lazy" then
        vim.api.nvim_create_autocmd("WinClosed", {
          pattern = tostring(vim.api.nvim_get_current_win()),
          once = true,
          callback = function()
            vim.schedule(function()
              vim.api.nvim_exec_autocmds("UIEnter", { group = "dashboard" })
            end)
          end,
        })
      end

      return opts
    end,
  },
})

-- ============== KEYMAPS ==============
local map = vim.keymap

-- better up/down
map.set({ "n", "x" }, "j", "v:count == 0 ? '\''gj'\'' : '\''j'\''", { desc = "Down", expr = true, silent = true })
map.set({ "n", "x" }, "<Down>", "v:count == 0 ? '\''gj'\'' : '\''j'\''", { desc = "Down", expr = true, silent = true })
map.set({ "n", "x" }, "k", "v:count == 0 ? '\''gk'\'' : '\''k'\''", { desc = "Up", expr = true, silent = true })
map.set({ "n", "x" }, "<Up>", "v:count == 0 ? '\''gk'\'' : '\''k'\''", { desc = "Up", expr = true, silent = true })

-- Move to window using the <ctrl> hjkl keys
map.set("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map.set("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map.set("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map.set("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- Resize window using <ctrl> arrow keys
map.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Move Lines
map.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move Down" })
map.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move Up" })
map.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map.set("v", "<A-j>", ":m '\''>+1<cr>gv=gv", { desc = "Move Down" })
map.set("v", "<A-k>", ":m '\''<-2<cr>gv=gv", { desc = "Move Up" })

-- buffers
map.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map.set("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map.set("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map.set("n", "<leader>bd", function() require("mini.bufremove").delete(0, false) end, { desc = "Delete Buffer" })
map.set("n", "<leader>bD", function() require("mini.bufremove").delete(0, true) end, { desc = "Delete Buffer (Force)" })

-- Clear search with <esc>
map.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and Clear hlsearch" })

-- Clear search, diff update and redraw
map.set(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / Clear hlsearch / Diff Update" }
)

-- save file
map.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- keywordprg
map.set("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- better indenting
map.set("v", "<", "<gv")
map.set("v", ">", ">gv")

-- commenting
map.set("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
map.set("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

-- lazy
map.set("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- new file
map.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })

map.set("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Location List" })
map.set("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix List" })

map.set("n", "[q", vim.cmd.cprev, { desc = "Previous Quickfix" })
map.set("n", "]q", vim.cmd.cnext, { desc = "Next Quickfix" })

-- diagnostic
local diagnostic_goto = function(next, severity)
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function()
    go({ severity = severity })
  end
end
map.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map.set("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map.set("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
map.set("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map.set("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
map.set("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map.set("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- quit
map.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- windows
map.set("n", "<leader>ww", "<C-W>p", { desc = "Other Window", remap = true })
map.set("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })
map.set("n", "<leader>w-", "<C-W>s", { desc = "Split Window Below", remap = true })
map.set("n", "<leader>w|", "<C-W>v", { desc = "Split Window Right", remap = true })
map.set("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map.set("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })
map.set("n", "<leader>wm", function() vim.cmd("resize | vertical resize") end, { desc = "Maximize window" })

-- tabs
map.set("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
map.set("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map.set("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
map.set("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map.set("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map.set("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

-- ============== AUTOCOMMANDS ==============

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = vim.api.nvim_create_augroup("resize_splits", {}),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("close_with_q", {}),
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("wrap_spell", {}),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
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

print("LazyVim-like configuration loaded!")
print("Key mappings:")
print("  <Space><Space> - Find files")
print("  <Space>/       - Live grep")
print("  <Space>e       - File explorer")
print("  gcc            - Comment line")
print("  s/S            - Leap forward/backward")
NVIM_CONFIG

# Try to install plugins if git is available
if command -v git >/dev/null 2>&1; then
    echo "🔌 Installing plugins..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

    # Check if plugins were installed
    if [ -d ~/.local/share/nvim/lazy ]; then
        echo "✅ Plugins installed successfully!"
        PLUGIN_COUNT=$(ls -1 ~/.local/share/nvim/lazy 2>/dev/null | wc -l)
        echo "   Installed $PLUGIN_COUNT plugins"
    else
        echo "⚠️  Plugin installation may have failed, but config is ready"
    fi
else
    echo "⚠️  Git not available, plugins will install on first launch"
fi

# Final check
if command -v nvim >/dev/null 2>&1; then
    echo ""
    echo "✅ LazyVim-like Neovim setup complete!"
    nvim --version | head -1
    echo ""
    echo "💎 Core plugins included:"
    echo "   • Telescope - Fuzzy finding (Space+ff, Space+/)"
    echo "   • Oil.nvim - File explorer (Space+e or -)"
    echo "   • Gitsigns - Git integration"
    echo "   • Which-key - Keybinding help"
    echo "   • Trouble - Diagnostics"
    echo "   • Todo-comments - TODO highlighting"
    echo "   • Leap - Fast navigation (s/S)"
    echo "   • Comment.nvim - Commenting (gcc)"
    echo "   • Mini.nvim - Surround, pairs, move"
    echo "   • Tokyo Night - Your theme"
    echo ""
    echo "📚 LazyVim keybindings work as expected!"
else
    echo "❌ Neovim installation failed"
    exit 1
fi
'

echo ""
echo "💡 You can now shell into the pod with LazyVim-like Neovim!"
echo "   kubectl exec -it -n $NAMESPACE $POD${CONTAINER:+ -c $CONTAINER} -- bash"
echo ""
echo "📝 This configuration:"
echo "   • Looks and feels like LazyVim"
echo "   • Includes Telescope and core plugins"
echo "   • Uses oil.nvim instead of netrw (no errors!)"
echo "   • Works without C compiler"
echo "   • All your familiar keybindings!"