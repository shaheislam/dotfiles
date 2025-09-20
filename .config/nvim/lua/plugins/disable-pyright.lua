-- Explicitly disable pyright to prevent conflicts with basedpyright
return {
  -- Disable pyright completely
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Explicitly disable pyright
        pyright = false,
      },
    },
  },

  -- Also ensure LazyVim's python extra doesn't enable pyright
  {
    "LazyVim/LazyVim",
    opts = {
      -- Disable any LazyVim python extras that might enable pyright
      lsp = {
        servers = {
          pyright = false,
        },
      },
    },
  },
}