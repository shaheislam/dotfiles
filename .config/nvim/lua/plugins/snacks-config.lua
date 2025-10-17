-- ~/.config/nvim/lua/plugins/snacks-config.lua
-- Snacks.nvim configuration overrides

return {
  "snacks.nvim",
  opts = {
    terminal = {
      -- Ensure terminals always auto-close when process exits (e.g., with <C-d>)
      auto_close = true,
      -- Keep other interactive behaviors enabled
      auto_insert = true,
      start_insert = true,
    },
  },
}
