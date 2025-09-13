return {
  -- vim-dadbod: Database interface
  {
    "tpope/vim-dadbod",
    lazy = true,
    cmd = { "DB", "DBUI", "DBUIToggle", "DBUIAddConnection" },
  },

  -- vim-dadbod-ui: UI for vim-dadbod
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 40

      -- Auto-save queries
      vim.g.db_ui_auto_execute_table_helpers = 1

      -- Icons
      vim.g.db_ui_icons = {
        expanded = {
          db = "▾ ",
          buffers = "▾ ",
          saved_queries = "▾ ",
          schemas = "▾ ",
          schema = "▾ פּ",
          tables = "▾ 藺",
          table = "▾ ",
        },
        collapsed = {
          db = "▸ ",
          buffers = "▸ ",
          saved_queries = "▸ ",
          schemas = "▸ ",
          schema = "▸ פּ",
          tables = "▸ 藺",
          table = "▸ ",
        },
        saved_query = "",
        new_query = "璘",
        tables = "離",
        buffers = "﬘",
        add_connection = "",
        connection_ok = "✓",
        connection_error = "✕",
      }
    end,
    keys = {
      { "<leader>db", "<cmd>DBUIToggle<cr>", desc = "Toggle Database UI" },
      { "<leader>dq", "<cmd>DBUIFindBuffer<cr>", desc = "Find Database Buffer" },
    },
  },

  -- vim-dadbod-completion: Auto-completion for vim-dadbod
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = "vim-dadbod",
    ft = { "sql", "mysql", "plsql" },
    lazy = true,
    config = function()
      -- Setup completion for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          local cmp = require("cmp")
          local sources = cmp.get_config().sources or {}
          table.insert(sources, { name = "vim-dadbod-completion" })
          cmp.setup.buffer({ sources = sources })
        end,
      })
    end,
  },
}