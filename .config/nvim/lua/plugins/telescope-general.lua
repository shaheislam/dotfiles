-- ~/.config/nvim/lua/plugins/telescope-general.lua
-- General Telescope configuration and keymaps
-- Extracted from misc.lua for better organization

return {
  -- Telescope configuration
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- Override LazyVim defaults with your custom versions
      { "<leader>ff", function()
        require("telescope.builtin").find_files({
          hidden = true,
          no_ignore = false,
          follow = true,
        })
      end, desc = "Find Files (Custom)" },

      -- <leader>fg mapping moved to telescope-live-grep-args.lua for better grep functionality

      -- Marks integration
      { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Find marks" },
    },
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        defaults = {
          default_text = "",  -- Prevent picking up vim's search register on first load
          file_ignore_patterns = {
            "node_modules", "^.git/", "dist", "/build/", "%.lock", "package%-lock%.json",
            "yarn%.lock", "%.log", "%.cache", "%.min%.js", "%.min%.css"
          },
          layout_config = {
            horizontal = { preview_width = 0.6 },
          },
        },
      })
    end,
  },
}
