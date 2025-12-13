-- fzf-lua CLI configuration
-- Provides scope toggle (Ctrl-D/S/G) matching Neovim behavior
--
-- IMPORTANT: Must inherit "cli" profile since cli.lua loads this AFTER
-- calling setup({ "cli" }). Without inheriting, we overwrite the CLI profile.
--
-- Scope keybindings (inside fzf picker):
--   Ctrl-D = Local (current directory)
--   Ctrl-S = Git root
--   Ctrl-G = Global (home directory)

local current_scope = "Local"
local function quit() vim.cmd.quit() end

-- Helper: Find git root from current directory
local function get_git_root()
  local git_dir = vim.fs.find(".git", { path = vim.fn.getcwd(), upward = true })[1]
  if git_dir then
    return vim.fn.fnamemodify(git_dir, ":h")
  end
  return vim.fn.getcwd()
end

-- Scope change action factory
local function create_scope_action(get_cwd_fn, scope_name)
  return function(_, opts)
    local new_cwd = get_cwd_fn()
    current_scope = scope_name

    local query = opts.__call_opts and opts.__call_opts.query or ""
    local prompt = opts.prompt or ""

    vim.schedule(function()
      if prompt:match("Grep") then
        require("fzf-lua").live_grep({
          cwd = new_cwd,
          query = query,
          prompt = "Live Grep (" .. scope_name .. ")> ",
        })
      else
        require("fzf-lua").files({
          cwd = new_cwd,
          query = query,
          prompt = "Find Files (" .. scope_name .. ")> ",
        })
      end
    end)
  end
end

-- Scope actions table (reusable across pickers)
local scope_actions = {
  ["ctrl-d"] = create_scope_action(function()
    return vim.fn.getcwd()
  end, "Local"),
  ["ctrl-s"] = create_scope_action(get_git_root, "Git Root"),
  ["ctrl-g"] = create_scope_action(function()
    return vim.env.HOME
  end, "Global"),
}

-- Setup fzf-lua - MUST inherit "cli" profile!
require("fzf-lua").setup({
  { "cli" }, -- Inherit CLI profile (CRITICAL!)
  keymap = {
    fzf = {
      -- Prevent fzf from handling these keys (let actions handle them)
      ["ctrl-d"] = "ignore",
      ["ctrl-s"] = "ignore",
      ["ctrl-g"] = "ignore",
    },
  },
  actions = {
    files = scope_actions,
  },
  files = {
    prompt = "Find Files (Local)> ",
  },
  grep = {
    prompt = "Live Grep (Local)> ",
    actions = scope_actions,
  },
  -- Zoxide: Override default action to output path to stdout (for CLI mode)
  -- Default actions.zoxide_cd only changes cwd inside nvim, doesn't output anything
  zoxide = {
    actions = {
      ["enter"] = function(s, _)
        if not s[1] then return quit() end
        -- Extract directory path from zoxide output (format: "score\tpath")
        local dir = s[1]:match("[^\t]+$") or s[1]
        io.stdout:write(dir .. "\n")
        quit()
      end,
      ["esc"] = quit,
      ["ctrl-c"] = quit,
    },
  },
})
