-- Enhanced Kai Chat - Interactive Claude conversation in Neovim
local M = {}

-- State management
M.chat_buffer = nil
M.chat_window = nil
M.conversation_history = {}
M.temp_history_file = vim.fn.tempname() .. "_kai_history.txt"

-- Configuration
M.config = {
  window_width = 80,
  window_height = 30,
  position = "right", -- "right", "left", "bottom", "floating"
  show_tool_use = true,
  auto_scroll = true,
  keymaps = {
    send = "<CR>",
    close = "q",
    clear = "<C-l>",
    apply_code = "<C-a>",
    copy_code = "<C-c>",
    toggle_tool_use = "<C-t>",
  }
}

-- Helper function to create highlight groups
local function setup_highlights()
  vim.cmd('highlight KaiChatUser guifg=#87CEEB')  -- Sky blue for user
  vim.cmd('highlight KaiChatAI guifg=#98FB98')    -- Pale green for AI
  vim.cmd('highlight KaiChatTool guifg=#DDA0DD')  -- Plum for tool use
  vim.cmd('highlight KaiChatCode guifg=#FFD700')  -- Gold for code
  vim.cmd('highlight KaiChatBorder guifg=#708090') -- Slate gray for border
  vim.cmd('highlight KaiChatPrompt guifg=#FF69B4') -- Hot pink for prompt
end

