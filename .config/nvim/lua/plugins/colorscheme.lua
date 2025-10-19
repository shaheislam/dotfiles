-- Override LazyVim's catppuccin configuration
return {
  -- Override catppuccin to disable bufferline integration
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      integrations = {
        bufferline = false, -- Explicitly disable bufferline integration
      },
    },
  },
}
