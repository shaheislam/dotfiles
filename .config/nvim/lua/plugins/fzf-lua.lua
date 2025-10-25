-- Consolidated fzf-lua configuration
-- Replaces telescope.nvim with feature parity for all custom workflows

-- State management for scope toggle and directory history
local original_bufnr = nil
local dir_history = {}
local history_index = 0

return {
  -- fzf-lua main plugin
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },

    opts = function()
      local actions = require("fzf-lua.actions")

      -- ===== Helper Functions for Scope Toggle =====

      local function get_service_repo_dir()
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local ft = vim.api.nvim_buf_get_option(original_bufnr, "filetype")
          if ft == "oil" then
            local oil_dir = require("oil").get_current_dir(original_bufnr)
            if oil_dir then
              local git_root = vim.fs.find(".git", { path = oil_dir, upward = true })[1]
              if git_root then
                return vim.fn.fnamemodify(git_root, ":h")
              end
            end
          end
        end
        return LazyVim.root.git()
      end

      local function get_local_dir()
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local ft = vim.api.nvim_buf_get_option(original_bufnr, "filetype")
          if ft == "oil" then
            local oil_dir = require("oil").get_current_dir(original_bufnr)
            if oil_dir then
              return oil_dir
            end
          end
        end
        return vim.fn.getcwd()
      end

      local function get_buffer_dir()
        if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
          local bufname = vim.api.nvim_buf_get_name(original_bufnr)
          if bufname and bufname ~= "" then
            local dir = vim.fn.fnamemodify(bufname, ":h")
            if dir and dir ~= "" then
              return dir
            end
          end
        end
        return vim.fn.getcwd()
      end

      local function get_parent_dir(cwd)
        local parent = vim.fn.fnamemodify(cwd or vim.fn.getcwd(), ":h")
        if parent == cwd or parent == "" or parent == "." then
          vim.notify("Already at filesystem root", vim.log.levels.WARN)
          return nil
        end
        return parent
      end

      local function add_to_history(cwd, scope_name)
        if history_index > 0 and dir_history[history_index] then
          if dir_history[history_index].cwd == cwd then
            return
          end
        end

        for i = history_index + 1, #dir_history do
          dir_history[i] = nil
        end

        table.insert(dir_history, { cwd = cwd, scope_name = scope_name })
        history_index = #dir_history
      end

      -- ===== Scope Change Actions =====

      local function create_scope_action(new_cwd_fn, scope_name)
        return function(_, opts)
          local new_cwd = new_cwd_fn(opts)
          if not new_cwd then return end

          -- Initialize history on first scope change
          if #dir_history == 0 then
            local current_cwd = opts.cwd or vim.fn.getcwd()
            add_to_history(current_cwd, "Initial")
          end

          add_to_history(new_cwd, scope_name)

          -- Determine picker type from prompt
          local prompt = opts.prompt or ""
          local query = opts.__call_opts and opts.__call_opts.query or ""

          -- Relaunch appropriate picker with new scope
          vim.schedule(function()
            if prompt:match("Buffers") then
              require("fzf-lua").buffers({
                query = query,
                prompt = "Buffers (" .. scope_name .. ")> "
              })
            elseif prompt:match("Oldfiles") or prompt:match("Recent") then
              require("fzf-lua").oldfiles({
                cwd = new_cwd,
                query = query,
                prompt = "Recent Files (" .. scope_name .. ")> "
              })
            elseif prompt:match("Grep") or prompt:match("RG") then
              local cwd_full = vim.fn.fnamemodify(new_cwd, ":~")
              require("fzf-lua").live_grep({
                cwd = new_cwd,
                query = query,
                prompt = "Live Grep> ",
                fzf_opts = { ["--header"] = "📁 " .. cwd_full }
              })
            else
              require("fzf-lua").files({
                cwd = new_cwd,
                query = query,
                prompt = "Find Files (" .. scope_name .. ")> "
              })
            end
          end)
        end
      end

      -- History navigation actions
      local function navigate_history(direction)
        return function(_, opts)
          if #dir_history == 0 then
            vim.notify("No directory history", vim.log.levels.WARN)
            return
          end

          local new_index = history_index + direction
          if new_index < 1 or new_index > #dir_history then
            vim.notify("At " .. (direction < 0 and "oldest" or "newest") .. " directory in history", vim.log.levels.WARN)
            return
          end

          history_index = new_index
          local entry = dir_history[history_index]

          -- Relaunch picker without adding to history
          local prompt = opts.prompt or ""
          local query = opts.__call_opts and opts.__call_opts.query or ""

          vim.schedule(function()
            if prompt:match("Buffers") then
              require("fzf-lua").buffers({
                query = query,
                prompt = "Buffers (" .. entry.scope_name .. ")> "
              })
            elseif prompt:match("Oldfiles") or prompt:match("Recent") then
              require("fzf-lua").oldfiles({
                cwd = entry.cwd,
                query = query,
                prompt = "Recent Files (" .. entry.scope_name .. ")> "
              })
            elseif prompt:match("Grep") or prompt:match("RG") then
              local cwd_full = vim.fn.fnamemodify(entry.cwd, ":~")
              require("fzf-lua").live_grep({
                cwd = entry.cwd,
                query = query,
                prompt = "Live Grep> ",
                fzf_opts = { ["--header"] = "📁 " .. cwd_full }
              })
            else
              require("fzf-lua").files({
                cwd = entry.cwd,
                query = query,
                prompt = "Find Files (" .. entry.scope_name .. ")> "
              })
            end
          end)
        end
      end

      -- Recursive folder browser using official fzf_exec pattern
      local function browse_folders(cwd, original_prompt, original_query, initial_call)
        local fzf_lua = require("fzf-lua")

        -- Initialize history on first call
        if initial_call and #dir_history == 0 then
          add_to_history(cwd, "Initial")
        end

        -- Build fd command with exclusions
        local fd_cmd = "fd --type d --exclude .git/objects --exclude .git/refs --exclude node_modules"

        fzf_lua.fzf_exec(fd_cmd, {
          prompt = "Select Directory> ",
          cwd = cwd,
          actions = {
            ["default"] = function(selected)
              -- Enter: Navigate into selected folder (recursive)
              if not selected or #selected == 0 then return end
              -- selected[1] is clean path relative to cwd
              local selected_dir = selected[1]
              local abs_dir = vim.fn.fnamemodify(cwd .. "/" .. selected_dir, ":p")

              -- Add to history when navigating into a directory
              add_to_history(abs_dir, "Browse")

              vim.schedule(function()
                browse_folders(abs_dir, original_prompt, original_query)
              end)
            end,
            ["ctrl-x"] = function(selected)
              -- Ctrl-x: Exit folder browser and open files/grep in selected directory
              if not selected or #selected == 0 then return end
              local selected_dir = selected[1]
              local abs_dir = vim.fn.fnamemodify(cwd .. "/" .. selected_dir, ":p")

              vim.schedule(function()
                local cwd_full = vim.fn.fnamemodify(abs_dir, ":~")
                if original_prompt:match("Grep") or original_prompt:match("RG") then
                  fzf_lua.live_grep({
                    cwd = abs_dir,
                    query = original_query,
                    prompt = "Live Grep> ",
                    fzf_opts = { ["--header"] = "📁 " .. cwd_full }
                  })
                else
                  fzf_lua.files({
                    cwd = abs_dir,
                    query = original_query,
                    prompt = "Find Files> ",
                    fzf_opts = { ["--header"] = "📁 " .. cwd_full }
                  })
                end
              end)
            end,
            ["alt-b"] = function()
              -- Navigate back in history
              if #dir_history == 0 then
                vim.notify("No directory history", vim.log.levels.WARN)
                return
              end

              if history_index > 1 then
                history_index = history_index - 1
                local entry = dir_history[history_index]

                vim.schedule(function()
                  browse_folders(entry.cwd, original_prompt, original_query)
                end)
              else
                vim.notify("At oldest directory in history", vim.log.levels.WARN)
              end
            end,
            ["alt-f"] = function()
              -- Navigate forward in history
              if #dir_history == 0 then
                vim.notify("No directory history", vim.log.levels.WARN)
                return
              end

              if history_index < #dir_history then
                history_index = history_index + 1
                local entry = dir_history[history_index]

                vim.schedule(function()
                  browse_folders(entry.cwd, original_prompt, original_query)
                end)
              else
                vim.notify("At newest directory in history", vim.log.levels.WARN)
              end
            end,
            ["alt-p"] = function()
              -- Navigate to parent directory
              local parent = vim.fn.fnamemodify(cwd, ":h")
              if parent == cwd or parent == "" or parent == "." then
                vim.notify("Already at filesystem root", vim.log.levels.WARN)
                return
              end

              -- Add parent to history
              add_to_history(parent, "Parent")

              vim.schedule(function()
                browse_folders(parent, original_prompt, original_query)
              end)
            end
          }
        })
      end

      -- Directory selector action (now <M-o>)
      local function select_directory()
        return function(_, opts)
          local query = opts.__call_opts and opts.__call_opts.query or ""
          local current_picker_prompt = opts.prompt or ""
          local current_cwd = opts.cwd or vim.fn.getcwd()

          browse_folders(current_cwd, current_picker_prompt, query, true)
        end
      end

      -- ===== Main Configuration =====

      return {
        -- Global options
        global_resume = true,
        global_resume_query = true,

        -- Global keymaps for fzf
        keymap = {
          fzf = {
            ["ctrl-f"] = "preview-up",        -- Scroll up (line by line)
            ["ctrl-d"] = "preview-down",      -- Scroll down (line by line)
            ["ctrl-b"] = "preview-page-up",   -- Page up
            -- ["ctrl-u"] is now free for other uses
          },
        },

        winopts = {
          height = 0.85,
          width = 0.85,
          row = 0.35,
          col = 0.50,
          border = "rounded",
          preview = {
            layout = "horizontal",
            horizontal = "right:60%",
            scrollbar = "float",
          },
          on_create = function()
            -- Set up Tab key to toggle focus between search and preview only
            -- Get the FzfWin instance to access window IDs
            local win = require("fzf-lua.win")

            -- In terminal mode (fzf search buffer)
            vim.keymap.set("t", "<Tab>", function()
              local self = win.__SELF()
              if self and self.preview_winid and vim.api.nvim_win_is_valid(self.preview_winid) then
                vim.cmd("stopinsert")  -- Exit insert mode in terminal
                vim.api.nvim_set_current_win(self.preview_winid)  -- Switch directly to preview
              end
            end, { buffer = true, silent = true })

            -- Set up Tab in normal mode for preview window
            -- This gets applied when we switch to the preview buffer
            vim.api.nvim_create_autocmd("WinEnter", {
              callback = function()
                local self = win.__SELF()
                if not self then return end

                local current_win = vim.api.nvim_get_current_win()
                -- Check if we're in the preview window
                if self.preview_winid and current_win == self.preview_winid then
                  vim.keymap.set("n", "<Tab>", function()
                    if self.fzf_winid and vim.api.nvim_win_is_valid(self.fzf_winid) then
                      vim.api.nvim_set_current_win(self.fzf_winid)  -- Switch directly to search
                      vim.cmd("startinsert")  -- Re-enter insert mode in terminal
                    end
                  end, { buffer = vim.api.nvim_win_get_buf(current_win), silent = true })
                end
              end,
            })
          end,
        },

        -- File ignore patterns (matching telescope config)
        files = {
          prompt = "Find Files> ",
          fd_opts = "--color=never --type f --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude '*.lock' --exclude package-lock.json --exclude yarn.lock --exclude '*.log' --exclude '*.cache' --exclude '*.min.js' --exclude '*.min.css'",
          actions = {
            ["alt-g"] = create_scope_action(function() return vim.fn.expand("~/work") end, "Global"),
            ["alt-s"] = create_scope_action(function()
              local git_root = get_service_repo_dir()
              local repo_name = vim.fn.fnamemodify(git_root, ":t")
              return git_root
            end, "Git"),
            ["alt-l"] = create_scope_action(get_local_dir, "Local"),
            ["alt-d"] = create_scope_action(get_buffer_dir, "Buffer Dir"),
            ["alt-p"] = create_scope_action(function(opts)
              return get_parent_dir(opts.cwd)
            end, "Parent"),
            ["alt-b"] = navigate_history(-1),
            ["alt-n"] = navigate_history(1),
            ["alt-o"] = select_directory(),
          },
        },

        -- Live grep with advanced ripgrep support
        grep = {
          prompt = "Live Grep> ",
          input_prompt = "Grep For> ",
          rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --hidden --glob '!.git/*' --glob '!node_modules/*' --glob '!dist/*' --glob '!*.lock' --glob '!*.log' --glob '!*.cache' --glob '!*.min.js' --glob '!*.min.css'",
          actions = {
            ["alt-g"] = create_scope_action(function() return vim.fn.expand("~/work") end, "Global"),
            ["alt-s"] = create_scope_action(function()
              local git_root = get_service_repo_dir()
              local repo_name = vim.fn.fnamemodify(git_root, ":t")
              return git_root
            end, "Git"),
            ["alt-l"] = create_scope_action(get_local_dir, "Local"),
            ["alt-d"] = create_scope_action(get_buffer_dir, "Buffer Dir"),
            ["alt-p"] = create_scope_action(function(opts)
              return get_parent_dir(opts.cwd)
            end, "Parent"),
            ["alt-b"] = navigate_history(-1),
            ["alt-n"] = navigate_history(1),
            ["alt-o"] = select_directory(),
            -- Advanced grep controls
            ["ctrl-g"] = { actions.grep_lgrep },
            ["ctrl-r"] = { actions.toggle_ignore },
            ["ctrl-h"] = { actions.toggle_hidden },
          },
          -- Enable interactive ripgrep mode
          rg_glob = true,
          glob_flag = "--iglob",
          glob_separator = "%s%-%-",
        },

        -- Buffers
        buffers = {
          prompt = "Buffers> ",
          sort_mru = true,
          sort_lastused = true,
          show_all_buffers = true,
          actions = {
            ["alt-g"] = create_scope_action(function() return vim.fn.expand("~/work") end, "Global"),
            ["alt-s"] = create_scope_action(function()
              local git_root = get_service_repo_dir()
              return git_root
            end, "Git"),
            ["alt-l"] = create_scope_action(get_local_dir, "Local"),
            ["alt-d"] = create_scope_action(get_buffer_dir, "Buffer Dir"),
            ["alt-b"] = navigate_history(-1),
            ["alt-n"] = navigate_history(1),
            ["ctrl-d"] = { actions.buf_del, actions.resume },
          },
        },

        -- Oldfiles (Recent Files)
        oldfiles = {
          prompt = "Recent Files> ",
          cwd_only = false,
          include_current_session = true,
          actions = {
            ["alt-g"] = create_scope_action(function() return vim.fn.expand("~/work") end, "Global"),
            ["alt-s"] = create_scope_action(function()
              local git_root = get_service_repo_dir()
              return git_root
            end, "Git"),
            ["alt-l"] = create_scope_action(get_local_dir, "Local"),
            ["alt-d"] = create_scope_action(get_buffer_dir, "Buffer Dir"),
            ["alt-p"] = create_scope_action(function(opts)
              return get_parent_dir(opts.cwd)
            end, "Parent"),
            ["alt-b"] = navigate_history(-1),
            ["alt-n"] = navigate_history(1),
          },
        },

        -- Git integration
        git = {
          files = {
            prompt = "Git Files> ",
          },
          commits = {
            prompt = "Git Commits> ",
            preview = "git show --color {1}",
            actions = {
              ["default"] = actions.git_checkout,
            },
          },
          bcommits = {
            prompt = "Git Buffer Commits> ",
            preview = "git show --color {1}",
            actions = {
              ["default"] = actions.git_buf_edit,
            },
          },
          branches = {
            prompt = "Git Branches> ",
            preview = "git log --graph --pretty=oneline --abbrev-commit --color {1}",
            actions = {
              ["default"] = function(selected)
                if not selected or #selected == 0 then return end

                local branch = selected[1]:match("^[^%s]+")
                if not branch then return end

                -- Check for uncommitted changes
                local has_changes = vim.fn.system("bash -c 'git status --porcelain'"):match("%S")

                if has_changes then
                  local choice = vim.fn.confirm(
                    "You have uncommitted changes. What would you like to do?",
                    "&Stash and switch\n&Cancel",
                    1
                  )

                  if choice == 1 then
                    -- Stash changes with descriptive message
                    local stash_msg = string.format(
                      "WIP on %s before switching to %s",
                      vim.fn.system("bash -c 'git branch --show-current'"):gsub("\n", ""),
                      branch
                    )
                    vim.fn.system(string.format("bash -c \"git stash push -m '%s'\"", stash_msg))
                    vim.notify("Changes stashed: " .. stash_msg, vim.log.levels.INFO)

                    -- Switch branch
                    local result = vim.fn.system(string.format("bash -c 'git checkout %s'", branch))
                    if vim.v.shell_error == 0 then
                      vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                    else
                      vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                    end
                  end
                else
                  -- No changes, switch directly
                  local result = vim.fn.system(string.format("bash -c 'git checkout %s'", branch))
                  if vim.v.shell_error == 0 then
                    vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to switch branch: " .. result, vim.log.levels.ERROR)
                  end
                end
              end,
            },
          },
          stash = {
            prompt = "Git Stash> ",
            preview = "git stash show --color -p {1}",
            actions = {
              ["default"] = actions.git_stash_apply,
              ["ctrl-x"] = actions.git_stash_drop,
            },
          },
        },

        -- LSP integration
        lsp = {
          symbols = {
            symbol_style = 1,
          },
        },
      }
    end,

    config = function(_, opts)
      -- Store original buffer on picker launch
      local fzf = require("fzf-lua")
      local original_fns = {}

      -- Wrap all picker functions to capture original buffer
      for name, fn in pairs(fzf) do
        if type(fn) == "function" and not name:match("^_") then
          original_fns[name] = fn
          fzf[name] = function(...)
            original_bufnr = vim.api.nvim_get_current_buf()
            return original_fns[name](...)
          end
        end
      end

      -- Apply configuration
      fzf.setup(opts)

      -- Register as LazyVim picker
      if LazyVim and LazyVim.pick then
        LazyVim.pick.register({
          name = "fzf-lua",
          commands = {
            files = "files",
            live_grep = "live_grep",
            buffers = "buffers",
            oldfiles = "oldfiles",
            git_files = "git_files",
          },
        })
      end
    end,

    keys = {
      -- File pickers
      { "<leader>ff", function() require("fzf-lua").files() end, desc = "Find Files" },
      { "<leader>fF", function() require("fzf-lua").files({ cwd = vim.fn.expand("~") }) end, desc = "Find Files (Home)" },

      -- Buffer pickers
      { "<leader>fb", function() require("fzf-lua").buffers({ prompt = "Buffers (Local)> " }) end, desc = "Buffers (with scope toggle)" },
      { "<leader>fB", function() require("fzf-lua").buffers({ prompt = "All Buffers> ", show_all_buffers = true }) end, desc = "All Buffers" },

      -- Recent files pickers
      {
        "<leader>fr",
        function()
          local cwd = vim.fn.getcwd()
          if vim.bo.filetype == "oil" then
            local oil_dir = require("oil").get_current_dir()
            if oil_dir then
              cwd = oil_dir
            end
          end
          require("fzf-lua").oldfiles({ cwd = cwd, prompt = "Recent Files (Local)> " })
        end,
        desc = "Recent Files (with scope toggle)"
      },
      { "<leader>fR", function() require("fzf-lua").oldfiles({ prompt = "Recent Files (Global)> " }) end, desc = "Recent Files (Global)" },

      -- Grep pickers
      { "<leader>fg", function()
        local cwd = vim.fn.getcwd()
        local cwd_full = vim.fn.fnamemodify(cwd, ":~")
        require("fzf-lua").live_grep({
          prompt = "Live Grep> ",
          fzf_opts = { ["--header"] = "📁 " .. cwd_full },
          resume = false  -- Force fresh session with current directory
        })
      end, desc = "Live Grep with Args" },
      { "<leader>fG", function() require("fzf-lua").live_grep({ rg_opts = "--column --line-number --no-heading --color=always --smart-case --glob '!*test*' --glob '!*spec*' --glob '!*.min.*'" }) end, desc = "Live Grep (No Tests)" },
      { "<leader>fw", function() require("fzf-lua").grep_cword() end, desc = "Grep word under cursor" },
      { "<leader>fW", function() require("fzf-lua").grep_cWORD() end, desc = "Grep WORD under cursor" },
      { "<leader>fv", function() require("fzf-lua").grep_visual() end, mode = "v", desc = "Grep visual selection" },

      -- Git pickers
      { "<leader>gC", function() require("fzf-lua").git_bcommits() end, desc = "Git buffer commits" },
      { "<leader>gb", function() require("fzf-lua").git_branches() end, desc = "Git branches (with stash)" },
      { "<leader>gs", function() require("fzf-lua").git_stash() end, desc = "Git stash" },

      -- Undo history
      { "<leader>fu", function() require("fzf-lua").changes() end, desc = "Undo History" },

      -- Marks
      { "<leader>fm", function() require("fzf-lua").marks() end, desc = "Find marks" },

      -- Help and commands
      { "<leader>fh", function() require("fzf-lua").help_tags() end, desc = "Help Tags" },
      { "<leader>fc", function() require("fzf-lua").commands() end, desc = "Commands" },

      -- Resume last picker
      { "<leader>f<leader>", function() require("fzf-lua").resume() end, desc = "Resume last picker" },

      -- FZF-Lua builtin picker (enhanced with advanced-git-search)
      {
        "<leader>fz",
        function()
          local fzf = require("fzf-lua")

          -- fzf-lua native pickers
          local fzf_pickers = {
            "files", "git_files", "oldfiles", "buffers",
            "live_grep", "grep_cword", "grep_cWORD", "grep_visual",
            "git_commits", "git_bcommits", "git_branches", "git_status", "git_stash",
            "lsp_references", "lsp_definitions", "lsp_declarations", "lsp_typedefs",
            "lsp_implementations", "lsp_document_symbols", "lsp_workspace_symbols",
            "diagnostics_document", "diagnostics_workspace",
            "commands", "command_history", "search_history",
            "marks", "jumps", "changes", "registers",
            "help_tags", "man_pages", "colorschemes",
            "keymaps", "filetypes", "highlights",
          }

          -- advanced-git-search operations (only if plugin is installed)
          local advanced_git = {
            "AdvancedGitSearch search_log_content",
            "AdvancedGitSearch search_log_content_file",
            "AdvancedGitSearch diff_commit_line",
            "AdvancedGitSearch diff_commit_file",
            "AdvancedGitSearch diff_branch_file",
            "AdvancedGitSearch checkout_reflog",
          }

          -- Combine lists
          local all_pickers = vim.list_extend(vim.deepcopy(fzf_pickers), advanced_git)

          fzf.fzf_exec(all_pickers, {
            prompt = "FZF-Lua Pickers> ",
            actions = {
              ["default"] = function(selected)
                if not selected or #selected == 0 then return end
                local picker = selected[1]

                -- Check if it's an AdvancedGitSearch command
                if picker:match("^AdvancedGitSearch") then
                  vim.cmd(picker)
                else
                  -- It's an fzf-lua native picker
                  if fzf[picker] then
                    fzf[picker]()
                  else
                    vim.notify("Picker not found: " .. picker, vim.log.levels.WARN)
                  end
                end
              end
            }
          })
        end,
        desc = "FZF-Lua Builtin Pickers (Enhanced)"
      },
    },
  },

  -- Zoxide integration with Oil.nvim
  -- Note: fzf-lua has built-in zoxide support, but we keep this for Oil integration
  {
    "nanotee/zoxide.vim",
    dependencies = { "ibhagwan/fzf-lua", "stevearc/oil.nvim" },
    keys = {
      {
        "<leader>cd",
        function()
          -- Use fzf-lua's built-in zoxide picker
          require("fzf-lua").zoxide({
            prompt = "Zoxide> ",
            actions = {
              ["default"] = function(selected)
                if not selected or #selected == 0 then return end
                local dir = selected[1]:match("^[^%s]+") or selected[1]
                -- Change working directory
                vim.cmd("cd " .. vim.fn.fnameescape(dir))
                -- Open oil in that directory
                require("oil").open(dir)
              end
            }
          })
        end,
        desc = "Zoxide jump to Oil"
      },
    },
  },

  -- Project management with fzf-lua integration
  {
    "ahmedkhalf/project.nvim",
    opts = {
      manual_mode = false,
      detection_methods = { "lsp", "pattern" },
      patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", "Cargo.toml" },
      show_hidden = false,
      silent_chdir = true,
    },
    event = "VeryLazy",
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
    keys = {
      {
        "<leader>fp",
        function()
          -- Use fzf-lua for project selection
          local project_nvim = require("project_nvim")
          local history = require("project_nvim.utils.history")
          local projects = history.get_recent_projects()

          require("fzf-lua").fzf_exec(projects, {
            prompt = "Projects> ",
            actions = {
              ["default"] = function(selected)
                if not selected or #selected == 0 then return end
                local project_path = selected[1]
                vim.cmd("cd " .. vim.fn.fnameescape(project_path))
                vim.notify("Changed to project: " .. project_path, vim.log.levels.INFO)
              end
            }
          })
        end,
        desc = "Projects"
      },
    },
  },
}