-- Function to create or get the chat window
function M.create_chat_window()
  -- If window exists and is valid, just focus it
  if M.chat_window and vim.api.nvim_win_is_valid(M.chat_window) then
    vim.api.nvim_set_current_win(M.chat_window)
    return
  end
  
  -- Create a new buffer for chat
  M.chat_buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.chat_buffer, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.chat_buffer, 'swapfile', false)
  vim.api.nvim_buf_set_option(M.chat_buffer, 'filetype', 'markdown')
  vim.api.nvim_buf_set_name(M.chat_buffer, "Kai Chat")
  
  -- Calculate window dimensions
  local width = M.config.window_width
  local height = M.config.window_height
  
  if M.config.position == "floating" then
    -- Create floating window
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    M.chat_window = vim.api.nvim_open_win(M.chat_buffer, true, {
      relative = 'editor',
      row = row,
      col = col,
      width = width,
      height = height,
      style = 'minimal',
      border = 'rounded',
      title = ' Kai Chat (Claude) ',
      title_pos = 'center'
    })
  elseif M.config.position == "right" then
    -- Create vertical split on the right
    vim.cmd('rightbelow vsplit')
    M.chat_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(M.chat_window, width)
    vim.api.nvim_win_set_buf(M.chat_window, M.chat_buffer)
  elseif M.config.position == "bottom" then
    -- Create horizontal split at bottom
    vim.cmd('rightbelow split')
    M.chat_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_height(M.chat_window, height)
    vim.api.nvim_win_set_buf(M.chat_window, M.chat_buffer)
  end
  
  -- Set up window options
  vim.api.nvim_win_set_option(M.chat_window, 'wrap', true)
  vim.api.nvim_win_set_option(M.chat_window, 'linebreak', true)
  vim.api.nvim_win_set_option(M.chat_window, 'number', false)
  vim.api.nvim_win_set_option(M.chat_window, 'relativenumber', false)
  
  -- Add welcome message if buffer is empty
  if vim.api.nvim_buf_line_count(M.chat_buffer) == 1 then
    local welcome_lines = {
      "╭─────────────────────────────────────╮",
      "│     Welcome to Kai Chat (Claude)    │",
      "╰─────────────────────────────────────╯",
      "",
      "Commands:",
      "  • Type your message and press Enter to send",
      "  • 'q' to close this window",
      "  • Ctrl-L to clear chat history",
      "  • Ctrl-A to apply code from last response",
      "  • Ctrl-C to copy code from last response",
      "  • Ctrl-T to toggle tool use visibility",
      "",
      "─────────────────────────────────────",
      "",
      "Type your message below and press Enter:",
      "",
    }
    vim.api.nvim_buf_set_lines(M.chat_buffer, 0, -1, false, welcome_lines)
    -- Move cursor to the input line
    vim.api.nvim_win_set_cursor(M.chat_window, {#welcome_lines, 0})
  end
  
  -- Set up keymaps for the chat buffer
  M.setup_chat_keymaps()
  
  -- Load conversation history if it exists
  M.load_history()
end

-- Function to set up keymaps in the chat buffer
function M.setup_chat_keymaps()
  local opts = { noremap = true, silent = true, buffer = M.chat_buffer }
  
  -- Send message on Enter (in insert mode)
  vim.keymap.set('i', M.config.keymaps.send, function()
    M.send_current_line()
  end, opts)
  
  -- Close window
  vim.keymap.set('n', M.config.keymaps.close, function()
    M.close_chat()
  end, opts)
  
  -- Clear chat
  vim.keymap.set('n', M.config.keymaps.clear, function()
    M.clear_chat()
  end, opts)
  
  -- Apply last code block
  vim.keymap.set('n', M.config.keymaps.apply_code, function()
    M.apply_last_code()
  end, opts)
  
  -- Copy last code block
  vim.keymap.set('n', M.config.keymaps.copy_code, function()
    M.copy_last_code()
  end, opts)
  
  -- Toggle tool use visibility
  vim.keymap.set('n', M.config.keymaps.toggle_tool_use, function()
    M.config.show_tool_use = not M.config.show_tool_use
    print("Tool use visibility: " .. (M.config.show_tool_use and "ON" or "OFF"))
  end, opts)
end

-- Function to send the current line as a message
function M.send_current_line()
  -- Get current line
  local row = vim.api.nvim_win_get_cursor(M.chat_window)[1]
  local line = vim.api.nvim_buf_get_lines(M.chat_buffer, row - 1, row, false)[1]
  
  -- Don't send empty lines or UI elements
  if line == "" or line:match("^[─╭╰│]") or line:match("^Commands:") or line:match("^%s*•") then
    -- If empty, add a new line for input
    vim.api.nvim_buf_set_lines(M.chat_buffer, -1, -1, false, {""})
    local new_row = vim.api.nvim_buf_line_count(M.chat_buffer)
    vim.api.nvim_win_set_cursor(M.chat_window, {new_row, 0})
    return
  end
  
  -- Add user message to chat
  M.add_to_chat("You", line, "user")
  
  -- Clear the input line
  vim.api.nvim_buf_set_lines(M.chat_buffer, row - 1, row, false, {""})
  
  -- Send to Claude
  M.send_to_claude(line)
end

-- Function to add message to chat display
function M.add_to_chat(sender, message, type)
  local lines = vim.api.nvim_buf_get_lines(M.chat_buffer, 0, -1, false)
  local new_lines = {}
  
  -- Add sender header
  if type == "user" then
    table.insert(new_lines, "")
    table.insert(new_lines, "👤 You:")
  elseif type == "ai" then
    table.insert(new_lines, "")
    table.insert(new_lines, "🤖 Claude:")
  elseif type == "tool" then
    table.insert(new_lines, "")
    table.insert(new_lines, "🔧 Tool Use:")
  end
  
  -- Add message lines
  for line in message:gmatch("[^\n]+") do
    table.insert(new_lines, "  " .. line)
  end
  
  -- Append to buffer
  vim.api.nvim_buf_set_lines(M.chat_buffer, -1, -1, false, new_lines)
  
  -- Auto scroll to bottom
  if M.config.auto_scroll then
    vim.api.nvim_win_set_cursor(M.chat_window, {vim.api.nvim_buf_line_count(M.chat_buffer), 0})
  end
  
  -- Add to history
  table.insert(M.conversation_history, {sender = sender, message = message, type = type})
  M.save_history()
end

-- Function to send message to Claude
function M.send_to_claude(prompt)
  -- Get current buffer content for context
  local original_window = vim.fn.win_getid()
  vim.fn.win_gotoid(original_window)
  local original_buffer = vim.api.nvim_get_current_buf()
  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(original_buffer, 0, -1, false), "\n")
  local filetype = vim.api.nvim_buf_get_option(original_buffer, 'filetype')
  local filename = vim.api.nvim_buf_get_name(original_buffer)
  
  -- Go back to chat window
  vim.api.nvim_set_current_win(M.chat_window)
  
  -- Create context for Claude
  local context = string.format([[
You are an AI assistant integrated into Neovim, having a conversation with the user.
The user is currently editing a %s file: %s

Current file content:
```%s
%s
```

Conversation history:
%s

Instructions:
- Provide helpful, concise responses
- When showing code, use proper markdown code blocks with language tags
- When suggesting edits, be specific about what changes to make
- You can see the current file content above for context

User's message: %s
]], filetype, filename, filetype, buffer_content, M.format_history(), prompt)
  
  -- Write context to temp file
  local temp_file = vim.fn.tempname()
  local f = io.open(temp_file, "w")
  f:write(context)
  f:close()
  
  -- Call Claude CLI via our chat script
  M.add_to_chat("Claude", "Thinking...", "ai")
  
  -- Use the kai-chat.sh script in chat mode
  local script_path = vim.fn.stdpath("config") .. "/lua/scripts/kai-chat.sh"
  local cmd = {script_path, "chat", temp_file, prompt}
  
  -- Accumulate response
  local response_lines = {}
  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(response_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= "" and M.config.show_tool_use then
            -- Show tool use if enabled
            if line:match("Tool:") or line:match("Reading:") or line:match("Writing:") then
              M.add_to_chat("System", line, "tool")
            end
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Remove "Thinking..." message
      local lines = vim.api.nvim_buf_get_lines(M.chat_buffer, 0, -1, false)
      for i = #lines, 1, -1 do
        if lines[i] == "  Thinking..." then
          vim.api.nvim_buf_set_lines(M.chat_buffer, i - 1, i, false, {})
          break
        end
      end
      
      -- Add complete response
      if #response_lines > 0 then
        local response = table.concat(response_lines, "\n")
        M.add_to_chat("Claude", response, "ai")
      elseif exit_code ~= 0 then
        M.add_to_chat("System", "Claude process exited with code: " .. exit_code, "tool")
      end
    end
  })
  
  -- Clean up
  vim.fn.delete(temp_file)
