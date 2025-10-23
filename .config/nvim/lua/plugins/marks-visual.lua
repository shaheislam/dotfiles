-- ~/.config/nvim/lua/plugins/marks-visual.lua
-- Enhanced marks with visual indicators
-- Extracted from misc.lua for better organization

return {
  -- marks.nvim - Enhanced marks with visual indicators
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      -- Enable default mappings (m{char} to set, dm{char} to delete)
      default_mappings = true,
      -- Enable signs in the sign column
      signs = true,
      -- Built-in mappings
      mappings = {
        set_next = "m,",           -- Set next available lowercase mark
        toggle = false,            -- Disable toggle to avoid conflicts
        next = "m]",              -- Move to next mark
        prev = "m[",              -- Move to previous mark
        preview = "m:",           -- Preview marks in floating window
        delete = "dm",            -- Delete mark (dm{char})
        delete_line = false,      -- Disable line deletion
        delete_buf = "dm<space>", -- Delete all marks in buffer
        next_bookmark = "m}",     -- Next bookmark
        prev_bookmark = "m{",     -- Previous bookmark
        delete_bookmark = "dm=",  -- Delete bookmark at cursor
      },
      -- Which builtin marks to show (. = last change, ^ = last insert)
      builtin_marks = { ".", "<", ">", "^" },
      -- Whether to remember marks between sessions
      cyclic = true,
      -- Force display marks in these filetypes
      force_write_shada = false,
      -- Refresh marks when these events occur
      refresh_interval = 250,
      -- Sign priorities
      sign_priority = { lower=10, upper=15, builtin=8, bookmark=20 },
      -- Bookmark groups (0-9) with custom signs
      bookmark_0 = {
        sign = "⚑",
        virt_text = "mark",
      },
      -- Exclude these filetypes
      excluded_filetypes = {
        "neo-tree",
        "TelescopePrompt",
        "lazy",
        "mason",
        "dashboard",
        "alpha",
        "terminal",
        "toggleterm",
      },
      -- Exclude these buffer types
      excluded_buftypes = {
        "terminal",
        "nofile",
        "quickfix",
      },
    },
  },
}
