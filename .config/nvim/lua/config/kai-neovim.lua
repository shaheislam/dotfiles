local M = {}

-- Function to get visual selection
local function get_visual_selection()
  -- Get the visual selection marks
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
  
  -- Get the lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    if end_col > 0 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end
  
  return table.concat(lines, "\n")
end

-- Function to escape special characters for shell
local function shell_escape(str)
  return "'" .. str:gsub("'", "'\"'\"'") .. "'"
end

-- Main function to handle Kai Neovim integration
function M.kai_enhance()
  -- Set up subtle blue highlight for the input prompt
  vim.cmd('highlight KaiPrompt guifg=#e0e0e0 guibg=#1a1a2e')
  
  -- Get the prompt from user with custom highlighting
  vim.cmd('echohl KaiPrompt')
  local prompt = vim.fn.input("🤖 Kai: ")
  vim.cmd('echohl None')
  
  if prompt == "" then
    print("No instruction provided.")
    return
  end
  
  -- Check if we're in visual mode
  local mode = vim.fn.mode()
  local is_visual = mode == 'v' or mode == 'V' or mode == ''
  
  -- Get selection if in visual mode, empty string otherwise
  local selection = ""
  if is_visual then
    selection = get_visual_selection()
  end
  
  -- Get current file path
  local filepath = vim.fn.expand('%:p')
  
  -- Get cursor position
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  
  -- Get entire buffer content
  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  
  -- Create a temporary file for the context
  local context_file = os.tmpname()
  local f = io.open(context_file, "w")
  f:write("CURRENT FILE: " .. filepath .. "\n\n")
  
  -- Always send the entire buffer
  f:write("FULL BUFFER CONTENT:\n" .. buffer_content .. "\n\n")
  
  -- Add cursor position
  f:write("CURSOR POSITION: Line " .. cursor_row .. ", Column " .. cursor_col .. "\n\n")
  
  if is_visual then
    -- Include selection information when text is selected
    local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
    local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
    
    f:write("SELECTED TEXT (Lines " .. start_row .. "-" .. end_row .. "):\n" .. selection .. "\n\n")
    f:write("MODE: User has selected specific text. Focus on this selection within the context of the entire buffer.\n\n")
  else
    -- When no selection, note cursor position
    f:write("MODE: No selection. User's cursor is at line " .. cursor_row .. ". Make targeted changes based on cursor location unless instructed otherwise.\n\n")
  end
  
  f:write("INSTRUCTION: " .. prompt .. "\n")
  f:close()
  
  -- Call Kai script
  local cmd = string.format(
    "~/.config/nvim/scripts/kai-neovim.sh %s %s",
    shell_escape(context_file),
    shell_escape(prompt)
  )
  
  -- Create progress notification (simplified for blog post)
  print("🤖 Processing with Kai...")
  
  -- Execute command
  local output = vim.fn.system(cmd)
  
  -- Clean up temp file
  os.remove(context_file)
  
  -- Parse the action and content from the response
  local lines = vim.split(output, '\n', { plain = true })
  local action = lines[1]
  local content_lines = {}
  for i = 2, #lines do
    if lines[i] ~= "" or i < #lines then
      table.insert(content_lines, lines[i])
    end
  end
  local content = table.concat(content_lines, '\n')
  
  -- Remove any trailing newline
  content = content:gsub('\n$', '')
  
  -- Handle different actions
  if action == "[ACTION:DISPLAY]" then
    -- Create a floating window to display the analysis
    local display_buf = vim.api.nvim_create_buf(false, true)
    local display_lines = vim.split(content, '\n', { plain = true })
    
    -- Calculate window dimensions
    local width = math.min(80, vim.o.columns - 10)
    local height = math.min(#display_lines + 2, vim.o.lines - 10)
    
    -- Set buffer content
    vim.api.nvim_buf_set_lines(display_buf, 0, -1, false, display_lines)
    
    -- Create floating window
    local display_win = vim.api.nvim_open_win(display_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = 'minimal',
      border = 'rounded',
      title = ' Kai Analysis ',
      title_pos = 'center',
    })
    
    -- Set up keymaps to close the window
    local close_keys = {'<Esc>', 'q', '<CR>'}
    for _, key in ipairs(close_keys) do
      vim.api.nvim_buf_set_keymap(display_buf, 'n', key, 
        ':lua vim.api.nvim_win_close(' .. display_win .. ', true)<CR>', 
        { noremap = true, silent = true })
    end
    
    print("Kai analysis complete! Press <Esc>, q, or <Enter> to close.")
    return
  end
  
  -- Perform the appropriate action based on the marker
  if is_visual then
    if action == "[ACTION:REPLACE]" then
      -- Replace the selection
      local save_reg = vim.fn.getreg('"')
      local save_regtype = vim.fn.getregtype('"')
      
      vim.fn.setreg('"', content, mode == 'V' and 'V' or 'v')
      vim.cmd('normal! gv"_d')  -- Delete selection without affecting registers
      vim.cmd('normal! P')      -- Paste before cursor
      
      vim.fn.setreg('"', save_reg, save_regtype)
      
    elseif action == "[ACTION:INSERT_AFTER]" then
      -- Insert after the selection
      vim.cmd('normal! gv')  -- Reselect
      vim.cmd('normal! o')   -- Go to end of selection
      vim.cmd('normal! ')    -- Exit visual mode
      
      -- Insert a newline and the content
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local content_lines_new = vim.split(content, '\n', { plain = true })
      
      -- Insert empty line first, then content
      vim.api.nvim_buf_set_lines(0, row, row, false, {""})
      vim.api.nvim_buf_set_lines(0, row + 1, row + 1, false, content_lines_new)
    end
  else
    -- Normal mode - insert at cursor position
    local content_lines_new = vim.split(content, '\n', { plain = true })
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    
    -- Insert the lines at cursor position
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, content_lines_new)
  end
  
  print("Kai enhancement complete!")
end

-- Set up the keymap
function M.setup()
  -- Visual mode mapping
  vim.keymap.set('v', '<leader>ai', M.kai_enhance,
    { noremap = true, silent = true, desc = "Enhance with Kai (intelligent action)" })
  
  -- Normal mode mapping (insert at cursor)
  vim.keymap.set('n', '<leader>ai', M.kai_enhance, 
    { noremap = true, silent = true, desc = "Insert Kai text at cursor" })
end

return M