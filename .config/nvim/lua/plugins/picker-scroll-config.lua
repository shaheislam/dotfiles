-- Unified scroll configuration for Telescope and Snacks pickers
-- Adds Ctrl+u and Ctrl+d for preview scrolling across all pickers with smooth scrolling

return {
  -- Telescope configuration with preview scrolling
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-live-grep-args.nvim",
    },
    opts = {
      defaults = {
        -- Enable smooth scrolling
        scroll_strategy = "limit", -- or "cycle" if you prefer wrapping
        layout_config = {
          scroll_speed = 3, -- Number of lines to scroll (lower = smoother)
        },
        mappings = {
          -- Insert mode mappings
          i = {
            ["<C-u>"] = require("telescope.actions").preview_scrolling_up,
            ["<C-d>"] = require("telescope.actions").preview_scrolling_down,
            -- Keep other useful mappings
            ["<C-h>"] = require("telescope.actions").preview_scrolling_left,
            ["<C-l>"] = require("telescope.actions").preview_scrolling_right,
            -- Add half-page scrolling for smoother experience
            ["<C-b>"] = require("telescope.actions").preview_scrolling_up,
            ["<C-f>"] = require("telescope.actions").preview_scrolling_down,
            -- Fuzzy refine: switch to fuzzy filtering on current results
            ["<C-Space>"] = require("telescope.actions").to_fuzzy_refine,
            -- Prompt history navigation (Vim-style)
            ["<C-p>"] = require("telescope.actions").cycle_history_prev,
            ["<C-n>"] = require("telescope.actions").cycle_history_next,
          },
          -- Normal mode mappings
          n = {
            ["<C-u>"] = require("telescope.actions").preview_scrolling_up,
            ["<C-d>"] = require("telescope.actions").preview_scrolling_down,
            ["<C-h>"] = require("telescope.actions").preview_scrolling_left,
            ["<C-l>"] = require("telescope.actions").preview_scrolling_right,
            ["<C-b>"] = require("telescope.actions").preview_scrolling_up,
            ["<C-f>"] = require("telescope.actions").preview_scrolling_down,
            -- Fuzzy refine: switch to fuzzy filtering on current results
            ["<C-Space>"] = require("telescope.actions").to_fuzzy_refine,
          },
        },
      },
    },
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)

      -- Load live-grep-args extension if available
      pcall(telescope.load_extension, "live_grep_args")
    end,
  },

  -- Snacks configuration with preview scrolling
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        -- Configure scrolling behavior
        scroll = {
          -- Enable smooth scrolling animation
          enable = true,
          -- Number of lines to scroll at once (lower = smoother)
          speed = 3,
          -- Animation duration in milliseconds
          duration = 100,
        },
        -- Default win configuration for ALL Snacks pickers
        win = {
          input = {
            keys = {
              -- Preview scrolling (use built-in actions)
              ["<C-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["<C-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
              -- Half-page scrolling
              ["<C-b>"] = { "preview_page_up", mode = { "i", "n" } },
              ["<C-f>"] = { "preview_page_down", mode = { "i", "n" } },
              -- Horizontal scrolling
              ["<C-h>"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["<C-l>"] = { "preview_scroll_right", mode = { "i", "n" } },
              -- Toggle live mode: switch between live search and fuzzy filtering
              -- Default is <C-g>, also adding <C-Space> for consistency with Telescope
              ["<C-Space>"] = { "toggle_live", mode = { "i", "n" } },
            },
          },
        },
      },
      -- Global scroll configuration for all Snacks features
      scroll = {
        animate = {
          duration = { step = 10, total = 100 },
          easing = "linear",
        },
      },
    },
  },

  -- Optional: Add mini.animate for even smoother scrolling animations
  {
    "nvim-mini/mini.animate",
    event = "VeryLazy",
    opts = function()
      return {
        cursor = { enable = false }, -- Disable cursor animation
        scroll = { enable = false }, -- Disable scroll animation to fix lag
        resize = { enable = false }, -- Disable window resize animation
        open = { enable = false },   -- Disable window open animation
        close = { enable = false },  -- Disable window close animation
      }
    end,
  },
}