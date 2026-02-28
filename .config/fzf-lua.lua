-- fzf-lua CLI configuration
-- Full parity with Neovim fzf-lua setup
--
-- Features:
--   - Preview with bat (syntax highlighting, 60% width)
--   - Multi-select with Tab/Shift-Tab
--   - Toggle preview with Ctrl-/
--   - Copy path with Ctrl-y
--   - Scope switching with Alt-L/S/G (Neovim parity)
--   - Header hints showing available keybindings

local function quit() vim.cmd.quit() end

-- Helper: Output selected files to stdout
local function output_files(selected, opts)
  if not selected or #selected == 0 then return quit() end
  local path = require("fzf-lua.path")
  for _, sel in ipairs(selected) do
    local entry = path.entry_to_file(sel, opts)
    local p = path.relative_to(assert(entry.path), vim.uv.cwd())
    io.stdout:write(p .. "\n")
  end
  quit()
end

-- Helper: Copy to clipboard and quit
local function copy_path(selected, opts)
  if not selected or #selected == 0 then return end
  local path = require("fzf-lua.path")
  local paths = {}
  for _, sel in ipairs(selected) do
    local entry = path.entry_to_file(sel, opts)
    table.insert(paths, path.relative_to(assert(entry.path), vim.uv.cwd()))
  end
  local result = table.concat(paths, "\n")
  vim.fn.setreg("+", result)
  io.stderr:write("Copied: " .. result .. "\n")
  quit()
end

-- Scope change action factory
-- CLI mode runs as subprocess, so we can't use vim.schedule() to re-launch
-- Instead, output a marker for Fish to handle the re-launch loop
local function create_scope_action(scope_name)
  return function(_, opts)
    local query = opts.__call_opts and opts.__call_opts.query or ""
    local prompt = opts.prompt or ""
    local picker_type = prompt:match("Grep") and "grep" or "files"
    -- Output: __scope__:SCOPE:PICKER:QUERY (Fish handles re-launch)
    io.stdout:write("__scope__:" .. scope_name .. ":" .. picker_type .. ":" .. query .. "\n")
    quit()
  end
end

-- Zoxide scope action - includes query for preservation across scope switches
-- Fish will rebuild the zoxide command with grep filtering
local function create_zoxide_scope_action(scope_name)
  return function(_, opts)
    local query = opts.__call_opts and opts.__call_opts.query or ""
    io.stdout:write("__zoxide_scope__:" .. scope_name .. ":" .. query .. "\n")
    quit()
  end
end

-- File picker actions (Alt-l/s/g/d/p for scope - Neovim parity)
-- Note: Alt bindings work on all target terminals (Ghostty, WezTerm, iTerm2).
-- Terminals that send Esc-prefix instead of real Alt are handled natively by
-- fzf, which treats Esc+key and Alt+key identically (see `man fzf`).
local file_actions = {
  ["enter"] = output_files,
  ["esc"] = quit,
  ["ctrl-c"] = quit,
  ["ctrl-y"] = copy_path,
  ["alt-l"] = create_scope_action("local"),
  ["alt-s"] = create_scope_action("git"),
  ["alt-g"] = create_scope_action("global"),
  ["alt-d"] = create_scope_action("local"),   -- Buffer dir (same as local in CLI)
  ["alt-p"] = create_scope_action("parent"),
}

-- Header hints (M = Alt/Meta)
local file_header = "C-y:copy | M-l:local M-s:git M-g:global M-p:parent | Tab:multi | C-/:preview"
local grep_header = "C-y:copy | M-l:local M-s:git M-g:global M-p:parent | Tab:multi | C-/:preview"
local zoxide_header = "Enter:cd | M-l:local M-s:git M-g:global M-p:parents | C-/:preview"
local git_header = "Enter:select | C-y:copy SHA | C-/:preview"

