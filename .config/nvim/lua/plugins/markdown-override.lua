-- Override LazyVim's markdown extras to disable markdownlint-cli2
-- This prevents the "Error running markdownlint-cli2: ENOENT" error
-- while keeping other markdown features like preview and render-markdown

return {
  -- Disable markdownlint-cli2 in conform.nvim
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      -- Remove markdownlint-cli2 from markdown formatters
      if opts.formatters_by_ft then
        opts.formatters_by_ft.markdown = { "prettier" }
        opts.formatters_by_ft["markdown.mdx"] = { "prettier" }
      end

      -- Disable markdownlint-cli2 formatter entirely
      if opts.formatters then
        opts.formatters["markdownlint-cli2"] = nil
      end

      return opts
    end,
  },

  -- Disable markdownlint-cli2 in Mason auto-install
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      -- Remove markdownlint-cli2 from ensure_installed
      if opts.ensure_installed then
        opts.ensure_installed = vim.tbl_filter(function(tool)
          return tool ~= "markdownlint-cli2"
        end, opts.ensure_installed)
      end
      return opts
    end,
  },

  -- Disable markdownlint-cli2 in nvim-lint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      -- Remove markdownlint-cli2 from markdown linters
      if opts.linters_by_ft then
        opts.linters_by_ft.markdown = {}
      end
      return opts
    end,
  },

  -- Disable markdownlint in none-ls (if used)
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      -- Filter out markdownlint diagnostics
      if opts.sources then
        opts.sources = vim.tbl_filter(function(source)
          return source.name ~= "markdownlint_cli2"
        end, opts.sources)
      end
      return opts
    end,
  },
}
