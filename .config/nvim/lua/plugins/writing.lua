-- Writing-focused plugins integrated from OVIWrite
-- https://miragiancycle.github.io/OVIWrite/

return {
  -- LaTeX editing support
  {
    "lervag/vimtex",
    ft = { "tex", "latex" },
    config = function()
      -- VimTeX configuration
      vim.g.vimtex_view_method = "skim" -- Use Skim for PDF preview on macOS
      vim.g.vimtex_compiler_method = "latexmk"

      -- Enable completion with nvim-cmp (LazyVim already has this)
      vim.g.vimtex_quickfix_mode = 0

      -- Disable overfull/underfull \hbox warnings
      vim.g.vimtex_quickfix_ignore_filters = {
        "Underfull",
        "Overfull",
      }
    end,
  },

  -- Automatic Pandoc integration for Markdown
  {
    "jghauser/auto-pandoc.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = "markdown",
    opts = {},
  },

  -- Better Markdown and Org-mode header highlighting
  {
    "lukas-reineke/headlines.nvim",
    ft = { "markdown", "org" },
    dependencies = "nvim-treesitter/nvim-treesitter",
    opts = {
      markdown = {
        headline_highlights = {
          "Headline1",
          "Headline2",
          "Headline3",
          "Headline4",
          "Headline5",
          "Headline6",
        },
        fat_headlines = true,
        fat_headline_upper_string = "▃",
        fat_headline_lower_string = "🬂",
      },
    },
  },

  -- Typewriter mode - keep cursor centered while writing
  {
    "arnamak/stay-centered.nvim",
    opts = {
      -- Only enable in certain filetypes (writing-focused)
      enabled = true,
      allow_scroll_move = true,
    },
    -- Optional: Only load for writing filetypes
    -- ft = { "markdown", "text", "org", "tex" },
  },

  -- Writing session tracking and statistics
  {
    "ptdewey/pendulum-nvim",
    config = function()
      require("pendulum").setup({
        -- Log file location (default: ~/pendulum-log.csv)
        log_file = vim.fn.expand("$HOME/pendulum-log.csv"),

        -- Timeout for inactivity (seconds) - default: 180
        timeout_len = 180,

        -- Activity check interval (seconds) - default: 120
        timer_len = 120,

        -- Enable report generation (requires Go installed)
        gen_reports = true,

        -- Number of top entries in report
        top_n = 5,

        -- Time format: "12h" or "24h"
        time_format = "12h",
      })
    end,
  },

  -- Smooth scrolling (aesthetic enhancement)
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    opts = {
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
      hide_cursor = true,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
    },
  },

  -- Note: Org-mode support is available via LazyVim extra
  -- Enable with: { import = "lazyvim.plugins.extras.lang.org" }
}
