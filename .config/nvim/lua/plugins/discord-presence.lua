-- ~/.config/nvim/lua/plugins/discord-presence.lua
-- Discord Rich Presence integration for Neovim
--
-- Requirements:
--   1. Discord Desktop app must be running (not browser version)
--   2. Discord Settings → Activity Privacy → Enable "Display current activity as a status message"
--   3. No additional Discord configuration or API keys needed
--
-- Features:
--   - Shows "Playing Neovim" in Discord
--   - Displays current file and editing time (workspace/repo name hidden)
--   - Updates in real-time across multiple Neovim instances
--   - Pure Lua implementation with no external dependencies

return {
  {
    "andweeb/presence.nvim",
    lazy = false, -- Load immediately to ensure Discord connection
    priority = 1000, -- Load early
    config = function()
      require("presence").setup({
        -- General options
        auto_update = true, -- Update activity based on autocmd events
        neovim_image_text = "Neovim", -- Text displayed when hovering over the Neovim image
        main_image = "neovim", -- Main image display (neovim, file, or custom)

        -- Display customization
        show_time = true, -- Show elapsed time
        editing_text = "Editing code", -- Generic text (hides filename and path)
        file_explorer_text = "Browsing files", -- Generic text (no directory name)
        git_commit_text = "Committing changes", -- Text displayed during git commits
        plugin_manager_text = "Managing plugins", -- Text displayed during plugin management
        reading_text = "Reading code", -- Generic text (hides filename)
        workspace_text = "Coding", -- Generic text (hides project/repo name)
        line_number_text = "Line %s out of %s", -- Format string for line number display

        -- Client configuration
        client_id = "793271441293967371", -- Default Discord Application ID

        -- Logging (enabled for troubleshooting)
        log_level = "debug", -- See :messages for debug output
        debounce_timeout = 10, -- Seconds to debounce events (avoid spamming Discord API)
      })
    end,
    keys = {
      -- Manual update keybinding for troubleshooting
      { "<leader>dp", "<cmd>lua require('presence'):update()<cr>", desc = "Update Discord Presence" },
    },
  },
}
