-- Debug script to test gg behavior
-- Run this in Neovim with :source ~/dotfiles/debug-gg.lua

print("=== Debugging gg command ===")
print("")

-- Check if gg is mapped
local gg_map = vim.fn.maparg('gg', 'n', false, true)
if vim.tbl_isempty(gg_map) then
  print("✓ gg is NOT mapped (using default Vim behavior)")
else
  print("✗ gg IS mapped:")
  print(vim.inspect(gg_map))
end

print("")

-- Check if g is mapped (could be waiting for second key)
local g_map = vim.fn.maparg('g', 'n', false, true)
if vim.tbl_isempty(g_map) then
  print("✓ g is NOT mapped")
else
  print("✗ g IS mapped:")
  print(vim.inspect(g_map))
end

print("")

-- Check timeoutlen
print("⏱ timeoutlen = " .. vim.o.timeoutlen .. "ms")
print("   (Time Vim waits for second key after 'g')")

print("")

-- Test if which-key is interfering
local has_whichkey, wk = pcall(require, "which-key")
if has_whichkey then
  print("⚠ which-key.nvim is loaded")
  print("   This might be waiting for a second key after 'g'")
else
  print("✓ which-key.nvim is not loaded")
end

print("")
print("=== Manual Test ===")
print("1. Press G - should go to bottom")
print("2. Press gg - should go to top")
print("3. If gg doesn't work, run: :verbose nmap gg")
print("")
