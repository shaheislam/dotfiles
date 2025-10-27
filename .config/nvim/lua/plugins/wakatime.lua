-- ~/.config/nvim/lua/plugins/wakatime.lua
-- WakaTime automatic time tracking for Neovim
--
-- Setup Instructions:
--   1. Sign up for free account at https://wakatime.com
--   2. Get your API key from https://wakatime.com/settings/account
--   3. After Neovim restart, run :WakaTimeApiKey (or press <leader>wk)
--   4. Paste your API key and press Enter
--   5. Code for a few minutes to generate initial data
--   6. View stats with :WakaTimeToday or press <leader>wd
--
-- Troubleshooting:
--   - If <leader>wd shows nothing → API key not configured or no data yet
--   - Check API key is set: cat ~/.wakatime.cfg
--   - Enable debug mode: :WakaTimeDebugEnable then check :messages
--   - View dashboard: Press <leader>wD to open browser
--   - Verify plugin loaded: :Lazy and check vim-wakatime status
--
-- Features:
--   - Automatic time tracking per project, language, file, and editor
--   - Beautiful dashboards showing coding stats and trends
--   - Weekly email reports with coding insights
--   - Privacy controls for project visibility
--   - Cross-editor support (tracks all your editors)
--
-- Dashboard: https://wakatime.com/dashboard

return {
  {
    "wakatime/vim-wakatime",
    lazy = false, -- Load immediately to ensure tracking starts
    keys = {
      -- Configuration and setup
      { "<leader>wk", "<cmd>WakaTimeApiKey<cr>", desc = "WakaTime: Set API Key" },

      -- View stats (requires API key configured and some coding activity)
      {
        "<leader>wd",
        function()
          -- Try the vim command first
          vim.cmd("WakaTimeToday")

          -- If no output after 1 second, try CLI directly
          vim.defer_fn(function()
            local handle = io.popen("wakatime-cli --today 2>&1")
            if handle then
              local result = handle:read("*a")
              handle:close()
              if result and result ~= "" then
                -- Show result in a notification
                vim.notify(result, vim.log.levels.INFO, { title = "WakaTime Today" })
              else
                vim.notify("No data yet. Code for a few minutes and try again.", vim.log.levels.WARN)
              end
            end
          end, 1000)
        end,
        desc = "WakaTime: Today's Stats",
      },

      -- Open dashboard in browser
      {
        "<leader>wD",
        function()
          vim.fn.system("open https://wakatime.com/dashboard")
          vim.notify("Opening WakaTime dashboard in browser...", vim.log.levels.INFO)
        end,
        desc = "WakaTime: Open Dashboard",
      },

      -- Debugging (if stats not showing)
      { "<leader>w+", "<cmd>WakaTimeDebugEnable<cr>", desc = "WakaTime: Enable Debug" },
      { "<leader>w-", "<cmd>WakaTimeDebugDisable<cr>", desc = "WakaTime: Disable Debug" },
    },
  },
}
