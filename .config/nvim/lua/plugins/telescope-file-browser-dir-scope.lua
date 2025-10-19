-- Telescope file browser directory scoping integration
-- Enables <M-f> (Alt-f) during live_grep, find_files, and live_grep_args to:
-- 1. Open visual directory picker (similar to Oil.nvim UI)
-- 2. Select a directory to scope the search
-- 3. Return to the original picker with search preserved and scoped to selected directory
-- 4. Repeat iteratively to refine scope as needed
--
-- Flow:
--   live_grep → <M-f> → directory picker → select dir → live_grep (scoped) → <M-f> → ...
--
-- Benefits:
--   - Iteratively narrow down search scope without losing context
--   - Visual directory selection
--   - Works with live_grep, find_files, and live_grep_args
--   - Preserves search terms when switching scopes

return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local telescope = require("telescope")

      -- Generic directory selector that works with any telescope picker
      -- @param picker_fn function: The telescope picker function to call after directory selection
      -- @param picker_opts table|nil: Optional additional options to pass to the picker
      -- @return function: A telescope action function
      local function select_dir_for_action(picker_fn, picker_opts)
        return function(prompt_bufnr)
          local action_state = require("telescope.actions.state")
          local fb = telescope.extensions.file_browser
          local current_line = action_state.get_current_line()

          fb.file_browser({
            files = false, -- Show only directories
            depth = false, -- Don't limit depth
            attach_mappings = function(prompt_bufnr)
              require("telescope.actions").select_default:replace(function()
                local entry_path = action_state.get_selected_entry().Path
                local dir = entry_path:is_dir() and entry_path or entry_path:parent()
                local relative = dir:make_relative(vim.fn.getcwd())
                local absolute = dir:absolute()

                -- Merge default options with custom picker options
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

      -- Configure telescope file_browser extension and add <C-f> mappings
      telescope.setup({
        extensions = {
          file_browser = {
            theme = "ivy",
            hijack_netrw = false, -- Don't hijack netrw, we use Oil.nvim
            mappings = {
              ["i"] = {
                -- Add custom file_browser mappings here if needed
              },
              ["n"] = {
                -- Add custom file_browser mappings here if needed
              },
            },
          },
        },
      })

      -- Load the file_browser extension
      telescope.load_extension("file_browser")

      -- Add <M-f> (Alt-f) directory scoping to built-in telescope pickers
      local builtin_pickers = require("telescope.builtin")

      -- Extend existing telescope setup for built-in pickers
      telescope.setup({
        pickers = {
          live_grep = {
            mappings = {
              i = {
                ["<M-f>"] = select_dir_for_action(builtin_pickers.live_grep),
              },
              n = {
                ["<M-f>"] = select_dir_for_action(builtin_pickers.live_grep),
              },
            },
          },
          find_files = {
            mappings = {
              i = {
                ["<M-f>"] = select_dir_for_action(
                  builtin_pickers.find_files,
                  { hidden = true } -- Show hidden files in scoped search
                ),
              },
              n = {
                ["<M-f>"] = select_dir_for_action(
                  builtin_pickers.find_files,
                  { hidden = true }
                ),
              },
            },
          },
        },
      })

      -- Add <M-f> (Alt-f) directory scoping to live_grep_args extension
      -- This is configured separately as it's an extension, not a built-in picker
      local has_live_grep_args, _ = pcall(require, "telescope-live-grep-args")
      if has_live_grep_args then
        telescope.setup({
          extensions = {
            live_grep_args = {
              mappings = {
                i = {
                  ["<M-f>"] = select_dir_for_action(
                    function(opts)
                      telescope.extensions.live_grep_args.live_grep_args(opts)
                    end
                  ),
                },
                n = {
                  ["<M-f>"] = select_dir_for_action(
                    function(opts)
                      telescope.extensions.live_grep_args.live_grep_args(opts)
                    end
                  ),
                },
              },
            },
          },
        })
      end
    end,
    keys = {
      -- Optional: Add standalone file_browser keybinding
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
