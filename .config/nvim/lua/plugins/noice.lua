-- Noice.nvim configuration to ensure text fits in message window
return {
  "folke/noice.nvim",
  keys = {
    -- Add keymaps to dismiss messages
    { "<Esc>", "<cmd>Noice dismiss<cr>", desc = "Dismiss all messages" },
    { "<leader>nd", "<cmd>Noice dismiss<cr>", desc = "Dismiss Noice messages" },
    -- Toggle message history buffer
    { "<leader>nh", "<cmd>Noice history<cr>", desc = "Show Noice history" },
    { "<leader>nl", "<cmd>Noice last<cr>", desc = "Show last message" },
    { "<leader>ne", "<cmd>Noice errors<cr>", desc = "Show error messages" },
    { "<leader>nt", "<cmd>Noice telescope<cr>", desc = "Show messages in Telescope" },
  },
  config = function(_, opts)
    -- Add a hook to the split view to scroll to bottom on open
    local original_split = opts.views.split or {}
    opts.views.split = vim.tbl_deep_extend("force", original_split, {
      enter = true,
      -- Override the update function to scroll to bottom on open
      opts = {
        on_open = function(win)
          vim.api.nvim_win_set_option(win, "wrap", true)
          vim.api.nvim_win_set_option(win, "linebreak", true)
          -- Scroll to bottom on initial open
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(win) then
              local buf = vim.api.nvim_win_get_buf(win)
              local line_count = vim.api.nvim_buf_line_count(buf)
              vim.api.nvim_win_set_cursor(win, { line_count, 0 })
              vim.cmd("normal! zb")
            end
          end, 1)
        end,
      },
    })
    
    require("noice").setup(opts)
    
    -- Track manual scrolling to avoid interfering
    local noice_manually_scrolled = {}
    
    -- Function to scroll to bottom only if not manually scrolled
    local function scroll_to_bottom(force)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.api.nvim_buf_get_option(buf, "filetype")
        local bufname = vim.api.nvim_buf_get_name(buf)
        if ft == "noice" or ft == "NoiceHistory" or ft == "NoiceSplit" or 
           bufname:match("Noice") or bufname:match("noice") then
          
          -- Skip if manually scrolled (unless forced)
          if not force and noice_manually_scrolled[win] then
            -- Check if we're already at the bottom
            local cursor = vim.api.nvim_win_get_cursor(win)
            local line_count = vim.api.nvim_buf_line_count(buf)
            if cursor[1] >= line_count - 1 then
              -- We're near the bottom, clear the manual scroll flag
              noice_manually_scrolled[win] = nil
            else
              -- Still manually scrolled, don't auto-scroll
              return
            end
          end
          
          local line_count = vim.api.nvim_buf_line_count(buf)
          -- Save current window to restore later
          local current_win = vim.api.nvim_get_current_win()
          -- Move to last line
          vim.api.nvim_win_set_cursor(win, { line_count, 0 })
          -- Only switch windows if needed for scrolling
          if current_win == win then
            vim.cmd("normal! Gzb")
          end
        end
      end
    end
    
    -- Detect manual scrolling
    vim.api.nvim_create_autocmd({ "WinScrolled" }, {
      callback = function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.api.nvim_buf_get_option(buf, "filetype")
        if ft == "noice" or ft == "NoiceHistory" or ft == "NoiceSplit" then
          local cursor = vim.api.nvim_win_get_cursor(win)
          local line_count = vim.api.nvim_buf_line_count(buf)
          -- If we're not at the bottom, mark as manually scrolled
          if cursor[1] < line_count - 2 then
            noice_manually_scrolled[win] = true
          else
            noice_manually_scrolled[win] = nil
          end
        end
      end,
    })
    
    -- Initial scroll to bottom when opening
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      pattern = { "noice", "NoiceHistory", "NoiceSplit" },
      callback = function()
        vim.defer_fn(function() scroll_to_bottom(true) end, 1)
      end,
    })
    
    -- Scroll to bottom only when new messages are added
    vim.api.nvim_create_autocmd("User", {
      pattern = { "NoiceMessageAdded" },
      callback = function()
        vim.defer_fn(function() scroll_to_bottom(false) end, 1)
      end,
    })
    
    -- Reset manual scroll flag when window is closed
    vim.api.nvim_create_autocmd({ "WinClosed" }, {
      callback = function()
        local win = tonumber(vim.fn.expand("<afile>"))
        if win then
          noice_manually_scrolled[win] = nil
        end
      end,
    })
  end,
  opts = {
    -- Cmdline configuration
    cmdline = {
      enabled = true,
      view = "cmdline", -- Use traditional bottom cmdline (like /)
    },
    -- Views configuration - use split buffer for messages
    views = {
      cmdline_popup = {
        position = {
          row = "90%", -- Position near bottom of screen
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
        view = "split",  -- Use split buffer instead of floating window
      },
      split = {
        backend = "split",
        relative = "editor",
        position = "bottom",
        size = "20%",
        close = {
          keys = { "q", "<Esc>" },
        },
        win_options = {
          wrap = true,
          linebreak = true,
          winhighlight = "Normal:Normal,FloatBorder:Normal",
          scrolloff = 0,  -- Allow cursor at very bottom
          cursorline = false,  -- Don't highlight cursor line
        },
        -- Keep cursor at the last line
        enter = true,
        -- Force scroll to bottom on open
        focus = true,
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
          row = -1, -- Position at very bottom of screen
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
    -- Message configuration
    messages = {
      enabled = true,
      view = "split",  -- Use split buffer for regular messages
      view_error = "split",  -- Use split buffer for errors
      view_warn = "split",  -- Use split buffer for warnings
      view_history = "split",  -- Use split buffer for history
      view_search = "virtualtext",
    },
    -- Presets
    presets = {
      bottom_search = true, -- Use bottom search position
      command_palette = true, -- Position cmdline and popupmenu together
      long_message_to_split = true, -- Long messages will be sent to a split
      inc_rename = false, -- Disable inc-rename preset
      lsp_doc_border = true, -- Add border to hover docs and signature help
    },
    -- Routes to handle specific message types
    routes = {
      -- Route all messages to split buffer by default
      {
        filter = {
          event = "msg_show",
        },
        view = "split",
      },
      -- Route git messages to split buffer
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
        view = "split",
      },
      -- Route LSP progress to mini (less intrusive)
      {
        filter = {
          event = "lsp",
          kind = "progress",
        },
        view = "mini",
      },
      -- Hide some common messages you might not need
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "^%d+L, %d+B" },  -- File write messages
            { find = "; after #%d+" },  -- Undo messages
            { find = "; before #%d+" }, -- Redo messages
          },
        },
        opts = { skip = true },
      },
    },
  },
}