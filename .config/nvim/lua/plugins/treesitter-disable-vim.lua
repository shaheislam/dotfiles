-- Disable treesitter for vim files to avoid query errors
-- The vim parser has issues with the "substitute" node type
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = {
        enable = true,
        -- Disable highlighting for vim files due to query errors
        disable = { "vim" },
      },
    },
  },
}