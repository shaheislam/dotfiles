-- Consolidated Telescope configuration
-- Combines all telescope extensions and configurations in one place
-- to avoid timing/ordering issues and double-setup problems

-- Store the original buffer number and directory history for scope toggles
local original_bufnr = nil
local dir_history = {}
local history_index = 0

return {
  -- Treesitter compatibility patch (must load first)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      -- Patch nvim-treesitter modules for Telescope compatibility
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          -- Patch parsers module with ft_to_lang and get_parser
          local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
          if has_parsers then
            -- Add ft_to_lang if missing
            if not parsers.ft_to_lang then
              parsers.ft_to_lang = function(ft)
                local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
                if ok and lang then
                  return lang
                end

                local ft_map = {
                  javascriptreact = "tsx",
                  typescriptreact = "tsx",
                  sh = "bash",
                  zsh = "bash",
                }
                return ft_map[ft] or ft
              end
            end

            -- Add get_parser if missing
            if not parsers.get_parser then
              parsers.get_parser = function(bufnr, lang)
                local ok1, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
                if ok1 and parser then
                  return parser
                end

                pcall(vim.treesitter.start, bufnr, lang)
                local ok4, final_parser = pcall(vim.treesitter.get_parser, bufnr)
                if ok4 and final_parser then
                  return final_parser
                end

                return {
                  parse = function() return {} end,
                  trees = function() return {} end,
                  source = function() return bufnr end,
                  lang = function() return lang end,
                  _callbacks = {},
                }
              end
            end
          end

          -- Create/patch configs module
          local configs_module = {
            is_enabled = function(_, _, _)
              return true
            end,
            get_module = function(module_name)
              if module_name == "highlight" then
                return {
                  enable = true,
                  additional_vim_regex_highlighting = false,
                }
              end
              return {}
            end,
          }

          package.loaded["nvim-treesitter.configs"] = configs_module
        end,
        desc = "Patch nvim-treesitter for Telescope compatibility",
      })
    end,
  },

  -- Extension dependencies
  {
    "debugloop/telescope-undo.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
  },
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
  },
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  },

  -- Main Telescope configuration
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "debugloop/telescope-undo.nvim",
      "nvim-telescope/telescope-live-grep-args.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },

    opts = function(_, opts)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      -- ===== Scope Toggle Setup =====
      -- Store original buffer for scope toggle functionality
      local telescope_builtin = require("telescope.builtin")
      local original_builtin = {}

      for name, func in pairs(telescope_builtin) do
        original_builtin[name] = func
        telescope_builtin[name] = function(opts_inner)
          original_bufnr = vim.api.nvim_get_current_buf()
          return original_builtin[name](opts_inner)
        end
      end

      -- Scope toggle helper functions
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

      local function get_parent_dir(prompt_bufnr)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local current_cwd = (current_picker.finder and current_picker.finder.cwd)
                         or current_picker.cwd
                         or vim.fn.getcwd()

        local parent = vim.fn.fnamemodify(current_cwd, ":h")
        if parent == current_cwd or parent == "" or parent == "." then
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

      local function change_scope(prompt_bufnr, new_cwd, scope_name, skip_history)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local finder = current_picker.finder
        local prompt = action_state.get_current_line()
        local original_title = current_picker.prompt_title or ""

        if not skip_history then
          if #dir_history == 0 then
            local current_cwd = (finder and finder.cwd) or current_picker.cwd or vim.fn.getcwd()
            local current_scope = original_title:match("%((.-)%)") or "Initial"
            add_to_history(current_cwd, current_scope)
          end
          add_to_history(new_cwd, scope_name)
        end

        actions.close(prompt_bufnr)

        vim.schedule(function()
          local lower_title = original_title:lower()

          if lower_title:match("recent") or lower_title:match("oldfiles") then
            require("telescope.builtin").oldfiles({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Recent Files (" .. scope_name .. ")",
            })
          elseif lower_title:match("buffer") then
            require("telescope.builtin").buffers({
              default_text = prompt,
              prompt_title = "Buffers (" .. scope_name .. ")",
            })
          elseif lower_title:match("grep") or lower_title:match("search") then
            require("telescope.builtin").live_grep({
              cwd = new_cwd,
              default_text = prompt,
              prompt_title = "Live Grep (" .. scope_name .. ")",
            })
          else
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

      local function navigate_history(prompt_bufnr, direction)
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
        change_scope(prompt_bufnr, entry.cwd, entry.scope_name, true)
      end

      -- File browser directory selector helper
      local function select_dir_for_action(picker_fn, picker_opts)
        return function(prompt_bufnr)
          local fb = require("telescope").extensions.file_browser
          local current_line = action_state.get_current_line()

          fb.file_browser({
            files = false,
            depth = false,
            attach_mappings = function(prompt_bufnr)
              actions.select_default:replace(function()
                local entry_path = action_state.get_selected_entry().Path
                local dir = entry_path:is_dir() and entry_path or entry_path:parent()
                local relative = dir:make_relative(vim.fn.getcwd())
                local absolute = dir:absolute()

                local opts = vim.tbl_extend("force", {
                  results_title = relative .. "/",
                  cwd = absolute,
                  default_text = current_line,
                }, picker_opts or {})

                picker_fn(opts)
              end)
              return true
            end,
          })
        end
      end

      -- ===== Merge All Configurations =====
      return vim.tbl_deep_extend("force", opts, {
        defaults = {
          default_text = "",  -- Prevent picking up vim's search register
          file_ignore_patterns = {
            "node_modules", "^.git/", "dist", "/build/", "%.lock", "package%-lock%.json",
            "yarn%.lock", "%.log", "%.cache", "%.min%.js", "%.min%.css"
          },
          layout_config = {
            horizontal = { preview_width = 0.6 },
          },
          mappings = {
            i = {
              -- Scope toggle mappings
              ["<M-g>"] = function(pb) change_scope(pb, vim.fn.expand("~/work"), "Global") end,
              ["<M-s>"] = function(pb)
                local git_root = get_service_repo_dir()
                local repo_name = vim.fn.fnamemodify(git_root, ":t")
                change_scope(pb, git_root, "Git: " .. repo_name)
              end,
              ["<M-l>"] = function(pb) change_scope(pb, get_local_dir(), "Local") end,
              ["<M-d>"] = function(pb) change_scope(pb, get_buffer_dir(), "Buffer Dir") end,
              ["<M-p>"] = function(pb)
                local parent = get_parent_dir(pb)
                if parent then
                  local parent_name = vim.fn.fnamemodify(parent, ":t")
                  change_scope(pb, parent, "Parent: " .. parent_name)
                end
              end,
              ["<M-b>"] = function(pb) navigate_history(pb, -1) end,
              ["<M-n>"] = function(pb) navigate_history(pb, 1) end,
            },
            n = {
              -- Scope toggle mappings (normal mode)
              ["<M-g>"] = function(pb) change_scope(pb, vim.fn.expand("~/work"), "Global") end,
              ["<M-s>"] = function(pb)
                local git_root = get_service_repo_dir()
                local repo_name = vim.fn.fnamemodify(git_root, ":t")
                change_scope(pb, git_root, "Git: " .. repo_name)
              end,
              ["<M-l>"] = function(pb) change_scope(pb, get_local_dir(), "Local") end,
              ["<M-d>"] = function(pb) change_scope(pb, get_buffer_dir(), "Buffer Dir") end,
              ["<M-p>"] = function(pb)
                local parent = get_parent_dir(pb)
                if parent then
                  local parent_name = vim.fn.fnamemodify(parent, ":t")
                  change_scope(pb, parent, "Parent: " .. parent_name)
                end
              end,
              ["<M-b>"] = function(pb) navigate_history(pb, -1) end,
              ["<M-n>"] = function(pb) navigate_history(pb, 1) end,
            },
          },
        },
        pickers = {
          -- Add <M-f> directory scoping to built-in pickers
          live_grep = {
            mappings = {
              i = { ["<M-f>"] = select_dir_for_action(telescope_builtin.live_grep) },
              n = { ["<M-f>"] = select_dir_for_action(telescope_builtin.live_grep) },
            },
          },
          find_files = {
            mappings = {
              i = { ["<M-f>"] = select_dir_for_action(telescope_builtin.find_files, { hidden = true }) },
              n = { ["<M-f>"] = select_dir_for_action(telescope_builtin.find_files, { hidden = true }) },
            },
          },
        },
        extensions = {
          -- Telescope-undo extension
          undo = {
            use_delta = true,
            side_by_side = false,
            layout_strategy = "horizontal",
            layout_config = {
              width = 0.9,
              height = 0.9,
              preview_width = 0.6,
            },
            mappings = {
              i = {
                ["<cr>"] = function(bufnr)
                  return require("telescope-undo.actions").restore(bufnr)
                end,
                ["<C-y>"] = function(bufnr)
                  return require("telescope-undo.actions").yank_additions(bufnr)
                end,
                ["<C-Y>"] = function(bufnr)
                  return require("telescope-undo.actions").yank_deletions(bufnr)
                end,
              },
              n = {
                ["<cr>"] = function(bufnr)
                  return require("telescope-undo.actions").restore(bufnr)
                end,
                ["y"] = function(bufnr)
                  return require("telescope-undo.actions").yank_additions(bufnr)
                end,
                ["Y"] = function(bufnr)
                  return require("telescope-undo.actions").yank_deletions(bufnr)
                end,
              },
            },
          },

          -- Live grep args extension
          live_grep_args = {
            auto_quoting = true,
            mappings = {
              i = {
                ["<C-k>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt()(bufnr)
                end,
                ["<C-g>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --glob " })(bufnr)
                end,
                ["<C-i>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " })(bufnr)
                end,
                ["<C-t>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --type " })(bufnr)
                end,
                ["<C-h>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --hidden " })(bufnr)
                end,
                -- Add <M-f> directory scoping to live_grep_args
                ["<M-f>"] = select_dir_for_action(function(opts)
                  require("telescope").extensions.live_grep_args.live_grep_args(opts)
                end),
              },
              n = {
                ["<C-k>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt()(bufnr)
                end,
                ["<C-g>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --glob " })(bufnr)
                end,
                ["<C-i>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " })(bufnr)
                end,
                ["<C-t>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --type " })(bufnr)
                end,
                ["<C-h>"] = function(bufnr)
                  return require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --hidden " })(bufnr)
                end,
                ["<M-f>"] = select_dir_for_action(function(opts)
                  require("telescope").extensions.live_grep_args.live_grep_args(opts)
                end),
              },
            },
          },

          -- File browser extension
          file_browser = {
            theme = nil,
            hijack_netrw = false,
            layout_strategy = "horizontal",
            layout_config = {
              horizontal = {
                preview_width = 0.6,
                preview_cutoff = 120,
              },
              width = 0.9,
              height = 0.9,
            },
          },
        },
      })
    end,

    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)

      -- Load all extensions
      telescope.load_extension("undo")
      telescope.load_extension("live_grep_args")
      telescope.load_extension("file_browser")
    end,

    keys = {
      -- General telescope keymaps
      {
        "<leader>ff",
        function()
          require("telescope.builtin").find_files({
            hidden = true,
            no_ignore = false,
            follow = true,
          })
        end,
        desc = "Find Files (Custom)",
      },
      { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Find marks" },

      -- Buffer keymaps (override Snacks picker)
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers({
            prompt_title = "Buffers (Local)",
            sort_mru = true,
            sort_lastused = true,
            ignore_current_buffer = false,
            show_all_buffers = true,
          })
        end,
        desc = "Buffers (with scope toggle)",
      },
      {
        "<leader>fB",
        function()
          require("telescope.builtin").buffers({
            prompt_title = "All Buffers",
            sort_mru = true,
            sort_lastused = true,
            ignore_current_buffer = false,
            show_all_buffers = true,
            bufnr_width = 3,
          })
        end,
        desc = "All Buffers (inc. hidden)",
      },

      -- Recent files keymaps (override Snacks picker)
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

          require("telescope.builtin").oldfiles({
            cwd = cwd,
            prompt_title = "Recent Files (Local)",
            only_cwd = false,
          })
        end,
        desc = "Recent Files (with scope toggle)",
      },
      {
        "<leader>fR",
        function()
          require("telescope.builtin").oldfiles({
            prompt_title = "Recent Files (Global)",
            only_cwd = false,
          })
        end,
        desc = "Recent Files (Global)",
      },

      -- Telescope-undo keymaps
      {
        "<leader>fu",
        "<cmd>Telescope undo<cr>",
        desc = "Undo History",
      },

      -- Live grep args keymaps
      {
        "<leader>fg",
        function()
          require("telescope").extensions.live_grep_args.live_grep_args({
            default_text = "",
          })
        end,
        desc = "Live Grep with Args",
      },
      {
        "<leader>fw",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_under_cursor()
        end,
        desc = "Grep word under cursor",
      },
      {
        "<leader>fW",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_under_cursor_current_buffer()
        end,
        desc = "Grep word under cursor (current buffer)",
      },
      {
        "<leader>fv",
        function()
          require("telescope-live-grep-args.shortcuts").grep_visual_selection()
        end,
        mode = "v",
        desc = "Grep visual selection",
      },
      {
        "<leader>fV",
        function()
          require("telescope-live-grep-args.shortcuts").grep_word_visual_selection_current_buffer()
        end,
        mode = "v",
        desc = "Grep visual selection (current buffer)",
      },

      -- File browser keymap
      {
        "<leader>fD",
        function()
          require("telescope").extensions.file_browser.file_browser({
            path = vim.fn.expand("%:p:h"),
            cwd = vim.fn.expand("%:p:h"),
            respect_gitignore = false,
            hidden = true,
            grouped = true,
            previewer = false,
            initial_mode = "normal",
            layout_config = { height = 0.7 },
          })
        end,
        desc = "File Browser (Standalone)",
      },
    },
  },
}
