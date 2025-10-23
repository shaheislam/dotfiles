-- ~/.config/nvim/lua/plugins/formatting.lua
-- Code formatting configuration using conform.nvim
-- Extracted from misc.lua for better organization

return {
  -- Configure conform.nvim (LazyVim includes this but we'll add your formatters)
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        formatters_by_ft = {
          lua = { 'stylua' },
          python = { 'ruff_organize_imports', 'ruff_format' }, -- Use ruff for both import sorting and formatting
          javascript = { 'prettierd', 'prettier', stop_after_first = true },
          typescript = { 'prettierd', 'prettier', stop_after_first = true },
          json = { 'prettierd', 'prettier', stop_after_first = true },
          yaml = { 'prettierd', 'prettier', stop_after_first = true },
          terraform = { 'terraform_fmt' },
          go = { 'goimports', 'gofmt' },
          rust = { 'rustfmt' },
          markdown = { 'prettierd', 'prettier', stop_after_first = true },
        },
      })
    end,
  },
}
