-- Test file for autocomplete functionality
-- Try typing the following and use Tab to complete:
-- 1. Type "pri" and press Tab (should complete to "print")
-- 2. Type "req" and press Tab (should show "require")
-- 3. Type "vim." and press Tab (should show vim API completions)
-- 4. Type "string." and press Tab (should show string library functions)

-- Test basic Lua completions
local function test_completion()
  -- Try typing: pr<Tab> (should complete to print)

  -- Try typing: req<Tab> (should complete to require)

  -- Try typing: vim.api.nvim_<Tab> (should show vim API functions)

  -- Try typing: string.f<Tab> (should show format, find, etc.)
end

-- Instructions:
-- 1. Open this file in Neovim: nvim test_autocomplete.lua
-- 2. Go into insert mode (i)
-- 3. Try the completions mentioned above
-- 4. Use Tab to accept completions
-- 5. Use Shift-Tab to navigate backwards
-- 6. Use Ctrl-Space to manually trigger completion if needed
-- 7. Use Ctrl-Y or Enter as alternative ways to accept

