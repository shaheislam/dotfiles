-- Test script to verify Kai keymaps
vim.defer_fn(function()
  print("=== Testing Kai Keymaps ===")
  
  -- Check for leader-a mappings
  local n_maps = vim.api.nvim_get_keymap('n')
  local v_maps = vim.api.nvim_get_keymap('v')
  
  local found_maps = {}
  
  -- Check normal mode mappings
  for _, map in ipairs(n_maps) do
    if map.lhs and map.lhs:match('a[itc]$') then
      table.insert(found_maps, "n:" .. map.lhs .. " -> " .. (map.desc or "no desc"))
    end
  end
  
  -- Check visual mode mappings
  for _, map in ipairs(v_maps) do
    if map.lhs and map.lhs:match('ai$') then
      table.insert(found_maps, "v:" .. map.lhs .. " -> " .. (map.desc or "no desc"))
    end
  end
  
  if #found_maps > 0 then
    print("Found Kai mappings:")
    for _, map in ipairs(found_maps) do
      print("  " .. map)
    end
  else
    print("No Kai mappings found!")
  end
  
  -- Try to load kai-chat module
  local chat_ok, kai_chat = pcall(require, "config.kai-chat")
  if chat_ok then
    print("✓ kai-chat module loaded successfully")
    if kai_chat.toggle_chat then
      print("✓ toggle_chat function exists")
    else
      print("✗ toggle_chat function missing")
    end
  else
    print("✗ Failed to load kai-chat module: " .. tostring(kai_chat))
  end
end, 100)

return {}