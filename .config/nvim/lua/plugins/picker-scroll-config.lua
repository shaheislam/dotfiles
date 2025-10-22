-- Unified scroll configuration for Telescope and Snacks pickers
-- Adds Ctrl+u and Ctrl+d for preview scrolling across all pickers with smooth scrolling
-- Dynamic scope switching: <M-g> global, <M-s> service/repo, <M-l> local

return {
  -- Telescope configuration with preview scrolling
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-live-grep-args.nvim",
      "kkharji/sqlite.lua",  -- Required for smart history
      "nvim-telescope/telescope-smart-history.nvim",
    },
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          -- Enable smooth scrolling
          scroll_strategy = "limit", -- or "cycle" if you prefer wrapping
          layout_config = {
            scroll_speed = 3, -- Number of lines to scroll (lower = smoother)
          },
          -- Per-picker history configuration
          history = {
            path = vim.fn.stdpath("data") .. "/databases/telescope_history.sqlite3",
            limit = 100,
          },
          -- Disable treesitter highlighting in preview to avoid errors
          preview = {
            treesitter = false,
          },
          mappings = {
            -- Insert mode mappings
            i = {
              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,
              -- Add half-page scrolling for smoother experience
              ["<C-b>"] = actions.preview_scrolling_up,
              ["<C-f>"] = actions.preview_scrolling_down,
              -- Fuzzy refine: switch to fuzzy filtering on current results
              ["<C-Space>"] = actions.to_fuzzy_refine,
              -- Prompt history navigation (Vim-style)
              ["<C-p>"] = actions.cycle_history_prev,
              ["<C-n>"] = actions.cycle_history_next,
            },
            -- Normal mode mappings
            n = {
              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,
              ["<C-b>"] = actions.preview_scrolling_up,
              ["<C-f>"] = actions.preview_scrolling_down,
              -- Fuzzy refine: switch to fuzzy filtering on current results
              ["<C-Space>"] = actions.to_fuzzy_refine,
            },
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")

      -- Create database directory if it doesn't exist
      local data_path = vim.fn.stdpath("data")
      local db_dir = data_path .. "/databases"
      if vim.fn.isdirectory(db_dir) == 0 then
        vim.fn.mkdir(db_dir, "p")
      end

      telescope.setup(opts)

      -- Load extensions
      telescope.load_extension("smart_history")
      pcall(telescope.load_extension, "live_grep_args")
    end,
  },

  -- Snacks configuration with preview scrolling and dynamic scope switching
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- Helper function to get the service repo directory
      local function get_service_repo_dir()
        local cwd = vim.fn.getcwd()
        local work_dir = vim.fn.expand("~/work")

        if not vim.startswith(cwd, work_dir) then
          return work_dir
        end

        local relative = cwd:sub(#work_dir + 2)
        local first_slash = relative:find("/")

        if first_slash then
          local service_name = relative:sub(1, first_slash - 1)
          return work_dir .. "/" .. service_name
        else
          return cwd
        end
      end

      -- Custom scope change action for Snacks
      local function change_snacks_scope(picker, new_cwd, scope_name)
        local prompt = picker:get_prompt()
        local picker_title = picker.title or ""
        picker:close()

        -- Restart picker with new cwd
        vim.schedule(function()
          local lower_title = picker_title:lower()

          -- Detect picker type by title or source
          if picker.opts.source == "files" or
             (picker.opts.cmd and picker.opts.cmd:match("find")) or
             lower_title:match("files") then
            -- File picker
            require("snacks").picker.files({
              cwd = new_cwd,
              default_text = prompt,
              prompt = "Files (" .. scope_name .. ")",
            })
          elseif picker.opts.source == "grep" or
                 (picker.opts.cmd and picker.opts.cmd:match("rg")) or
                 lower_title:match("grep") or lower_title:match("search") then
            -- Grep picker
            require("snacks").picker.grep({
              cwd = new_cwd,
              default_text = prompt,
              prompt = "Grep (" .. scope_name .. ")",
            })
          elseif lower_title:match("buffer") then
            -- Buffers
            require("snacks").picker.buffers({
              default_text = prompt,
              prompt = "Buffers (" .. scope_name .. ")",
            })
          elseif lower_title:match("recent") or lower_title:match("oldfiles") then
            -- Recent files
            require("snacks").picker.recent({
              cwd = new_cwd,
              default_text = prompt,
              prompt = "Recent (" .. scope_name .. ")",
            })
          elseif lower_title:match("git") then
            -- Git-related pickers - keep as is, just update title
            if lower_title:match("log") then
              require("snacks").picker.git_log({
                cwd = new_cwd,
                default_text = prompt,
                prompt = "Git Log (" .. scope_name .. ")",
              })
            elseif lower_title:match("status") then
              require("snacks").picker.git_status({
                cwd = new_cwd,
                default_text = prompt,
                prompt = "Git Status (" .. scope_name .. ")",
              })
            elseif lower_title:match("diff") then
              require("snacks").picker.git_diff({
                cwd = new_cwd,
                default_text = prompt,
                prompt = "Git Diff (" .. scope_name .. ")",
              })
            else
              require("snacks").picker.git_files({
                cwd = new_cwd,
                default_text = prompt,
                prompt = "Git Files (" .. scope_name .. ")",
              })
            end
          else
            -- Default: assume file picker
            require("snacks").picker.files({
              cwd = new_cwd,
              default_text = prompt,
              prompt = "Files (" .. scope_name .. ")",
            })
          end
        end)
      end

      -- Merge with existing opts
      opts = opts or {}
      opts.picker = opts.picker or {}
      opts.picker.scroll = opts.picker.scroll or {
        enable = true,
        speed = 3,
        duration = 100,
      }

      opts.picker.win = opts.picker.win or {}
      opts.picker.win.input = opts.picker.win.input or {}
      opts.picker.win.input.keys = opts.picker.win.input.keys or {}

      local keys = opts.picker.win.input.keys

      -- Dynamic scope toggles (Alt-based to avoid conflicts)
      keys["<M-g>"] = {
        function(picker)
          change_snacks_scope(picker, vim.fn.expand("~/work"), "Global")
        end,
        mode = { "i", "n" },
        desc = "Switch to Global scope (~/work)",
      }

      keys["<M-s>"] = {
        function(picker)
          change_snacks_scope(picker, get_service_repo_dir(), "Service")
        end,
        mode = { "i", "n" },
        desc = "Switch to Service/Repo scope",
      }

      keys["<M-l>"] = {
        function(picker)
          change_snacks_scope(picker, vim.fn.getcwd(), "Local")
        end,
        mode = { "i", "n" },
        desc = "Switch to Local scope (cwd)",
      }

      -- Preview scrolling
      keys["<C-u>"] = { "preview_scroll_up", mode = { "i", "n" } }
      keys["<C-d>"] = { "preview_scroll_down", mode = { "i", "n" } }
      keys["<C-b>"] = { "preview_page_up", mode = { "i", "n" } }
      keys["<C-f>"] = { "preview_page_down", mode = { "i", "n" } }

      -- Toggle live mode
      keys["<C-Space>"] = { "toggle_live", mode = { "i", "n" } }

      -- Global scroll configuration
      opts.scroll = opts.scroll or {}
      opts.scroll.animate = opts.scroll.animate or {
        duration = { step = 10, total = 100 },
        easing = "linear",
      }

      return opts
    end,
  },

  -- mini.animate - DISABLED to prevent scrolling lag
  -- Even with all animations disabled, the plugin adds overhead
  -- Uncomment only if you need specific animations
  -- {
  --   "nvim-mini/mini.animate",
  --   enabled = false,
  -- },
}