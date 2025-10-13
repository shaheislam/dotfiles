-- Enhanced Marks and Quickfix List Management
-- marks.nvim: Visual bookmark indicators in the sign column
-- quicker.nvim: Better quickfix/location list management
-- nvim-pqf: Pretty quickfix formatting with better readability

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
        signcolumn = "auto",
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
        -- Keep quickfix at bottom with fixed height
        vim.cmd("wincmd J")
        vim.cmd("resize 10")

        -- Helper function to jump to quickfix item location
        local function jump_to_qf_item()
          local qf_idx = vim.fn.line('.')
          local qf_list = vim.fn.getqflist()
          local item = qf_list[qf_idx]

          if item and item.bufnr > 0 then
            -- Move to buffer window above
            vim.cmd("wincmd k")
            -- Jump to the exact location
            vim.cmd(qf_idx .. "cc")
            -- Center the line on screen
            vim.cmd("normal! zz")
            -- Return to quickfix window
            vim.cmd("wincmd j")
          end
        end

        -- Automatically show file in buffer above when navigating
        vim.api.nvim_create_autocmd("CursorMoved", {
          buffer = bufnr,
          callback = function()
            jump_to_qf_item()
          end,
        })

        -- Add custom keymaps for quickfix buffer
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Refresh quickfix list
        map("n", "r", function()
          require("quicker").refresh()
        end, "Refresh quickfix")

        -- Close quickfix
        map("n", "q", function()
          require("quicker").close()
        end, "Close quickfix")

        -- Open entry in buffer above (keep quickfix open)
        map("n", "<CR>", function()
          local qf_idx = vim.fn.line('.')
          vim.cmd("wincmd k")
          vim.cmd(qf_idx .. "cc")
          vim.cmd("normal! zz")
        end, "Open entry")

        -- Navigate to next item
        map("n", "j", function()
          vim.cmd("normal! j")
          jump_to_qf_item()
        end, "Next item")

        -- Navigate to previous item
        map("n", "k", function()
          vim.cmd("normal! k")
          jump_to_qf_item()
        end, "Previous item")
      end,
      -- Set to false to disable vim.ui.select hijacking
      use_default_opts = true,
      -- Max height of the quickfix window
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

  -- Pretty quickfix formatting for better readability
  {
    "yorickpeterse/nvim-pqf",
    ft = "qf",
    config = function()
      require("pqf").setup({
        signs = {
          error = "E",
          warning = "W",
          info = "I",
          hint = "H",
        },
        -- Maximum number of lines to show for each entry
        max_filename_length = 0, -- 0 = no limit
        -- Show the line number in the quickfix list
        show_line_numbers = true,
      })
    end,
  },

  -- Optional: Enhanced quickfix preview (works well with quicker.nvim and nvim-pqf)
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "junegunn/fzf",
    },
    opts = {
      auto_enable = true,
      auto_resize_height = false, -- Don't auto-resize
      preview = {
        auto_preview = false, -- Disable automatic preview
        border = "none",
        show_title = false,
        should_preview_cb = function() return false end, -- Never show preview
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