-- Telescope dynamic scope switching within active picker
-- <M-g>: Switch to Global scope (~/work)
-- <M-s>: Switch to Service/Repo scope (parent under ~/work)
-- <M-l>: Switch to Local scope (cwd)

return {
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

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

      -- Custom action to change search scope dynamically
      local function change_scope(prompt_bufnr, new_cwd, scope_name)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local finder = current_picker.finder

        -- Get the current prompt text and picker title
        local prompt = action_state.get_current_line()
        local original_title = current_picker.prompt_title or ""

        -- Close current picker
        actions.close(prompt_bufnr)

        -- Determine picker type based on finder and original title
        vim.schedule(function()
          local lower_title = original_title:lower()

          -- Detect picker type by title or finder characteristics
          if lower_title:match("find") or lower_title:match("files") or
             (finder.results_title and finder.results_title:match("[Ff]iles")) then
            -- File finder
            require("telescope.builtin").find_files({
              cwd = new_cwd,
              hidden = true,
              no_ignore = false,
              follow = true,
              default_text = prompt,
              prompt_title = "Find Files (" .. scope_name .. ")",
            })
          elseif lower_title:match("grep") or lower_title:match("search") then
            -- Live grep
            require("telescope.builtin").live_grep({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Live Grep (" .. scope_name .. ")",
            })
          elseif lower_title:match("buffer") then
            -- Buffers - keep default cwd, just update title
            require("telescope.builtin").buffers({
              default_text = prompt,
              prompt_title = "Buffers (" .. scope_name .. ")",
            })
          elseif lower_title:match("oldfiles") or lower_title:match("recent") then
            -- Recent files
            require("telescope.builtin").oldfiles({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Recent Files (" .. scope_name .. ")",
            })
          else
            -- Default: assume file finder
            require("telescope.builtin").find_files({
              cwd = new_cwd,
              hidden = true,
              no_ignore = false,
              follow = true,
              default_text = prompt,
              prompt_title = "Find Files (" .. scope_name .. ")",
            })
          end
        end)
      end

      -- Ensure mappings table exists
      opts.defaults = opts.defaults or {}
      opts.defaults.mappings = opts.defaults.mappings or {}
      opts.defaults.mappings.i = opts.defaults.mappings.i or {}
      opts.defaults.mappings.n = opts.defaults.mappings.n or {}

      -- Add scope toggle mappings for insert mode (Alt-based)
      opts.defaults.mappings.i["<M-g>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, vim.fn.expand("~/work"), "Global")
      end

      opts.defaults.mappings.i["<M-s>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_service_repo_dir(), "Service")
      end

      opts.defaults.mappings.i["<M-l>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, vim.fn.getcwd(), "Local")
      end

      -- Add scope toggle mappings for normal mode (Alt-based)
      opts.defaults.mappings.n["<M-g>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, vim.fn.expand("~/work"), "Global")
      end

      opts.defaults.mappings.n["<M-s>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_service_repo_dir(), "Service")
      end

      opts.defaults.mappings.n["<M-l>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, vim.fn.getcwd(), "Local")
      end

      return opts
    end,
  },
}