end

-- Function to format conversation history
function M.format_history()
  local formatted = {}
  for _, entry in ipairs(M.conversation_history) do
    table.insert(formatted, string.format("%s: %s", entry.sender, entry.message))
  end
  return table.concat(formatted, "\n")
end

-- Function to extract and apply last code block
function M.apply_last_code()
  -- Find last code block in conversation
  local lines = vim.api.nvim_buf_get_lines(M.chat_buffer, 0, -1, false)
  local code_lines = {}
  local in_code_block = false
  local code_lang = ""
  
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^%s*```") then
      if in_code_block then
        -- Found start of code block
        code_lang = line:match("```(%w+)")
        break
      else
        -- Found end of code block
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(code_lines, 1, line:gsub("^  ", ""))
    end
  end
  
  if #code_lines > 0 then
    -- Apply code to original buffer
    local original_window = vim.fn.win_getid()
    for win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
      if win ~= M.chat_window then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
    
    -- Insert code at cursor position
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, code_lines)
    
    -- Go back to chat window
    vim.api.nvim_set_current_win(M.chat_window)
    print("Code applied to buffer!")
  else
    print("No code block found in conversation")
  end
end

-- Function to copy last code block to clipboard
function M.copy_last_code()
  -- Similar to apply_last_code but copies to clipboard
  local lines = vim.api.nvim_buf_get_lines(M.chat_buffer, 0, -1, false)
  local code_lines = {}
  local in_code_block = false
  
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^%s*```") then
      if in_code_block then
        break
      else
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(code_lines, 1, line:gsub("^  ", ""))
    end
  end
  
  if #code_lines > 0 then
    local code = table.concat(code_lines, "\n")
    vim.fn.setreg('+', code)
    print("Code copied to clipboard!")
  else
    print("No code block found in conversation")
  end
end

-- Function to clear chat
function M.clear_chat()
  M.conversation_history = {}
  M.save_history()
  vim.api.nvim_buf_set_lines(M.chat_buffer, 0, -1, false, {
    "╭─────────────────────────────────────╮",
    "│     Welcome to Kai Chat (Claude)    │",
    "╰─────────────────────────────────────╯",
    "",
    "Chat cleared. Type your message below:",
    "",
  })
end

-- Function to close chat window
function M.close_chat()
  if M.chat_window and vim.api.nvim_win_is_valid(M.chat_window) then
    vim.api.nvim_win_close(M.chat_window, true)
  end
  M.chat_window = nil
end

-- Function to save conversation history
function M.save_history()
  local f = io.open(M.temp_history_file, "w")
  if f then
    f:write(vim.json.encode(M.conversation_history))
    f:close()
  end
end

-- Function to load conversation history
function M.load_history()
  local f = io.open(M.temp_history_file, "r")
  if f then
    local content = f:read("*all")
    f:close()
    if content and content ~= "" then
      M.conversation_history = vim.json.decode(content) or {}
      -- Replay history in chat buffer
      for _, entry in ipairs(M.conversation_history) do
        M.add_to_chat(entry.sender, entry.message, entry.type)
      end
    end
  end
end

-- Main function to toggle chat window
function M.toggle_chat()
  setup_highlights()
  
  if M.chat_window and vim.api.nvim_win_is_valid(M.chat_window) then
    M.close_chat()
  else
    M.create_chat_window()
  end
end

-- Setup function
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Set up global keybinding to toggle chat
  vim.keymap.set('n', '<leader>ac', M.toggle_chat, { desc = "Toggle Kai Chat (Claude)" })
  
  -- Keep the original kai-neovim functionality
  vim.keymap.set('n', '<leader>ai', function() require("config.kai-neovim").kai_enhance() end, { desc = "Kai Quick AI (Claude)" })
  vim.keymap.set('v', '<leader>ai', function() require("config.kai-neovim").kai_enhance() end, { desc = "Kai Quick AI (Claude)" })
end

return M