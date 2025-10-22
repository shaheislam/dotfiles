-- Blink.cmp - Custom configuration to extend LazyVim's blink.cmp extra
-- Note: LazyVim's coding.blink extra handles base setup and nvim-cmp disabling
return {
  {
    "saghen/blink.cmp",
    opts = {
      -- Custom Tab key mapping to accept completions (preserving workflow)
      keymap = {
        preset = "default", -- C-y to accept, C-n/C-p for navigation
        ["<Tab>"] = { "select_and_accept", "fallback" },
      },
    },
  },
}
