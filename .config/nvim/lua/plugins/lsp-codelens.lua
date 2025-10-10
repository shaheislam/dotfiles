-- Code Lens Configuration for Multiple Languages
-- Provides inline code actions like "Run Test", "Debug", references count, etc.

return {
  -- Configure code lens for various language servers
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Rust code lens (already configured via rustaceanvim)
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              lens = {
                enable = true,
                references = {
                  adt = { enable = true },
                  enumVariant = { enable = true },
                  method = { enable = true },
                  trait = { enable = true },
                },
                implementations = { enable = true },
                run = { enable = true },
                debug = { enable = true },
              },
            },
          },
        },

        -- TypeScript/JavaScript code lens
        tsserver = {
          settings = {
            typescript = {
              implementationsCodeLens = { enabled = true },
              referencesCodeLens = {
                enabled = true,
                showOnAllFunctions = true,
              },
            },
            javascript = {
              implementationsCodeLens = { enabled = true },
              referencesCodeLens = {
                enabled = true,
                showOnAllFunctions = true,
              },
            },
          },
        },

        -- Python code lens (basedpyright)
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                -- Enable code lens for Python
                enableCodeLens = true,
              },
            },
            python = {
              analysis = {
                -- Additional Python analysis settings
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
              },
            },
          },
        },

        -- C/C++ code lens (if using clangd)
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
        },

        -- Java code lens (if using jdtls)
        jdtls = {
          settings = {
            java = {
              referencesCodeLens = { enabled = true },
              implementationsCodeLens = { enabled = true },
              signatureHelp = { enabled = true },
            },
          },
        },

        -- Lua code lens
        lua_ls = {
          settings = {
            Lua = {
              hint = {
                enable = true,
                setType = false,
                paramType = true,
                paramName = "Disable",
                semicolon = "Disable",
                arrayIndex = "Disable",
              },
              codeLens = {
                enable = true,
              },
            },
          },
        },
      },
    },
    init = function()
      -- Code lens auto-refresh is disabled by default to avoid errors
      -- Uncomment the following to enable auto-refresh if your LSP servers support it
      --[[
      vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
        pattern = "*",
        callback = function(args)
          local bufnr = args.buf
          if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
            return
          end
          if vim.bo[bufnr].buftype ~= "" then
            return
          end
          local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
          for _, client in pairs(clients) do
            if client.server_capabilities and client.server_capabilities.codeLensProvider then
              pcall(vim.lsp.codelens.refresh)
              return
            end
          end
        end,
      })
      --]]
    end,
    keys = {
      -- Code lens keymaps (simplified to avoid API issues)
      {
        "<leader>cl",
        function()
          pcall(vim.lsp.codelens.run)
        end,
        desc = "Run Code Lens"
      },
      {
        "<leader>cL",
        function()
          pcall(vim.lsp.codelens.refresh)
        end,
        desc = "Refresh Code Lens"
      },
    },
  },

  -- nvim-dap integration for running/debugging from code lens
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- Debug adapter installations
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = "mason.nvim",
      cmd = { "DapInstall", "DapUninstall" },
      opts = {
        automatic_installation = true,
        ensure_installed = {
          "python",
          "codelldb", -- Rust/C/C++
          "js-debug-adapter",
          "go-debug-adapter",
        },
      },
    },
    keys = {
      -- Debug keymaps that work with code lens
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest Test" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Breakpoint Condition" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dO", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() require("dap").session() end, desc = "Session" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    },
  },

  -- Test integration for code lens "Run Test" actions
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
      "nvim-neotest/neotest-jest",
      "rouge8/neotest-rust",
      "nvim-neotest/neotest-vim-test",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      -- Add test adapters for different languages
      table.insert(opts.adapters, require("neotest-python")({
        dap = { justMyCode = false },
        runner = "pytest",
      }))

      table.insert(opts.adapters, require("neotest-go")({
        experimental = {
          test_table = true,
        },
      }))

      table.insert(opts.adapters, require("neotest-jest")({
        jestCommand = "npm test --",
        env = { CI = true },
        cwd = function(path)
          return vim.fn.getcwd()
        end,
      }))

      table.insert(opts.adapters, require("neotest-rust")({
        args = { "--no-capture" },
      }))

      return opts
    end,
    keys = {
      -- Test running keymaps (work with code lens)
      { "<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File Tests" },
      { "<leader>tT", function() require("neotest").run.run(vim.uv.cwd()) end, desc = "Run All Tests" },
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest Test" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run Last Test" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Test Summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Test Output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Test Output Panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop Tests" },
      { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Toggle Test Watch" },
    },
  },

  -- Virtual text for references/implementations count
  {
    "Wansmer/symbol-usage.nvim",
    event = "LspAttach",
    config = function()
      local hl = vim.api.nvim_set_hl

      hl(0, "SymbolUsageRounding", { fg = "#2a2a37", italic = true })
      hl(0, "SymbolUsageContent", { bg = "#2a2a37", fg = "#898b9a", italic = true })
      hl(0, "SymbolUsageRef", { fg = "#70a5eb", bg = "#2a2a37", italic = true })
      hl(0, "SymbolUsageDef", { fg = "#eba070", bg = "#2a2a37", italic = true })
      hl(0, "SymbolUsageImpl", { fg = "#eb7097", bg = "#2a2a37", italic = true })

      local function text_format(symbol)
        local res = {}

        -- Rounded corners
        table.insert(res, { "⟪", "SymbolUsageRounding" })

        -- References
        if symbol.references then
          table.insert(res, { "󰌹 " .. tostring(symbol.references), "SymbolUsageRef" })
        end

        -- Definition
        if symbol.definition then
          if #res > 1 then
            table.insert(res, { " ", "SymbolUsageContent" })
          end
          table.insert(res, { "󰳽 " .. tostring(symbol.definition), "SymbolUsageDef" })
        end

        -- Implementation
        if symbol.implementation then
          if #res > 1 then
            table.insert(res, { " ", "SymbolUsageContent" })
          end
          table.insert(res, { "󰡱 " .. tostring(symbol.implementation), "SymbolUsageImpl" })
        end

        -- Closing
        table.insert(res, { "⟫", "SymbolUsageRounding" })

        return res
      end

      require("symbol-usage").setup({
        text_format = text_format,
        vt_position = "end_of_line",
        disable = { lsp = { "pylsp", "pyright" } }, -- Disabled for some LSPs that don't support it well
        filetypes = { -- Enable only for specific filetypes
          "rust",
          "go",
          "typescript",
          "javascript",
          "typescriptreact",
          "javascriptreact",
          "lua",
          "c",
          "cpp",
          "java",
        },
      })
    end,
  },
}