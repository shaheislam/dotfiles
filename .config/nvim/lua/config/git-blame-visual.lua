-- Visual mode git blame extension
local M = {}

local ns_id = vim.api.nvim_create_namespace("git-blame-visual-lines")
local blame_cache = {}
local visual_blame_enabled = false

-- Parse git blame output
local function parse_git_blame(output)
  local blame_data = {}
  local current_info = {}
  
  for _, line in ipairs(output) do
    local sha, _, final = line:match("^([0-9a-f]+) (%d+) (%d+)")
    if sha then
      current_info = { sha = sha, line = tonumber(final) }
    elseif line:match("^author ") then
      current_info.author = line:match("^author (.+)$")
    elseif line:match("^author%-time ") then
      current_info.time = tonumber(line:match("^author%-time (%d+)"))
    elseif line:match("^summary ") then
      current_info.summary = line:match("^summary (.+)$")
      if current_info.line then
        blame_data[current_info.line] = vim.deepcopy(current_info)
      end
    end
  end
  
  return blame_data
end

-- Show blame for visual selection
function M.show_visual_blame()
  -- Only proceed if git blame is enabled
  if not vim.g.gitblame_enabled then
    return
  end
  
  -- Get visual selection range
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  
  -- Get file path
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then return end
  
  -- Load or cache blame data
  if not blame_cache[filepath] then
    local output = vim.fn.systemlist("git blame -p " .. vim.fn.shellescape(filepath))
    if vim.v.shell_error ~= 0 then return end
    blame_cache[filepath] = parse_git_blame(output)
  end
  
  local blame_data = blame_cache[filepath]
  if not blame_data then return end
  
  -- Clear previous visual blame
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  
  -- Show blame for each line in range
  for line_num = start_line, end_line do
    local info = blame_data[line_num]
    if info and info.sha ~= "0000000000000000000000000000000000000000" then
      local date_str = os.date(vim.g.gitblame_date_format or "%Y-%m-%d", info.time or os.time())
      local blame_text = string.format("%s, %s - %s",
        info.author or "Unknown",
        date_str,
        info.summary or "")
      
      -- Set virtual text with high priority
      vim.api.nvim_buf_set_extmark(0, ns_id, line_num - 1, 0, {
        virt_text = {{(vim.g.gitblame_virtual_text_prefix or " ■ ") .. blame_text, vim.g.gitblame_highlight_group or "Comment"}},
        virt_text_pos = "eol",
        priority = 1000,  -- Very high priority
        hl_mode = "combine",
      })
    end
  end
  
  visual_blame_enabled = true
end

-- Clear visual blame
function M.clear_visual_blame()
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  visual_blame_enabled = false
end

-- Toggle visual blame based on mode
function M.update_visual_blame()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    if vim.g.gitblame_enabled then
      vim.defer_fn(M.show_visual_blame, 1)
    end
  else
    if visual_blame_enabled then
      M.clear_visual_blame()
    end
  end
end

-- Setup autocmds
function M.setup()
  local augroup = vim.api.nvim_create_augroup("GitBlameVisualMode", { clear = true })
  
  -- Update on cursor movement in visual mode
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = M.update_visual_blame,
  })
  
  -- Clear cache on buffer write
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function()
      local filepath = vim.fn.expand("%:p")
      blame_cache[filepath] = nil
    end,
  })
  
  -- Create command for manual trigger
  vim.api.nvim_create_user_command("GitBlameVisual", M.show_visual_blame, {})
end

return M