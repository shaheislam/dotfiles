-- Nix-aware LSP Configuration
-- Prioritizes Nix-provided LSPs over Mason-installed ones
-- This allows per-project LSP versioning via Nix flakes

-- Helper function to check if a command exists
local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result ~= ""
  end
  return false
end

-- Helper function to get command path (LSP or formatter)
-- Prioritizes Nix-provided tools, falls back to Mason
local function get_tool_cmd(nix_cmd, mason_cmd, tool_type)
  tool_type = tool_type or "tool"

  -- Check if we're in a Nix environment
  local in_nix_shell = os.getenv("IN_NIX_SHELL") ~= nil
  local nix_lsp_enabled = os.getenv("NIX_LSP_ENABLED") == "true"

  -- If in Nix shell or Nix LSP is enabled, prefer Nix
  if in_nix_shell or nix_lsp_enabled then
    if command_exists(nix_cmd) then
      vim.notify("Using Nix-provided " .. nix_cmd, vim.log.levels.DEBUG)
      return nix_cmd
    end
  end

  -- Check system-wide Nix installation
  if command_exists(nix_cmd) then
    vim.notify("Using system Nix " .. nix_cmd, vim.log.levels.DEBUG)
    return nix_cmd
  end

  -- Only fall back to Mason for formatters, not LSPs
  if tool_type == "formatter" then
    -- Check Mason for formatters
    local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. (mason_cmd or nix_cmd)
    if vim.fn.executable(mason_path) == 1 then
      vim.notify("Using Mason-provided " .. (mason_cmd or nix_cmd), vim.log.levels.DEBUG)
      return mason_path
    end
    return nil
  end

  -- For LSPs, don't fall back to Mason - only use Nix
  if tool_type == "lsp" then
    -- LSP not found - return nil to prevent starting
    -- Only notify in debug mode to avoid spam
    vim.notify("LSP " .. nix_cmd .. " not available from Nix", vim.log.levels.DEBUG)
    return nil
  end

  return nix_cmd
end

-- Export formatter command resolver for use by other plugins
_G.get_nix_formatter_cmd = function(nix_cmd, mason_cmd)
  return get_tool_cmd(nix_cmd, mason_cmd, "formatter")
end

