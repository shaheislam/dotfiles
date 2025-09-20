-- Python virtual environment selector
return {
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    lazy = false, -- Load immediately to ensure proper initialization
    branch = "main",
    config = function()
      require("venv-selector").setup({
        -- Minimal configuration to avoid the pairs error
        search = {}, -- Empty table instead of nil to avoid pairs() error
        options = {
          enable_default_searches = true, -- Use the plugin's built-in searches
          enable_cached_venvs = true, -- Allow caching of discovered venvs
          cached_venv_automatic_activation = false, -- Don't auto-activate cached venvs
          notify_user_on_venv_activation = true, -- Show notification when switching
          -- Use telescope if available, fallback to native
          picker = "telescope",
        },
        -- Add hook to update LSP when venv changes
        hooks = {
          basedpyright = function(venv_path)
            -- Update basedpyright with new venv
            local clients = vim.lsp.get_active_clients({ name = "basedpyright" })
            for _, client in ipairs(clients) do
              if client.config.settings then
                client.config.settings.basedpyright = client.config.settings.basedpyright or {}
                client.config.settings.basedpyright.venvPath = venv_path and vim.fn.fnamemodify(venv_path, ":h") or nil
              end
              client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
            end
          end,
          ruff = function(venv_path)
            -- Update ruff with new venv
            local clients = vim.lsp.get_active_clients({ name = "ruff" })
            for _, client in ipairs(clients) do
              -- Ruff might need a restart to pick up the new environment
              vim.cmd("LspRestart ruff")
            end
          end,
        },
      })
    end,
    keys = {
      { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
      { "<leader>vc", "<cmd>VenvSelectCached<cr>", desc = "Select cached venv" },
    },
  },
}