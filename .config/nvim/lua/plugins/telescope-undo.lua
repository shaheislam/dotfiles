-- Telescope undo tree integration
-- View and search through your undo history using Telescope
-- Usage: <leader>fu to open undo history
-- Mappings:
-- - <cr> restore the selected undo state (simplified to just Enter)
-- - y yank additions to clipboard
-- - Y yank deletions to clipboard

return {
  {
    "debugloop/telescope-undo.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
      },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope-undo.actions")

      -- Merge our undo extension config with existing telescope setup
      telescope.setup({
        extensions = {
          undo = {
            use_delta = true,
            side_by_side = false,
            layout_strategy = "vertical",
            layout_config = {
              preview_height = 0.8,
            },
            mappings = {
              i = {
                ["<cr>"] = actions.restore,
                ["<C-y>"] = actions.yank_additions,
                ["<C-Y>"] = actions.yank_deletions,
              },
              n = {
                ["<cr>"] = actions.restore,
                ["y"] = actions.yank_additions,
                ["Y"] = actions.yank_deletions,
              },
            },
          },
        },
      })

      -- Load the undo extension
      telescope.load_extension("undo")
    end,
    keys = {
      {
        "<leader>fu",
        "<cmd>Telescope undo<cr>",
        desc = "Undo History",
      },
    },
  },
}
