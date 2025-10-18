-- Advanced LSP Formatting Configuration
-- Extends LazyVim's formatting with more control and language-specific settings

return {
  -- Configure formatters via conform.nvim (LazyVim's formatter)
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Helper to get formatter command with Nix priority
      local function get_formatter_cmd(formatter_name)
        if _G.get_nix_formatter_cmd then
          return _G.get_nix_formatter_cmd(formatter_name, formatter_name)
        end
        -- Fallback to standard executable check
        if vim.fn.executable(formatter_name) == 1 then
          return formatter_name
        end
        return nil
      end

      -- Function to filter available formatters
      local function filter_available_formatters(formatters)
        local available = {}
        for _, formatter in ipairs(formatters) do
          if get_formatter_cmd(formatter) then
            table.insert(available, formatter)
          end
        end
        return available
      end
      -- DISABLED: Auto-formatting disabled to preserve manual formatting
      -- Toggle with <leader>uf (buffer) or <leader>uF (global) to re-enable
      opts.format_on_save = false

      -- Original format_on_save function (commented out):
      -- opts.format_on_save = function(bufnr)
      --   -- Disable format on save for specific filetypes
      --   local disable_filetypes = { c = true, cpp = true, markdown = true }
      --   if disable_filetypes[vim.bo[bufnr].filetype] then
      --     return false
      --   end
      --
      --   -- Disable for large files
      --   local max_lines = 10000
      --   if vim.api.nvim_buf_line_count(bufnr) > max_lines then
      --     return false
      --   end
      --
      --   -- Use LSP formatting for Go (gofmt/goimports via gopls)
      --   if vim.bo[bufnr].filetype == "go" then
      --     return {
      --       timeout_ms = 2000,
      --       lsp_format = "prefer", -- Use LSP formatting when available
      --     }
      --   end
      --
      --   -- Return default settings for other filetypes
      --   return {
      --     timeout_ms = 500,
      --     lsp_format = "fallback", -- Use LSP as fallback if no formatter configured
      --   }
      -- end

      -- Configure specific formatters (filtered by availability)
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
        python = filter_available_formatters({ "ruff_format", "black" }), -- Ruff first, black as fallback
        javascript = filter_available_formatters({ "prettier", "eslint" }),
        typescript = filter_available_formatters({ "prettier", "eslint" }),
        javascriptreact = filter_available_formatters({ "prettier", "eslint" }),
        typescriptreact = filter_available_formatters({ "prettier", "eslint" }),
        -- json = filter_available_formatters({ "prettier" }), -- Disabled: prettier normalizes formatting
        yaml = filter_available_formatters({ "prettier" }),
        markdown = filter_available_formatters({ "prettier" }),
        html = filter_available_formatters({ "prettier" }),
        css = filter_available_formatters({ "prettier" }),
        scss = filter_available_formatters({ "prettier" }),
        lua = filter_available_formatters({ "stylua" }),
        rust = filter_available_formatters({ "rustfmt" }),
        go = filter_available_formatters({ "gofumpt", "goimports" }),
        sh = filter_available_formatters({ "shfmt" }),
        terraform = filter_available_formatters({ "terraform_fmt" }),
        sql = filter_available_formatters({ "sqlfmt", "sql-formatter" }),
        nix = filter_available_formatters({ "nixpkgs-fmt", "nixfmt" }),
      })

      -- Custom formatter configurations with Nix-aware command paths
      local formatter_configs = {}

      -- Configure each formatter with its Nix-provided path
      local formatters_to_configure = {
        shfmt = { prepend_args = { "-i", "2", "-ci" } }, -- 2 spaces, indent case statements
        prettier = { prepend_args = { "--prose-wrap", "always", "--print-width", "200" } },
        black = { prepend_args = { "--fast", "--line-length", "100" } },
        stylua = { prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" } },
        rustfmt = { prepend_args = { "--edition", "2021" } },
        nixpkgs_fmt = { command = get_formatter_cmd("nixpkgs-fmt") },
        gofumpt = { command = get_formatter_cmd("gofumpt") },
        goimports = { command = get_formatter_cmd("goimports") },
      }

      for name, config in pairs(formatters_to_configure) do
        local cmd = config.command or get_formatter_cmd(name)
        if cmd then
          formatter_configs[name] = vim.tbl_extend("force", config, { command = cmd })
        end
      end

      opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, formatter_configs)

      return opts
    end,
    keys = {
      -- Format commands
      { "<leader>cf", "<cmd>ConformFormat<cr>", desc = "Format Buffer" },
      {
        "<leader>cF",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format Buffer (Async)",
      },
      -- Format selection
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "v" },
        desc = "Format Selection",
      },
      -- Toggle format on save
      {
        "<leader>uf",
        function()
          if vim.b.autoformat == false then
            vim.b.autoformat = true
            vim.notify("Format on save: enabled (buffer)", vim.log.levels.INFO)
          else
            vim.b.autoformat = false
            vim.notify("Format on save: disabled (buffer)", vim.log.levels.WARN)
          end
        end,
        desc = "Toggle Format on Save (Buffer)",
      },
      {
        "<leader>uF",
        function()
          if vim.g.autoformat == false then
            vim.g.autoformat = true
            vim.notify("Format on save: enabled (global)", vim.log.levels.INFO)
          else
            vim.g.autoformat = false
            vim.notify("Format on save: disabled (global)", vim.log.levels.WARN)
          end
        end,
        desc = "Toggle Format on Save (Global)",
      },
    },
  },

  -- Additional formatting utilities
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Add format on save capabilities to LSP
      local function lsp_format_on_save(client, bufnr)
        if client.supports_method("textDocument/formatting") then
          -- Create an autocmd for this specific buffer
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("LspFormatting_" .. bufnr, { clear = true }),
            buffer = bufnr,
            callback = function()
              -- Check if formatting is enabled
              if vim.b[bufnr].autoformat == false or vim.g.autoformat == false then
                return
              end

              -- Format with timeout
              vim.lsp.buf.format({
                bufnr = bufnr,
                timeout_ms = 2000,
                filter = function(c)
                  -- Only use clients that support formatting
                  return c.supports_method("textDocument/formatting")
                end,
              })
            end,
          })
        end
      end

      -- Override the on_attach to add formatting
      local on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr)
        if on_attach then
          on_attach(client, bufnr)
        end
        -- Don't add LSP format on save if conform is handling it
        -- This is handled by conform.nvim's lsp_format option
      end

      return opts
    end,
  },

  -- Add support for format on modified lines only (using git diff)
  {
    "mhartington/formatter.nvim",
    enabled = false, -- Disabled by default, enable if you want this feature
    opts = function()
      return {
        filetype = {
          -- Configure formatters that support range formatting
          python = {
            function()
              return {
                exe = "black",
                args = { "--fast", "--line-length", "100", "-" },
                stdin = true,
              }
            end,
          },
        },
      }
    end,
  },

  -- EditorConfig support for consistent formatting across editors
  {
    "editorconfig/editorconfig-vim",
    event = "BufReadPre",
  },
}