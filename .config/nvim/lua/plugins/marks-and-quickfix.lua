-- Enhanced Marks and Quickfix List Management
-- marks.nvim: Visual bookmark indicators in the sign column
-- quicker.nvim: Better quickfix/location list management

return {
  -- Visual bookmark/mark indicators
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      -- Whether to map keybinds or not
      default_mappings = true,
      -- Which builtin marks to show (0 = disabled)
      builtin_marks = { ".", "<", ">", "^" },
      -- Whether movements cycle back to the beginning/end of buffer
      cyclic = true,
      -- Whether the shada file is updated after modifying uppercase marks
      force_write_shada = false,
      -- How often (in ms) to redraw signs/recompute mark positions
      refresh_interval = 250,
      -- Sign priorities for each type of mark
      sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
      -- Disables mark tracking for specific filetypes
      excluded_filetypes = {
        "qf",
        "NvimTree",
        "neo-tree",
        "toggleterm",
        "TelescopePrompt",
        "alpha",
        "netrw",
      },
      -- Marks.nvim allows you to configure up to 10 bookmark groups
      bookmark_0 = {
        sign = "⚑",
        virt_text = "bookmark",
        -- Highlight group for the annotation (defaults to anno_texthl)
        annotate = false,
      },
      mappings = {
        toggle = "m,",           -- Toggle the next available mark at the current line
        delete_line = "m-",      -- Delete all marks on the current line
        delete_buf = "m<space>", -- Delete all marks in the current buffer
        next = "m]",             -- Go to next mark
        prev = "m[",             -- Go to previous mark
        preview = "m:",          -- Preview mark (requires telescope)
        -- Bookmark mappings
        set_bookmark0 = "m0",
        delete_bookmark0 = "dm0",
        next_bookmark0 = "]0",
        prev_bookmark0 = "[0",
      },
    },
  },

  -- Better quickfix and location list management
  {
    "stevearc/quicker.nvim",
    event = "VeryLazy",
    opts = {
      -- Local options to set for quickfix buffers
      opts = {
        buflisted = false,
        number = false,
        relativenumber = false,
        signcolumn = "no",
        winfixheight = true,
        wrap = false,
      },
      -- Set to false to disable the default keymaps
      keys = {
        {
          ">",
          function()
            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
          end,
          desc = "Expand quickfix context",
        },
        {
          "<",
          function()
            require("quicker").collapse()
          end,
          desc = "Collapse quickfix context",
        },
      },
      -- Callback function to run any custom logic or keymaps for the quickfix buffer
      on_qf = function(bufnr)
        -- Add custom keymaps for quickfix buffer
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Refresh quickfix list
        map("n", "r", function()
          require("quicker").refresh()
        end, "Refresh quickfix")

        -- Toggle quickfix open/close
        map("n", "q", function()
          require("quicker").close()
        end, "Close quickfix")

        -- Open entry and close quickfix
        map("n", "<CR>", function()
          vim.cmd([[.cc]])
          require("quicker").close()
        end, "Open and close quickfix")
      end,
      -- Set to false to disable vim.ui.select hijacking
      use_default_opts = true,
      -- Max height of the quickfix window (number of lines)
      max_height = 10,
    },
    keys = {
      {
        "<leader>qq",
        function()
          require("quicker").toggle()
        end,
        desc = "Toggle quickfix",
      },
      {
        "<leader>ql",
        function()
          require("quicker").toggle({ loclist = true })
        end,
        desc = "Toggle loclist",
      },
      {
        "[q",
        function()
          vim.cmd("cprev")
        end,
        desc = "Previous quickfix item",
      },
      {
        "]q",
        function()
          vim.cmd("cnext")
        end,
        desc = "Next quickfix item",
      },
      {
        "[l",
        function()
          vim.cmd("lprev")
        end,
        desc = "Previous loclist item",
      },
      {
        "]l",
        function()
          vim.cmd("lnext")
        end,
        desc = "Next loclist item",
      },
    },
  },

  -- Optional: Enhanced quickfix preview (works well with quicker.nvim)
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "junegunn/fzf",
    },
    opts = {
      auto_enable = true,
      auto_resize_height = true, -- Automatically resize quickfix window height
      preview = {
        win_height = 15,          -- Height of preview window
        win_vheight = 15,         -- Height of preview window when vertical split
        delay_syntax = 80,        -- Delay for syntax highlighting in preview
        border = "rounded",       -- Border style
        show_title = true,        -- Show preview title
        should_preview_cb = nil,  -- Callback to determine if preview should be shown
      },
      filter = {
        fzf = {
          action_for = { ["ctrl-s"] = "split", ["ctrl-t"] = "tab drop" },
          extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
        },
      },
    },
  },
}