-- Setup fzf-lua - MUST inherit "cli" profile!
require("fzf-lua").setup({
  { "cli" }, -- Inherit CLI profile (CRITICAL!)

  -- Global fzf options
  fzf_opts = {
    ["--multi"] = true,
    ["--layout"] = "reverse",
    ["--info"] = "inline-right",
    ["--preview-window"] = "right:60%:wrap",
    ["--bind"] = "ctrl-/:toggle-preview",
  },

  -- Note: Don't use keymap.fzf["key"] = "ignore" - it blocks actions from firing!
  -- Actions are registered via --expect and work correctly without explicit fzf bindings

  -- Preview with bat
  previewers = {
    bat = {
      cmd = "bat",
      args = "--color=always --style=numbers,changes --line-range :500",
    },
  },

  -- Files picker
  files = {
    prompt = "Files (Local)❯ ",
    header = file_header,
    previewer = "bat",
    actions = file_actions,
  },

  -- Grep picker
  grep = {
    prompt = "Grep (Local)❯ ",
    header = grep_header,
    previewer = "bat",
    actions = file_actions,
  },

  live_grep = {
    prompt = "Grep (Local)❯ ",
    header = grep_header,
    previewer = "bat",
    actions = file_actions,
  },

  -- Oldfiles/recent
  oldfiles = {
    prompt = "Recent❯ ",
    header = file_header,
    previewer = "bat",
    actions = file_actions,
  },

  -- Zoxide: Output path to stdout for CLI mode
  -- Note: Scope filtering happens in Fish via cmd parameter with grep
  zoxide = {
    prompt = "Zoxide (Global)❯ ",
    header = zoxide_header,
    actions = {
      ["enter"] = function(s, _)
        if not s[1] then return quit() end
        -- Extract directory path from zoxide output (format: "score    path")
        local dir = s[1]:match("%S+$") or s[1]
        io.stdout:write(dir .. "\n")
        quit()
      end,
      ["alt-l"] = create_zoxide_scope_action("local"),
      ["alt-s"] = create_zoxide_scope_action("git"),
      ["alt-g"] = create_zoxide_scope_action("global"),
      ["alt-p"] = create_zoxide_scope_action("parents"),
      ["esc"] = quit,
      ["ctrl-c"] = quit,
    },
  },

  -- Git pickers
  git = {
    files = {
      prompt = "Git Files❯ ",
      header = file_header,
      previewer = "bat",
      actions = file_actions,
    },
    status = {
      prompt = "Git Status❯ ",
      header = file_header,
      previewer = "bat",
      actions = file_actions,
    },
    commits = {
      prompt = "Git Log❯ ",
      header = "Tab:select | Enter:done | C-y:copy | C-/:preview",
      actions = {
        ["enter"] = function(s, _)
          if not s or #s == 0 then return quit() end
          -- Output all selected SHAs (multi-select support for Diffview)
          for _, item in ipairs(s) do
            local sha = item:match("^(%x+)")
            if sha then io.stdout:write(sha .. "\n") end
          end
          quit()
        end,
        ["ctrl-y"] = function(s, _)
          if not s[1] then return end
          local sha = s[1]:match("^(%x+)")
          if sha then
            vim.fn.setreg("+", sha)
            io.stderr:write("Copied SHA: " .. sha .. "\n")
          end
          quit()
        end,
        ["esc"] = quit,
        ["ctrl-c"] = quit,
      },
    },
    branches = {
      prompt = "Branches❯ ",
      header = "Enter:checkout | C-y:copy | C-/:preview",
      actions = {
        ["enter"] = function(s, _)
          if not s[1] then return quit() end
          local branch = s[1]:match("^%*?%s*(%S+)")
          if branch then
            -- Output special command for Fish to execute git checkout
            io.stdout:write("__checkout__:" .. branch .. "\n")
          end
          quit()
        end,
        ["ctrl-y"] = function(s, _)
          if not s[1] then return end
          local branch = s[1]:match("^%*?%s*(%S+)")
          if branch then
            vim.fn.setreg("+", branch)
            io.stderr:write("Copied: " .. branch .. "\n")
          end
          quit()
        end,
        ["esc"] = quit,
        ["ctrl-c"] = quit,
      },
    },
    stash = {
      prompt = "Git Stash❯ ",
      header = "Enter:apply | C-x:drop | C-y:copy | C-/:preview",
      actions = {
        ["enter"] = function(s, _)
          if not s[1] then return quit() end
          local ref = s[1]:match("^(%S+)")
          if ref then io.stdout:write("__stash_apply__:" .. ref .. "\n") end
          quit()
        end,
        ["ctrl-x"] = function(s, _)
          if not s[1] then return quit() end
          local ref = s[1]:match("^(%S+)")
          if ref then io.stdout:write("__stash_drop__:" .. ref .. "\n") end
          quit()
        end,
        ["ctrl-y"] = function(s, _)
          if not s[1] then return end
          local ref = s[1]:match("^(%S+)")
          if ref then
            vim.fn.setreg("+", ref)
            io.stderr:write("Copied: " .. ref .. "\n")
          end
          quit()
        end,
        ["esc"] = quit,
        ["ctrl-c"] = quit,
      },
    },
    bcommits = {
      prompt = "Git Buffer Commits❯ ",
      header = git_header,
      actions = {
        ["enter"] = function(s, _)
          if not s[1] then return quit() end
          local sha = s[1]:match("^(%x+)")
          if sha then io.stdout:write(sha .. "\n") end
          quit()
        end,
        ["ctrl-y"] = function(s, _)
          if not s[1] then return end
          local sha = s[1]:match("^(%x+)")
          if sha then
            vim.fn.setreg("+", sha)
            io.stderr:write("Copied SHA: " .. sha .. "\n")
          end
          quit()
        end,
        ["esc"] = quit,
        ["ctrl-c"] = quit,
      },
    },
  },

  -- Builtin picker
  builtin = {
    prompt = "Pickers❯ ",
  },
})
