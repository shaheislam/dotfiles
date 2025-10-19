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
    -- Note: LspAttach autocmd for enabling inlay hints is handled in lua/config/autocmds/lsp.lua
    -- to avoid duplication and conflicts
    keys = {
      -- Toggle inlay hints globally (all buffers with LSP attached)
      {
        "<leader>uh",
        function()
          if vim.lsp.inlay_hint then
            -- Get all buffers with LSP clients attached
            local buffers = vim.api.nvim_list_bufs()
            local has_any_enabled = false
            local lsp_buffers = {}

            -- Check which buffers have LSP and inlay hints
            for _, buf in ipairs(buffers) do
              if vim.api.nvim_buf_is_loaded(buf) then
                local clients = vim.lsp.get_clients({ bufnr = buf })
                if #clients > 0 then
                  table.insert(lsp_buffers, buf)
                  if vim.lsp.inlay_hint.is_enabled({ bufnr = buf }) then
                    has_any_enabled = true
                  end
                end
              end
            end

            -- Toggle all LSP buffers to the opposite state
            local new_state = not has_any_enabled
            for _, buf in ipairs(lsp_buffers) do
              vim.lsp.inlay_hint.enable(new_state, { bufnr = buf })
            end

            vim.notify(
              "Inlay Hints (Global) " .. (new_state and "Enabled" or "Disabled"),
              vim.log.levels.INFO
            )
          end
        end,
        desc = "Toggle Inlay Hints (Global)",
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