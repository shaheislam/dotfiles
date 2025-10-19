-- Override Snacks picker keybindings to use Telescope for scope toggle support
-- This enables <M-g> (Global), <M-s> (Service), <M-l> (Local) scope switching

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- Override fb to use Telescope instead of Snacks picker
      -- This enables dynamic scope switching with <M-g>, <M-s>, <M-l>
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers({
            prompt_title = "Buffers (Local)",
            sort_mru = true,
            sort_lastused = true,
            ignore_current_buffer = false,
            show_all_buffers = true,
          })
        end,
        desc = "Buffers (with scope toggle)",
      },

      -- Override fr to use Telescope instead of Snacks picker
      -- Starts with Local scope (respects Oil directory if in Oil)
      {
        "<leader>fr",
        function()
          -- Check if we're in an Oil buffer and use its directory
          local cwd = vim.fn.getcwd()
          if vim.bo.filetype == "oil" then
            local oil_dir = require("oil").get_current_dir()
            if oil_dir then
              cwd = oil_dir
            end
          end

          require("telescope.builtin").oldfiles({
            cwd = cwd,
            prompt_title = "Recent Files (Local)",
            only_cwd = false, -- Show all recent files, but start filtered to cwd
          })
        end,
        desc = "Recent Files (with scope toggle)",
      },

      -- Keep fB for all buffers including hidden/nofile
      {
        "<leader>fB",
        function()
          require("telescope.builtin").buffers({
            prompt_title = "All Buffers",
            sort_mru = true,
            sort_lastused = true,
            ignore_current_buffer = false,
            show_all_buffers = true,
            bufnr_width = 3,
          })
        end,
        desc = "All Buffers (inc. hidden)",
      },

      -- Add fR for global recent files (no cwd filtering)
      {
        "<leader>fR",
        function()
          require("telescope.builtin").oldfiles({
            prompt_title = "Recent Files (Global)",
            only_cwd = false,
          })
        end,
        desc = "Recent Files (Global)",
      },
    },
  },
}