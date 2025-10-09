-- ~/.config/nvim/lua/plugins/terminal-maximize.lua
-- Terminal maximize toggle functionality

return {
  {
    "LazyVim/LazyVim",
    keys = {
      -- Add terminal maximize toggle with Ctrl+z in terminal mode
      {
        "<C-z>",
        function()
          local win = vim.api.nvim_get_current_win()
          local buf = vim.api.nvim_get_current_buf()

          -- Only work in terminal buffers
          if vim.bo[buf].buftype ~= "terminal" then
            return
          end

          -- Check if window is already maximized by checking if width/height are at max
          local win_width = vim.api.nvim_win_get_width(win)
          local win_height = vim.api.nvim_win_get_height(win)
          local max_width = vim.o.columns
          local max_height = vim.o.lines - vim.o.cmdheight - 2 -- Account for statusline

          -- Store original size if not already stored
          if not vim.w.terminal_original_size then
            vim.w.terminal_original_size = {
              width = win_width,
              height = win_height,
            }
          end

          -- Toggle between maximized and original size
          if win_width >= max_width - 2 and win_height >= max_height - 2 then
            -- Restore to original size
            if vim.w.terminal_original_size then
              vim.api.nvim_win_set_width(win, vim.w.terminal_original_size.width)
              vim.api.nvim_win_set_height(win, vim.w.terminal_original_size.height)
            end
          else
            -- Maximize window
            vim.api.nvim_win_set_width(win, max_width)
            vim.api.nvim_win_set_height(win, max_height)
          end
        end,
        desc = "Toggle Terminal Maximize",
        mode = "t", -- Terminal mode only
      },
    },
  },
}
