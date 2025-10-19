-- Telescope dynamic scope switching within active picker
-- <M-g>: Switch to Global scope (~/work)
-- <M-s>: Switch to Service/Repo scope (parent under ~/work)
-- <M-l>: Switch to Local scope (cwd)
-- <M-d>: Switch to current buffer's Directory
-- <M-p>: Switch to Parent directory (refine up one level)

-- Store the original buffer number before opening telescope
-- This lets us check if we came from an Oil buffer
local original_bufnr = nil

return {
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      -- Store the current buffer before telescope opens
      -- This will be called when telescope initializes
      local telescope_builtin = require("telescope.builtin")
      local original_builtin = {}

      -- Wrap common pickers to capture the buffer
      for name, func in pairs(telescope_builtin) do
        original_builtin[name] = func
        telescope_builtin[name] = function(opts_inner)
          original_bufnr = vim.api.nvim_get_current_buf()
          return original_builtin[name](opts_inner)
        end
      end

      -- Helper function to get the git repository root directory
      -- Works with any git repository (dotfiles, work projects, etc.)
      local function get_service_repo_dir()
        -- First, try to get git root from Oil's current directory if applicable
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local ft = vim.api.nvim_buf_get_option(original_bufnr, "filetype")
          if ft == "oil" then
            local oil_dir = require("oil").get_current_dir(original_bufnr)
            if oil_dir then
              -- Find git root from Oil directory
              local git_root = vim.fs.find(".git", { path = oil_dir, upward = true })[1]
              if git_root then
                return vim.fn.fnamemodify(git_root, ":h")
              end
            end
          end
        end

        -- Fallback: use LazyVim's git root detection
        return LazyVim.root.git()
      end

      -- Helper function to get the local directory
      -- Respects Oil.nvim's current directory when applicable
      local function get_local_dir()
        -- Check if the original buffer (before telescope opened) was an oil buffer
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local ft = vim.api.nvim_buf_get_option(original_bufnr, "filetype")
          if ft == "oil" then
            -- Get the Oil directory from the original buffer
            local oil_dir = require("oil").get_current_dir(original_bufnr)
            if oil_dir then
              return oil_dir
            end
          end
        end
        -- Fallback to vim's cwd
        return vim.fn.getcwd()
      end

      -- Helper function to get the current buffer's directory
      -- Returns the directory of the file being edited, not cwd or Oil directory
      local function get_buffer_dir()
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local bufname = vim.api.nvim_buf_get_name(original_bufnr)
          if bufname and bufname ~= "" then
            -- Get the directory of the file
            local dir = vim.fn.fnamemodify(bufname, ":h")
            if dir and dir ~= "" then
              return dir
            end
          end
        end
        -- Fallback to cwd if no valid buffer
        return vim.fn.getcwd()
      end

      -- Helper function to get the parent directory of current picker scope
      local function get_parent_dir(prompt_bufnr)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        -- Try to get cwd from picker options, fallback to vim's cwd
        local current_cwd = (current_picker.finder and current_picker.finder.cwd)
                         or current_picker.cwd
                         or vim.fn.getcwd()

        local parent = vim.fn.fnamemodify(current_cwd, ":h")

        -- Prevent going above root
        if parent == current_cwd or parent == "" or parent == "." then
          vim.notify("Already at filesystem root", vim.log.levels.WARN)
          return nil
        end

        return parent
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
          -- Check for more specific patterns first before generic ones
          if lower_title:match("recent") or lower_title:match("oldfiles") then
            -- Recent files - must check this before "files" pattern
            require("telescope.builtin").oldfiles({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Recent Files (" .. scope_name .. ")",
            })
          elseif lower_title:match("buffer") then
            -- Buffers - keep default cwd, just update title
            require("telescope.builtin").buffers({
              default_text = prompt,
              prompt_title = "Buffers (" .. scope_name .. ")",
            })
          elseif lower_title:match("grep") or lower_title:match("search") then
            -- Live grep
            require("telescope.builtin").live_grep({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Live Grep (" .. scope_name .. ")",
            })
          elseif lower_title:match("find") or lower_title:match("files") or
             (finder.results_title and finder.results_title:match("[Ff]iles")) then
            -- File finder - check this after more specific patterns
            require("telescope.builtin").find_files({
              cwd = new_cwd,
              hidden = true,
              no_ignore = false,
              follow = true,
              default_text = prompt,
              prompt_title = "Find Files (" .. scope_name .. ")",
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
        local git_root = get_service_repo_dir()
        local repo_name = vim.fn.fnamemodify(git_root, ":t")
        change_scope(prompt_bufnr, git_root, "Git: " .. repo_name)
      end

      opts.defaults.mappings.i["<M-l>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_local_dir(), "Local")
      end

      opts.defaults.mappings.i["<M-d>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_buffer_dir(), "Buffer Dir")
      end

      opts.defaults.mappings.i["<M-p>"] = function(prompt_bufnr)
        local parent = get_parent_dir(prompt_bufnr)
        if parent then
          local parent_name = vim.fn.fnamemodify(parent, ":t")
          change_scope(prompt_bufnr, parent, "Parent: " .. parent_name)
        end
      end

      -- Add scope toggle mappings for normal mode (Alt-based)
      opts.defaults.mappings.n["<M-g>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, vim.fn.expand("~/work"), "Global")
      end

      opts.defaults.mappings.n["<M-s>"] = function(prompt_bufnr)
        local git_root = get_service_repo_dir()
        local repo_name = vim.fn.fnamemodify(git_root, ":t")
        change_scope(prompt_bufnr, git_root, "Git: " .. repo_name)
      end

      opts.defaults.mappings.n["<M-l>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_local_dir(), "Local")
      end

      opts.defaults.mappings.n["<M-d>"] = function(prompt_bufnr)
        change_scope(prompt_bufnr, get_buffer_dir(), "Buffer Dir")
      end

      opts.defaults.mappings.n["<M-p>"] = function(prompt_bufnr)
        local parent = get_parent_dir(prompt_bufnr)
        if parent then
          local parent_name = vim.fn.fnamemodify(parent, ":t")
          change_scope(prompt_bufnr, parent, "Parent: " .. parent_name)
        end
      end

      return opts
    end,
  },
}
