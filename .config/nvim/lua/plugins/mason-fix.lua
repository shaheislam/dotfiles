-- Fix Mason.nvim configuration
return {
  -- Override Mason configuration to fix the async error
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗"
        }
      },
      -- Don't use ensure_installed here, use mason-lspconfig for that
    },
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },

  -- Configure mason-lspconfig properly
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          -- LSP Servers with correct mason-lspconfig names
          "terraformls",        -- Terraform
          "ansiblels",          -- Ansible
          "helm_ls",            -- Helm
          "docker_compose_language_service", -- Docker Compose
          "dockerls",           -- Dockerfile
          "yamlls",             -- YAML
          "jsonls",             -- JSON
          "taplo",              -- TOML
          "bashls",             -- Bash
          "powershell_es",      -- PowerShell
          "pyright",            -- Python
          "gopls",              -- Go
          "rust_analyzer",      -- Rust
          "lua_ls",             -- Lua
          "marksman",           -- Markdown
        },
        automatic_installation = true,
      })
    end,
  },
}