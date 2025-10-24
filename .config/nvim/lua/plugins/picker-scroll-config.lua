-- Unified scroll configuration for fzf-lua and Snacks pickers
-- Adds Ctrl+u and Ctrl+d for preview scrolling across all pickers with smooth scrolling
-- Dynamic scope switching: <M-g> global, <M-s> service/repo, <M-l> local
-- NOTE: Telescope configuration removed - now using fzf-lua (see fzf-lua.lua)

return {
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