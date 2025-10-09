-- Native inlay hints configuration for Neovim v0.10+
-- Compatible with LazyVim's LSP setup

return {
  -- Configure LSP settings for inlay hints
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Enable inlay hints in LazyVim
      inlay_hints = {
        enabled = true,
      },
      -- Setup hooks for all servers
      servers = {},
    },
    init = function()
      -- Hook into LSP attach to enable native inlay hints
      local lsp_attach = vim.api.nvim_create_augroup("lsp_inlay_hints", { clear = true })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp_attach,
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local bufnr = args.buf

          -- Enable native inlay hints if supported
          if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end
        end,
      })
    end,
    keys = {
      -- Toggle inlay hints globally
      {
        "<leader>uh",
        function()
          if vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
            vim.notify(
              "Inlay Hints " .. (vim.lsp.inlay_hint.is_enabled() and "Enabled" or "Disabled"),
              vim.log.levels.INFO
            )
          end
        end,
        desc = "Toggle Inlay Hints",
      },
      -- Toggle for current buffer only
      {
        "<leader>uH",
        function()
          if vim.lsp.inlay_hint then
            local bufnr = vim.api.nvim_get_current_buf()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
            vim.notify(
              "Inlay Hints (Buffer) " .. (not enabled and "Enabled" or "Disabled"),
              vim.log.levels.INFO
            )
          end
        end,
        desc = "Toggle Inlay Hints (Buffer)",
      },
    },
  },

  -- Configure highlighting for inlay hints
  {
    "folke/tokyonight.nvim",
    opts = {
      on_highlights = function(highlights, colors)
        -- Customize inlay hint appearance for Tokyo Night
        highlights.LspInlayHint = {
          bg = colors.bg_dark,
          fg = colors.dark3,
          italic = true,
        }
      end,
    },
  },
}