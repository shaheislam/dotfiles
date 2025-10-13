-- Advanced LSP Enhancements
-- Extends LazyVim's LSP configuration with additional features

return {
  -- Enhanced LSP configuration
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Enhanced diagnostics configuration
      local diagnostics = {
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
          -- Only show virtual text for errors and warnings
          severity = { min = vim.diagnostic.severity.WARN },
        },
        severity_sort = true,
        float = {
          focusable = false,
          style = "minimal",
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = " ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
      }

      vim.diagnostic.config(diagnostics)

      -- Enhanced hover configuration
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
        vim.lsp.handlers.hover,
        {
          border = "rounded",
          max_width = 80,
          max_height = 20,
        }
      )

      -- Enhanced signature help configuration
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help,
        {
          border = "rounded",
          focusable = false,
          relative = "cursor",
        }
      )

      -- Progress handler for LSP operations
      local function lsp_progress_handler()
        local clients = vim.lsp.get_active_clients()
        if next(clients) == nil then
          return " LSP Inactive"
        end

        local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if next(buf_clients) == nil then
          return " LSP Inactive"
        end

        local buf_client_names = {}
        for _, client in pairs(buf_clients) do
          table.insert(buf_client_names, client.name)
        end

        return " " .. table.concat(buf_client_names, ", ")
      end

      -- Store the handler function for use in statusline
      vim.g.lsp_progress = lsp_progress_handler

      return opts
    end,
    keys = {
      -- Diagnostic navigation with descriptions
      { "]d", vim.diagnostic.goto_next, desc = "Next Diagnostic" },
      { "[d", vim.diagnostic.goto_prev, desc = "Previous Diagnostic" },
      { "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Next Error" },
      { "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Previous Error" },
      { "]w", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end, desc = "Next Warning" },
      { "[w", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end, desc = "Previous Warning" },

      -- Diagnostic actions
      { "<leader>cl", vim.diagnostic.open_float, desc = "Line Diagnostics" },
      { "<leader>cD", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>cW", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },

      -- Enhanced hover
      {
        "K",
        function()
          local winid = require("ufo").peekFoldedLinesUnderCursor()
          if not winid then
            vim.lsp.buf.hover()
          end
        end,
        desc = "Hover Documentation",
      },

      -- Signature help
      { "<C-k>", vim.lsp.buf.signature_help, mode = { "n", "i" }, desc = "Signature Help" },

      -- Workspace symbols with preview
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Workspace Symbols" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document Symbols" },
    },
  },

  -- Better diagnostics list with trouble.nvim v3 (if not already present)
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
      modes = {
        diagnostics = {
          auto_open = false,
          auto_close = true,
          auto_preview = true,
          auto_refresh = true,
          focus = true,
        },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
      { "<leader>xQ", "<cmd>Trouble quickfix toggle<cr>", desc = "Quickfix List (Trouble)" },
      {
        "[q",
        function()
          if require("trouble").is_open() then
            require("trouble").prev({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "Previous Quickfix",
      },
      {
        "]q",
        function()
          if require("trouble").is_open() then
            require("trouble").next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "Next Quickfix",
      },
    },
  },

  -- nvim-ufo for better folding (referenced in hover key above)
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    event = "BufReadPost",
    opts = {
      provider_selector = function(bufnr, filetype, buftype)
        return { "treesitter", "indent" }
      end,
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("  %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end,
    },
    config = function(_, opts)
      require("ufo").setup(opts)
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
  },

  -- Lsp lines for better inline diagnostics (optional, can be toggled)
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    event = "LspAttach",
    keys = {
      {
        "<leader>ul",
        function()
          local lines_enabled = vim.diagnostic.config().virtual_lines
          vim.diagnostic.config({ virtual_lines = not lines_enabled })
          if lines_enabled then
            vim.diagnostic.config({ virtual_text = true })
          else
            vim.diagnostic.config({ virtual_text = false })
          end
        end,
        desc = "Toggle LSP Lines",
      },
    },
    config = function()
      require("lsp_lines").setup()
      -- Start with lsp_lines disabled
      vim.diagnostic.config({ virtual_lines = false })
    end,
  },

  -- Document symbols outline (already present via LazyVim outline extra, just adding config)
  {
    "hedyhli/outline.nvim",
    keys = {
      { "<leader>co", "<cmd>Outline<cr>", desc = "Toggle Outline" },
    },
    opts = {
      outline_window = {
        position = "right",
        width = 25,
        relative_width = false,
        auto_close = false,
        auto_jump = false,
        jump_highlight_duration = 300,
        center_on_jump = true,
        show_numbers = false,
        show_relative_numbers = false,
        wrap = false,
      },
      outline_items = {
        show_symbol_details = true,
        show_symbol_lineno = false,
        highlight_hovered_item = true,
        auto_set_cursor = true,
        auto_update_events = {
          follow = { "CursorMoved" },
          items = { "InsertLeave", "WinEnter", "BufEnter", "BufWinEnter", "TabEnter", "BufWritePost" },
        },
      },
      symbols = {
        icon_source = "lspkind",
      },
      providers = {
        priority = { "lsp", "coc", "markdown", "norg" },
        lsp = {
          blacklist_clients = {},
        },
      },
      keymaps = {
        show_help = "?",
        close = { "<Esc>", "q" },
        goto_location = "<CR>",
        peek_location = "o",
        goto_and_close = "<S-CR>",
        restore_location = "<C-g>",
        hover_symbol = "<C-space>",
        toggle_preview = "K",
        rename_symbol = "r",
        code_actions = "a",
        fold = "h",
        unfold = "l",
        fold_toggle = "<Tab>",
        fold_toggle_all = "<S-Tab>",
        fold_all = "W",
        unfold_all = "E",
        fold_reset = "R",
        down_and_jump = "<C-j>",
        up_and_jump = "<C-k>",
      },
    },
  },
}