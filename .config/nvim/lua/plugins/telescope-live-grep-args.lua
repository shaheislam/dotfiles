-- Telescope live grep with arguments
-- Enables advanced ripgrep searches with custom arguments
-- Usage: <leader>fg to start live grep with args
-- - Type search query, then add args like --type py or --glob *.lua
-- - <C-k> to quote the prompt for exact phrase matching
-- - <C-g> to insert glob pattern (case-sensitive)
-- - <C-i> to insert iglob pattern (case-insensitive)

return {
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      local telescope = require("telescope")
      local lga_actions = require("telescope-live-grep-args.actions")

      telescope.setup({
        extensions = {
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            mappings = {
              i = {
                ["<C-k>"] = lga_actions.quote_prompt(),
                ["<C-g>"] = lga_actions.quote_prompt({ postfix = " --glob " }),
                ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
              },
              n = {
                ["<C-k>"] = lga_actions.quote_prompt(),
                ["<C-g>"] = lga_actions.quote_prompt({ postfix = " --glob " }),
                ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
              },
            },
            -- ... also accepts theme settings, for example:
            -- theme = "dropdown", -- use dropdown theme
            -- theme = { }, -- use own theme spec
            -- layout_config = { mirror=true }, -- mirror preview pane
          },
        },
      })

      -- Load the extension
      telescope.load_extension("live_grep_args")
    end,
    keys = {
      {
        "<leader>fg",
        function()
          require("telescope").extensions.live_grep_args.live_grep_args()
        end,
        desc = "Live Grep with Args",
      },
    },
  },
}
