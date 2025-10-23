-- Cleanup redundant plugins and ensure proper alternatives are loaded
return {
  -- Disable redundant plugins
  { "nvim-mini/mini.files", enabled = false },
  -- vim-yoink and vim-cutlass are enabled in custom.lua - don't disable here
  -- { "svermeulen/vim-yoink", enabled = false },
  -- { "svermeulen/vim-cutlass", enabled = false },
  { "nathanaelkane/vim-indent-guides", enabled = false },
  { "tpope/vim-surround", enabled = false },

  -- Ensure these alternatives are loaded (LazyVim provides most of them)
  -- ts-comments.nvim is included by default in LazyVim
  -- persistence.nvim is included by default in LazyVim

  -- indent-blankline is already in missing-essentials.lua but let's ensure it's configured properly
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = {
        enabled = true,
        show_start = false,
        show_end = false,
      },
      exclude = {
        filetypes = {
          "help",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      },
    },
  },
}