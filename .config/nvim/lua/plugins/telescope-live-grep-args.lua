-- Telescope live grep with arguments
-- Enables advanced ripgrep searches with custom arguments
-- Usage: <leader>fg to start live grep with args
-- - Type search query, then add args like --type py or --glob *.lua
-- - <C-k> to quote the prompt for exact phrase matching
-- - <C-g> to insert glob pattern (case-sensitive)
-- - <C-i> to insert iglob pattern (case-insensitive)
-- - <C-t> to add --type filter
-- - <C-h> to add --hidden flag
-- - <C-space> to convert to fuzzy refine (filter results)
-- Shortcuts:
-- - <leader>fw to grep word under cursor (project-wide)
-- - <leader>fW to grep word under cursor (current buffer)
-- - <leader>fv (visual) to grep selection (project-wide)
-- - <leader>fV (visual) to grep selection (current buffer)

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
                ["<C-t>"] = lga_actions.quote_prompt({ postfix = " --type " }),
                ["<C-h>"] = lga_actions.quote_prompt({ postfix = " --hidden " }),
              },
              n = {
                ["<C-k>"] = lga_actions.quote_prompt(),
                ["<C-g>"] = lga_actions.quote_prompt({ postfix = " --glob " }),
                ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
                ["<C-t>"] = lga_actions.quote_prompt({ postfix = " --type " }),
                ["<C-h>"] = lga_actions.quote_prompt({ postfix = " --hidden " }),
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
      {
        "<leader>fw",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_under_cursor()
        end,
        desc = "Grep word under cursor",
      },
      {
        "<leader>fW",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_under_cursor_current_buffer()
        end,
        desc = "Grep word under cursor (current buffer)",
      },
      {
        "<leader>fv",
        function()
          require("telescope-live-grep-args.shortcuts").grep_visual_selection()
        end,
        mode = "v",
        desc = "Grep visual selection",
      },
      {
        "<leader>fV",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_visual_selection_current_buffer()
        end,
        mode = "v",
        desc = "Grep visual selection (current buffer)",
      },
    },
  },
}
