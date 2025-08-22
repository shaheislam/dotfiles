-- Additional DevOps/SRE Tools and Enhancements
-- Complementary plugins for complete DevOps workflow

return {
  -- ============== DEBUGGING & TESTING ==============
  
  -- DAP (Debug Adapter Protocol) for debugging
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-telescope/telescope-dap.nvim",
    },
    config = function()
      require("dapui").setup()
      require("nvim-dap-virtual-text").setup()
    end,
  },

  -- Test runner integration
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
      "rouge8/neotest-rust",
      "vim-test/vim-test",
    },
  },

  -- ============== CLOUD PROVIDERS ==============
  
  -- AWS CloudFormation support
  {
    "kddnewton/vim-cloudformation",
    ft = { "cloudformation", "cfn", "yaml" },
  },

  -- Azure ARM templates
  {
    "fourjay/vim-azurearmtemplate",
    ft = { "json", "arm" },
  },

  -- GCP Config Connector
  {
    "hashivim/vim-consul",
    ft = { "hcl", "consul" },
  },

  -- Pulumi support
  {
    "pulumi/pulumi-lsp",
    ft = { "typescript", "javascript", "python", "go", "yaml" },
  },

  -- ============== CI/CD TOOLS ==============
  
  -- GitHub Actions
  {
    "yasuhiroki/github-actions-yaml.vim",
    ft = { "yaml", "yml" },
  },

  -- GitLab CI
  {
    "Tirke/vim-gitlab-ci",
    ft = { "yaml", "gitlab-ci" },
  },

  -- Jenkins
  {
    "martinda/Jenkinsfile-vim-syntax",
    ft = { "jenkinsfile", "groovy" },
  },

  -- ============== MONITORING & OBSERVABILITY ==============
  
  -- Prometheus & PromQL
  {
    "saibing/vim-prometheus",
    ft = { "prometheus", "promql" },
  },

  -- Grafana dashboard JSON
  {
    "grafana/vim-grafana",
    ft = { "json", "grafana" },
  },

  -- Log file highlighting
  {
    "MTDL9/vim-log-highlighting",
    ft = { "log" },
  },

  -- ============== NETWORKING & SECURITY ==============
  
  -- nginx configuration
  {
    "chr4/nginx.vim",
    ft = { "nginx" },
  },

  -- Apache configuration
  {
    "vim-scripts/apachestyle",
    ft = { "apache", "htaccess" },
  },

  -- iptables/netfilter
  {
    "vim-scripts/iptables",
    ft = { "iptables" },
  },

  -- OpenAPI/Swagger
  {
    "hsanson/vim-openapi",
    ft = { "yaml", "json", "openapi" },
  },

  -- ============== PRODUCTIVITY ENHANCEMENTS ==============
  
  -- REST client for API testing
  {
    "rest-nvim/rest.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("rest-nvim").setup({
        result_split_horizontal = false,
        skip_ssl_verification = false,
        encode_url = true,
        highlight = {
          enabled = true,
          timeout = 150,
        },
      })
    end,
    keys = {
      { "<leader>rr", "<Plug>RestNvim", desc = "Run REST request" },
      { "<leader>rp", "<Plug>RestNvimPreview", desc = "Preview REST request" },
      { "<leader>rl", "<Plug>RestNvimLast", desc = "Run last REST request" },
    },
  },

  -- Database client
  {
    "kristijanhusak/vim-dadbod",
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_save_location = "~/.local/share/db_ui"
    end,
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
  },

  -- Docker integration
  {
    "kkvh/vim-docker-tools",
    cmd = { "DockerToolsOpen", "DockerToolsToggle" },
  },

  -- Kubernetes integration
  {
    "rottencandy/vimkubectl",
    cmd = { "KubectlApply", "KubectlDelete", "KubectlGet" },
  },

  -- ============== DOCUMENTATION & DIAGRAMS ==============
  
  -- PlantUML for architecture diagrams
  {
    "weirongxu/plantuml-previewer.vim",
    dependencies = {
      "aklt/plantuml-syntax",
      "tyru/open-browser.vim",
    },
    ft = { "plantuml", "puml" },
  },

  -- Mermaid diagrams
  {
    "mracos/mermaid.vim",
    ft = { "mermaid", "markdown" },
  },

  -- ASCII diagrams
  {
    "jbyuki/venn.nvim",
    config = function()
      vim.keymap.set("n", "<leader>v", ":VBox<CR>", { desc = "Toggle Venn ASCII drawing" })
    end,
  },

  -- ============== CONFIGURATION MANAGEMENT ==============
  
  -- Jsonnet support
  {
    "google/vim-jsonnet",
    ft = { "jsonnet", "libsonnet" },
  },

  -- Dhall configuration language
  {
    "vmchale/dhall-vim",
    ft = { "dhall" },
  },

  -- Protocol Buffers
  {
    "uber/prototool",
    ft = { "proto" },
  },

  -- ============== MISC DEVOPS TOOLS ==============
  
  -- Makefile support
  {
    "mechatroner/rainbow_csv",
    ft = { "csv", "tsv" },
  },

  -- Environment variable files
  {
    "tpope/vim-dotenv",
    ft = { "env", "dotenv" },
  },

  -- SSH config files
  {
    "noahfrederick/vim-ssh-config",
    ft = { "sshconfig", "sshdconfig" },
  },

  -- Systemd unit files
  {
    "Matt-Deacalion/vim-systemd-syntax",
    ft = { "systemd" },
  },

  -- Crontab files
  {
    "vim-scripts/crontab.vim",
    ft = { "crontab" },
  },

  -- ============== AI ASSISTANCE ==============
  
  -- ChatGPT integration
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      require("chatgpt").setup({
        api_key_cmd = "echo $OPENAI_API_KEY"
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    },
    keys = {
      { "<leader>cc", "<cmd>ChatGPT<CR>", desc = "ChatGPT" },
      { "<leader>ce", "<cmd>ChatGPTEditWithInstruction<CR>", desc = "Edit with instruction", mode = { "n", "v" } },
      { "<leader>cg", "<cmd>ChatGPTRun grammar_correction<CR>", desc = "Grammar Correction", mode = { "n", "v" } },
      { "<leader>cd", "<cmd>ChatGPTRun docstring<CR>", desc = "Docstring", mode = { "n", "v" } },
      { "<leader>co", "<cmd>ChatGPTRun optimize_code<CR>", desc = "Optimize Code", mode = { "n", "v" } },
    },
  },

  -- ============== SESSION MANAGEMENT ==============
  
  -- Better session management for projects
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        log_level = "error",
        auto_session_suppress_dirs = { "~/", "~/Downloads", "/" },
        auto_session_use_git_branch = true,
      })
    end,
  },

  -- ============== PERFORMANCE MONITORING ==============
  
  -- Startup time analysis
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
  },

  -- ============== ADDITIONAL FORMATTERS ==============
  
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- Config files
        json = { "prettier", "jq" },
        yaml = { "prettier", "yamlfmt" },
        toml = { "taplo" },
        ini = { "ini" },
        
        -- Cloud configs
        hcl = { "hclfmt" },
        terraform = { "terraform_fmt" },
        
        -- Shell
        sh = { "shfmt", "shellcheck" },
        bash = { "shfmt", "shellcheck" },
        zsh = { "shfmt" },
        fish = { "fish_indent" },
        
        -- Documentation
        markdown = { "prettier", "markdownlint" },
        
        -- Containers
        dockerfile = { "hadolint" },
        
        -- CI/CD
        groovy = { "npm-groovy-lint" },
      },
    },
  },
}