-- Telescope undo tree integration
-- View and search through your undo history using Telescope
-- Usage: <leader>fu to open undo history
-- Mappings:
-- - <cr> restore the selected undo state
-- - y yank additions to clipboard
-- - Y yank deletions to clipboard

return {
  {
    "debugloop/telescope-undo.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      { "debugloop/telescope-undo.nvim" },
    },
    opts = function(_, opts)
      local actions = require("telescope-undo.actions")

      return vim.tbl_deep_extend("force", opts, {
        extensions = {
          undo = {
            use_delta = true,
            side_by_side = false,
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
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
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