return {
  -- Override LSP configuration to check for Nix-provided LSPs first
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    opts = function(_, opts)
      -- Wrapper for LSP commands (returns array for compatibility)
      local function get_lsp_cmd(nix_cmd, mason_cmd)
        local cmd = get_tool_cmd(nix_cmd, mason_cmd, "lsp")
        if cmd then
          return { cmd }
        end
        return nil
      end

      -- Override server configurations to use Nix-aware command resolution
      opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
        -- Go
        gopls = {
          cmd = get_lsp_cmd("gopls", "gopls"),
          settings = {
            gopls = {
              gofumpt = true,
              usePlaceholders = true,
              analyses = {
                unusedparams = true,
              },
            },
          },
        },

        -- Rust
        rust_analyzer = {
          cmd = get_lsp_cmd("rust-analyzer", "rust-analyzer"),
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
              },
            },
          },
        },

        -- Python
        basedpyright = {
          cmd = function()
            -- Try basedpyright-langserver first, then pyright-langserver
            local basedpyright_cmd = get_tool_cmd("basedpyright-langserver", nil, "lsp")
            if basedpyright_cmd then
              return { basedpyright_cmd, "--stdio" }
            end

            -- Fall back to pyright if basedpyright isn't available
            local pyright_cmd = get_tool_cmd("pyright-langserver", nil, "lsp")
            if pyright_cmd then
              vim.notify("Using pyright instead of basedpyright", vim.log.levels.INFO)
              return { pyright_cmd, "--stdio" }
            end

            return nil
          end,
        },

        pyright = {
          cmd = get_lsp_cmd("pyright-langserver", "pyright-langserver"),
        },

        ruff_lsp = {
          cmd = get_lsp_cmd("ruff-lsp", "ruff-lsp"),
        },

        -- TypeScript/JavaScript
        tsserver = {
          cmd = get_lsp_cmd("typescript-language-server", "typescript-language-server"),
        },

        -- Terraform
        terraformls = {
          cmd = get_lsp_cmd("terraform-ls", "terraform-ls"),
        },

        -- Ansible
        ansiblels = {
          cmd = get_lsp_cmd("ansible-language-server", "ansible-language-server"),
        },

        -- Docker
        dockerls = {
          cmd = get_lsp_cmd("docker-langserver", "docker-langserver"),
        },

        docker_compose_language_service = {
          cmd = get_lsp_cmd("docker-compose-langserver", "docker-compose-langserver"),
        },

        -- Helm
        helm_ls = {
          cmd = get_lsp_cmd("helm_ls", "helm-ls"),
        },

        -- YAML
        yamlls = {
          cmd = get_lsp_cmd("yaml-language-server", "yaml-language-server"),
        },

        -- JSON
        jsonls = {
          cmd = get_lsp_cmd("vscode-json-language-server", "vscode-json-language-server"),
        },

        -- Lua
        lua_ls = {
          cmd = get_lsp_cmd("lua-language-server", "lua-language-server"),
        },

        -- Markdown
        marksman = {
          cmd = get_lsp_cmd("marksman", "marksman"),
        },

        -- Bash
        bashls = {
          cmd = get_lsp_cmd("bash-language-server", "bash-language-server"),
        },

        -- TOML
        taplo = {
          cmd = get_lsp_cmd("taplo", "taplo"),
        },

        -- Nix
        nil_ls = {
          cmd = get_lsp_cmd("nil", "nil"),
          settings = {
            ["nil"] = {
              formatting = {
                command = { "nixpkgs-fmt" },
              },
            },
          },
        },

        -- SQL
        sqls = {
          cmd = get_lsp_cmd("sqls", "sqls"),
        },

        -- GraphQL
        graphql = {
          cmd = get_lsp_cmd("graphql-lsp", "graphql-lsp"),
        },

        -- Protocol Buffers
        bufls = {
          cmd = get_lsp_cmd("buf-language-server", "buf-language-server"),
        },
      })

      -- Filter out LSPs that don't have available commands
      local disabled_servers = {}
      if opts.servers then
        for server_name, server_config in pairs(opts.servers) do
          if server_config.cmd then
            -- Check if cmd is a function and call it
            if type(server_config.cmd) == "function" then
              local cmd_result = server_config.cmd()
              if not cmd_result then
                -- Disable this server if command not found
                opts.servers[server_name] = vim.tbl_extend("force", server_config, {
                  autostart = false,
                  filetypes = {}, -- Don't attach to any files
                })
                table.insert(disabled_servers, server_name)
              else
                server_config.cmd = cmd_result
              end
            elseif type(server_config.cmd) == "table" and server_config.cmd[1] == nil then
              -- Disable if cmd array is empty or has nil
              opts.servers[server_name] = vim.tbl_extend("force", server_config, {
                autostart = false,
                filetypes = {},
              })
              table.insert(disabled_servers, server_name)
            end
          end
        end
      end

      -- Show a single summary notification if servers were disabled
      if #disabled_servers > 0 then
        vim.defer_fn(function()
          vim.notify(
            "Some LSPs not available from Nix. Use <leader>nl to check status.",
            vim.log.levels.INFO,
            { title = "Nix LSP Status" }
          )
        end, 100)
      end

      return opts
    end,
  },

  -- Add notification when entering Nix environment
  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add startup notification if in Nix shell
      vim.defer_fn(function()
        if os.getenv("IN_NIX_SHELL") then
          local shell_name = os.getenv("name") or "default"
          vim.notify(
            "Nix shell active: " .. shell_name,
            vim.log.levels.INFO,
            { title = "Nix Environment" }
          )
        elseif vim.fn.filereadable("flake.nix") == 1 then
          vim.notify(
            "Nix flake detected. Run 'nix develop' or use direnv",
            vim.log.levels.INFO,
            { title = "Nix Environment" }
          )
        end
      end, 100)

      return opts
    end,
  },

  -- Status line component for Nix environment
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add Nix environment indicator to lualine
      local function nix_env()
        if os.getenv("IN_NIX_SHELL") then
          local name = os.getenv("name") or "nix"
          return "❄️  " .. name
        elseif vim.fn.filereadable("flake.nix") == 1 then
          return "❄️  (flake)"
        end
        return ""
      end

      -- Insert Nix indicator into existing lualine config
      if opts.sections and opts.sections.lualine_x then
        table.insert(opts.sections.lualine_x, 1, nix_env)
      end

      return opts
    end,
  },

  -- Commands for Nix operations
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      defaults = {
        ["<leader>n"] = { name = "+nix" },
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- Nix-specific keymaps
      wk.register({
        ["<leader>n"] = {
          name = "+nix",
          d = {
            function()
              vim.cmd("!nix develop")
            end,
            "Enter Nix develop shell",
          },
          u = {
            function()
              vim.cmd("!nix flake update")
            end,
            "Update flake.lock",
          },
          s = {
            function()
              -- Show current LSP information
              local clients = vim.lsp.get_active_clients()
              if #clients == 0 then
                vim.notify("No active LSP clients", vim.log.levels.INFO)
                return
              end

              local msg = "Active LSP Servers:\n"
              for _, client in ipairs(clients) do
                msg = msg .. "• " .. client.name

                -- Try to show if it's from Nix or Mason
                if client.config and client.config.cmd and client.config.cmd[1] then
                  local cmd = client.config.cmd[1]
                  if cmd:match("/nix/store/") then
                    msg = msg .. " (Nix)"
                  elseif cmd:match("/mason/") then
                    msg = msg .. " (Mason)"
                  else
                    msg = msg .. " (System)"
                  end
                end
                msg = msg .. "\n"
              end

              vim.notify(msg, vim.log.levels.INFO, { title = "LSP Status" })
            end,
            "Show LSP status",
          },
          l = {
            function()
              -- List available LSPs in current environment
              local lsps = {
                { cmd = "gopls", name = "Go" },
                { cmd = "rust-analyzer", name = "Rust" },
                { cmd = "typescript-language-server", name = "TypeScript" },
                { cmd = "basedpyright-langserver", name = "Python (Basedpyright)" },
                { cmd = "pyright-langserver", name = "Python (Pyright)" },
                { cmd = "terraform-ls", name = "Terraform" },
                { cmd = "ansible-language-server", name = "Ansible" },
                { cmd = "helm_ls", name = "Helm" },
                { cmd = "nil", name = "Nix" },
                { cmd = "lua-language-server", name = "Lua" },
              }

              local available = {}
              local unavailable = {}

              for _, lsp in ipairs(lsps) do
                if vim.fn.executable(lsp.cmd) == 1 then
                  table.insert(available, "✓ " .. lsp.name .. " (" .. lsp.cmd .. ")")
                else
                  table.insert(unavailable, "✗ " .. lsp.name .. " (" .. lsp.cmd .. ")")
                end
              end

              local msg = "Available LSPs in current environment:\n\n"
              if #available > 0 then
                msg = msg .. table.concat(available, "\n")
              else
                msg = msg .. "No LSPs found in current environment"
              end

              if #unavailable > 0 then
                msg = msg .. "\n\nNot available:\n" .. table.concat(unavailable, "\n")
              end

              vim.notify(msg, vim.log.levels.INFO, { title = "LSP Availability" })
            end,
            "List available LSPs",
          },
          f = {
            function()
              -- List available formatters and their sources
              local formatters = {
                { cmd = "stylua", name = "Lua" },
                { cmd = "black", name = "Python (Black)" },
                { cmd = "ruff", name = "Python (Ruff)" },
                { cmd = "prettier", name = "JS/TS/Markdown" },
                { cmd = "gofumpt", name = "Go (gofumpt)" },
                { cmd = "goimports", name = "Go (goimports)" },
                { cmd = "rustfmt", name = "Rust" },
                { cmd = "nixpkgs-fmt", name = "Nix" },
                { cmd = "shfmt", name = "Shell" },
                { cmd = "terraform", name = "Terraform" },
                { cmd = "taplo", name = "TOML" },
                { cmd = "sqlfmt", name = "SQL" },
              }

              local available = {}
              local unavailable = {}

              for _, fmt in ipairs(formatters) do
                local cmd_path = get_tool_cmd(fmt.cmd, fmt.cmd, "formatter")
                if cmd_path then
                  local source = "System"
                  if cmd_path:match("/nix/store/") then
                    source = "Nix"
                  elseif cmd_path:match("/mason/") then
                    source = "Mason"
                  end
                  table.insert(available, string.format("✓ %s (%s) [%s]", fmt.name, fmt.cmd, source))
                else
                  table.insert(unavailable, "✗ " .. fmt.name .. " (" .. fmt.cmd .. ")")
                end
              end

              local msg = "Available Formatters:\n\n"
              if #available > 0 then
                msg = msg .. table.concat(available, "\n")
              else
                msg = msg .. "No formatters found in current environment"
              end

              if #unavailable > 0 then
                msg = msg .. "\n\nNot available:\n" .. table.concat(unavailable, "\n")
                msg = msg .. "\n\nNote: Uncomment formatters in your Nix config to enable them"
              end

              vim.notify(msg, vim.log.levels.INFO, { title = "Formatter Availability" })
            end,
            "List available formatters",
          },
        },
      })
    end,
  },
}