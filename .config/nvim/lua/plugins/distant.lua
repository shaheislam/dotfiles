return {
  {
    "chipsenkbeil/distant.nvim",
    branch = "v0.3",
    config = function()
      require("distant"):setup({
        -- Server settings
        servers = {
          -- Example server configuration
          -- Uncomment and modify this to add your servers
          -- ["myserver"] = {
          --   connect = {
          --     default = {
          --       scheme = "ssh",
          --       host = "example.com",
          --       port = 22,
          --       username = "yourusername",
          --     },
          --   },
          -- },
        },

        -- Default settings for all servers
        ["*"] = {
          -- Authentication options
          connect = {
            default = {
              scheme = "ssh",
              options = {
                -- SSH backend to use (ssh2, libssh, exec)
                backend = "ssh2",
              },
            },
          },

          -- File browser settings
          file = {
            -- Automatically wrap nvim-tree, neo-tree, etc
            mappings = {
              ["-"] = ":DistantOpen",
            },
          },

          -- Launch settings
          launch = {
            -- Automatically launch distant server on connection
            autostart = true,

            -- Options for the distant server
            options = {
              -- Logging level
              log_level = "info",

              -- Where to store logs
              log_file = vim.fn.stdpath("cache") .. "/distant.log",
            },
          },
        },
      })
    end,

    -- Commands
    cmd = {
      "DistantInstall",
      "DistantConnect",
      "DistantLaunch",
      "DistantOpen",
      "DistantShell",
      "DistantCopy",
      "DistantRename",
      "DistantRemove",
      "DistantMkdir",
      "DistantSearch",
      "DistantSessionInfo",
      "DistantSystemInfo",
      "DistantClientVersion",
    },

    -- Key mappings
    keys = {
      { "<leader>dc", "<cmd>DistantConnect<cr>", desc = "Connect to remote server" },
      { "<leader>do", "<cmd>DistantOpen<cr>", desc = "Open remote file/directory" },
      { "<leader>ds", "<cmd>DistantShell<cr>", desc = "Open remote shell" },
      { "<leader>dS", "<cmd>DistantSearch<cr>", desc = "Search remote files" },
      { "<leader>di", "<cmd>DistantSessionInfo<cr>", desc = "Show session info" },
      { "<leader>dI", "<cmd>DistantSystemInfo<cr>", desc = "Show system info" },
    },
  },
}