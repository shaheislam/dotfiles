-- DevOps LSP Configuration
-- Complete LSP setup for DevOps engineering with LazyVim

return {
  -- Configure LazyVim to load DevOps-specific language extras
  {
    "LazyVim/LazyVim",
    opts = {
      -- Enable all DevOps-relevant language extras
      extras = {
        -- Infrastructure as Code
        "lazyvim.plugins.extras.lang.terraform",
        "lazyvim.plugins.extras.lang.ansible",
        "lazyvim.plugins.extras.lang.helm",
        
        -- Containers & Orchestration
        "lazyvim.plugins.extras.lang.docker",
        
        -- Configuration Languages
        "lazyvim.plugins.extras.lang.yaml",
        "lazyvim.plugins.extras.lang.json",
        "lazyvim.plugins.extras.lang.toml",
        
        -- Scripting Languages
        "lazyvim.plugins.extras.lang.python",
        "lazyvim.plugins.extras.lang.go",
        "lazyvim.plugins.extras.lang.rust",
        
        -- Database
        "lazyvim.plugins.extras.lang.sql",
        
        -- Documentation
        "lazyvim.plugins.extras.lang.markdown",
        
        -- Version Control
        "lazyvim.plugins.extras.lang.git",
      },
    },
  },

  -- Ensure Mason installs all necessary LSPs, formatters, and linters
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP Servers
        "terraform-ls",           -- Terraform
        "tflint",                  -- Terraform linter
        "ansible-language-server", -- Ansible
        "helm-ls",                 -- Helm charts
        "docker-compose-language-service", -- Docker Compose
        "dockerfile-language-server", -- Dockerfile
        "yaml-language-server",    -- YAML
        "json-lsp",                -- JSON
        "taplo",                   -- TOML
        "bash-language-server",    -- Bash/Shell
        "powershell-editor-services", -- PowerShell
        "pyright",                 -- Python
        "gopls",                   -- Go
        "rust-analyzer",           -- Rust
        "lua-language-server",     -- Lua
        "marksman",                -- Markdown
        
        -- Formatters
        "prettier",                -- YAML, JSON, Markdown
        "stylua",                  -- Lua
        "shfmt",                   -- Shell scripts
        "black",                   -- Python
        "isort",                   -- Python imports
        "gofumpt",                 -- Go
        "rustfmt",                 -- Rust
        
        -- Linters
        "shellcheck",              -- Shell scripts
        "hadolint",                -- Dockerfile
        "yamllint",                -- YAML
        "jsonlint",                -- JSON
        "markdownlint",            -- Markdown
        "golangci-lint",           -- Go
        "ruff",                    -- Python
      },
    },
  },

  -- Additional LSP configurations
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Terraform LSP with enhanced settings
        terraformls = {
          cmd = { "terraform-ls", "serve" },
          filetypes = { "terraform", "tf", "terraform-vars", "hcl" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(".terraform", ".git")(fname)
          end,
        },
        
        -- Ansible LSP configuration
        ansiblels = {
          cmd = { "ansible-language-server", "--stdio" },
          filetypes = { "yaml.ansible", "ansible" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("ansible.cfg", ".ansible-lint")(fname)
          end,
          single_file_support = true,
        },
        
        -- YAML LSP with schema support
        yamlls = {
          settings = {
            yaml = {
              schemas = {
                -- Kubernetes schemas
                ["https://raw.githubusercontent.com/instrumenta/kubernetes-json-schema/master/v1.18.0-standalone-strict/all.json"] = "k8s/**/*.yaml",
                -- GitHub Actions
                ["https://json.schemastore.org/github-workflow.json"] = ".github/workflows/*",
                -- Docker Compose
                ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.yml",
                -- Ansible
                ["https://raw.githubusercontent.com/ansible/ansible-lint/main/src/ansiblelint/schemas/ansible.json"] = "ansible/**/*.yml",
              },
              validate = true,
              completion = true,
              hover = true,
            },
          },
        },
        
        -- Docker LSP
        dockerls = {
          cmd = { "docker-langserver", "--stdio" },
          filetypes = { "dockerfile" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("Dockerfile", "docker-compose.yml")(fname)
          end,
        },
        
        -- Helm LSP
        helm_ls = {
          cmd = { "helm_ls", "serve" },
          filetypes = { "helm" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("Chart.yaml")(fname)
          end,
        },
        
      },
    },
  },

  -- Auto-detect filetypes for DevOps files
  -- Note: This is built into Neovim, not a plugin
  {
    "folke/lazy.nvim", -- Dummy plugin to hold the config
    priority = 1000,
    config = function()
      vim.filetype.add({
        extension = {
          tf = "terraform",
          tfvars = "terraform",
          hcl = "hcl",
          nomad = "hcl",
          consul = "hcl",
          vault = "hcl",
        },
        filename = {
          ["Dockerfile"] = "dockerfile",
          [".dockerignore"] = "dockerfile",
          ["docker-compose.yml"] = "yaml.docker-compose",
          ["docker-compose.yaml"] = "yaml.docker-compose",
          ["playbook.yml"] = "yaml.ansible",
          ["playbook.yaml"] = "yaml.ansible",
          ["inventory"] = "ini",
          ["Jenkinsfile"] = "groovy",
          ["Vagrantfile"] = "ruby",
        },
        pattern = {
          [".*%.ya?ml%.j2"] = "yaml.jinja",
          [".*ansible.*%.ya?ml"] = "yaml.ansible",
          [".*playbook.*%.ya?ml"] = "yaml.ansible",
          [".*k8s.*%.ya?ml"] = "yaml",
          [".*kubernetes.*%.ya?ml"] = "yaml",
          [".*%.tf"] = "terraform",
          [".*%.tfvars"] = "terraform",
        },
      })
    end,
  },

  -- Terraform-specific plugin for better HCL support
  {
    "hashivim/vim-terraform",
    ft = { "terraform", "hcl" },
    config = function()
      vim.g.terraform_align = 1
      vim.g.terraform_fmt_on_save = 1
    end,
  },

  -- Ansible-specific plugin
  {
    "pearofducks/ansible-vim",
    ft = { "yaml.ansible", "ansible" },
  },

  -- Better JSON schemas
  {
    "b0o/schemastore.nvim",
    lazy = true,
    version = false,
  },

}