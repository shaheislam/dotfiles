-- Pulse - Self-hosted coding activity tracking
-- https://github.com/viccon/pulse
--
-- Setup:
--   - Redis server running (brew services start redis)
--   - Pulse server running (via launchd daemon)
--   - Binaries installed: ~/bin/pulse-server, ~/bin/pulse-client
--   - Config file: ~/.pulse/config.yaml
--
-- View Stats:
--   - Check logs: tail -f ~/.pulse/logs/stdout.log
--   - Query Redis: redis-cli KEYS "*"
--   - Server status: launchctl list | grep pulse
--
-- Architecture:
--   - Neovim plugin sends events to RPC server
--   - Server logs to local KV store
--   - Background job aggregates to Redis
--   - Build custom dashboard to visualize

return {
  {
    "viccon/pulse",
    lazy = false, -- Load immediately to ensure tracking starts
    config = function()
      -- Plugin auto-connects to localhost:1122 (default from Pulse server)
      -- No additional configuration needed
    end,
  },
}
