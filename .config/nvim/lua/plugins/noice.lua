-- Noice.nvim configuration to ensure text fits in message window
return {
  "folke/noice.nvim",
  keys = {
    -- Add keymaps to dismiss messages
    { "<Esc>", "<cmd>Noice dismiss<cr>", desc = "Dismiss all messages" },
    { "<leader>nd", "<cmd>Noice dismiss<cr>", desc = "Dismiss Noice messages" },
  },
  opts = {
    -- Cmdline configuration
    cmdline = {
      enabled = true,
      view = "cmdline_popup", -- Use popup for cmdline
    },
    -- Views configuration - focus on proper text display
    views = {
      cmdline_popup = {
        position = {
          row = "50%", -- Center vertically
          col = "50%", -- Center horizontally
        },
        size = {
          width = "auto",
          height = "auto",
          min_width = 40, -- Minimum width
          max_width = 90, -- Maximum width to prevent overflow
        },
        win_options = {
          wrap = true, -- Enable text wrapping
          linebreak = true, -- Break at word boundaries
        },
      },
      messages = {
        view = "mini",
      },
      mini = {
        win_options = {
          wrap = true, -- Enable text wrapping
          linebreak = true, -- Break at word boundaries
          winblend = 0, -- No transparency
        },
        size = {
          width = "auto", -- Automatic width based on content
          height = "auto", -- Automatic height based on content
          max_width = math.floor(vim.o.columns * 0.9), -- Use 90% of screen width max
          max_height = 10, -- Limit height to prevent taking too much space
        },
        position = {
          row = 1, -- Position at top of screen
          col = "50%", -- Centered horizontally
        },
        align = "center", -- Center align the text within the window
      },
      notify = {
        win_options = {
          wrap = true,
          linebreak = true,
        },
        size = {
          max_width = math.floor(vim.o.columns * 0.75),
          max_height = math.floor(vim.o.lines * 0.5),
        },
      },
      popup = {
        backend = "popup",
        relative = "editor",
        focusable = false,
        enter = false,
        border = {
          style = "rounded",
          padding = { 0, 1 },
        },
        position = {
          row = "30%",
          col = "50%",
        },
        size = {
          width = "80%",
          height = "auto",
        },
        win_options = {
          wrap = true,
          linebreak = true,
          winblend = 0,
        },
      },
    },
    -- LSP configuration
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
      hover = {
        enabled = true,
        view = nil, -- Use default
        opts = {}, -- Use default
      },
      signature = {
        enabled = true,
        auto_open = {
          enabled = true,
          trigger = true,
          luasnip = true,
          throttle = 50,
        },
      },
      message = {
        enabled = true,
        view = "mini", -- Use mini view for LSP messages
      },
    },
    -- Notification configuration
    notify = {
      enabled = true,
      view = "notify", -- Use notify view for better popup notifications
    },
    -- Presets
    presets = {
      bottom_search = false, -- Use default search position
      command_palette = true, -- Position cmdline and popupmenu together
      long_message_to_split = true, -- Long messages will be sent to a split
      inc_rename = false, -- Disable inc-rename preset
      lsp_doc_border = true, -- Add border to hover docs and signature help
    },
    -- Routes to handle specific message types
    routes = {
      -- Route git/fugitive messages to popup for better visibility
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "^Your branch" },
            { find = "^On branch" },
            { find = "^nothing to commit" },
            { find = "^Untracked files" },
            { find = "^Changes" },
            { find = "^modified:" },
            { find = "^deleted:" },
            { find = "^new file:" },
            { find = "git add" },
          },
        },
        view = "popup",
        opts = {
          position = {
            row = "30%",
            col = "50%",
          },
          size = {
            width = "80%",
            height = "auto",
          },
          win_options = {
            wrap = true,
            linebreak = true,
          },
          timeout = 3000, -- Auto-dismiss after 3 seconds (3000ms)
        },
      },
      -- Route long messages to split view
      {
        filter = {
          event = "msg_show",
          min_height = 10, -- Messages with 10+ lines
        },
        view = "split",
      },
      -- Keep short messages in mini view
      {
        filter = {
          event = "msg_show",
          max_height = 5, -- Messages with 5 or fewer lines
        },
        view = "mini",
      },
    },
  },
}