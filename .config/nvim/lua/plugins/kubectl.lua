-- kubectl.nvim - Kubernetes management within Neovim
-- Full cluster management without leaving the editor

return {
  {
    "ramilito/kubectl.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "saghen/blink.download",
    },
    lazy = true,
    cmd = { "Kubectl", "KubectlToggle" },
    keys = {
      { "<leader>kk", "<cmd>lua require('kubectl').toggle()<cr>", desc = "Toggle kubectl view" },
      { "<leader>kp", "<cmd>KubectlPods<cr>", desc = "Kubectl pods view" },
      { "<leader>kd", "<cmd>KubectlDeployments<cr>", desc = "Kubectl deployments view" },
    },
    config = function()
      require("kubectl").setup({
        -- Logging configuration
        log_level = vim.log.levels.INFO,

        -- Auto-refresh configuration
        auto_refresh = {
          enabled = true,
          interval = 300, -- milliseconds
        },

        -- Default namespace (use "All" for all namespaces)
        namespace = "All",

        -- kubectl command configuration
        kubectl_cmd = {
          cmd = "kubectl",
          persist_context_change = false, -- Don't persist context changes between sessions
        },

        -- Terminal command for exec (optional)
        -- If not set, uses built-in terminal
        terminal_cmd = nil,

        -- Logs configuration
        logs = {
          prefix = true,      -- Show container prefix in logs
          timestamps = true,  -- Show timestamps
          since = "5m",      -- Default time range for logs
        },

        -- Custom keybindings (optional)
        -- Uncomment to override defaults
        -- mappings = {
        --   open = "<cr>",
        --   back = "<bs>",
        --   help = "g?",
        --   refresh = "gr",
        --   sort = "gs",
        --   delete = "gD",
        --   describe = "gd",
        --   edit = "ge",
        --   yaml = "gy",
        --   logs = "gl",
        --   follow = "f",
        -- },
      })

      -- Additional custom commands for convenience
      vim.api.nvim_create_user_command("Kubectl", function()
        require("kubectl").toggle()
      end, {})

      vim.api.nvim_create_user_command("KubectlToggle", function()
        require("kubectl").toggle()
      end, {})

      -- Quick access to different views
      vim.api.nvim_create_user_command("KubectlPods", function()
        require("kubectl").toggle()
        vim.defer_fn(function()
          vim.api.nvim_feedkeys("2", "n", false)
        end, 100)
      end, {})

      vim.api.nvim_create_user_command("KubectlDeployments", function()
        require("kubectl").toggle()
        vim.defer_fn(function()
          vim.api.nvim_feedkeys("1", "n", false)
        end, 100)
      end, {})

      -- Create which-key mappings if available
      local ok, wk = pcall(require, "which-key")
      if ok then
        wk.add({
          { "<leader>k", group = "kubectl" },
          { "<leader>kk", "<cmd>lua require('kubectl').toggle()<cr>", desc = "Toggle kubectl" },
          { "<leader>kp", "<cmd>KubectlPods<cr>", desc = "Pods view" },
          { "<leader>kd", "<cmd>KubectlDeployments<cr>", desc = "Deployments view" },
        })
      end
    end,
  },
}