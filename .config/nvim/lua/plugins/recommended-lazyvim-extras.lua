-- Recommended LazyVim Extras to Enable
-- These are built-in LazyVim features you're not using yet

return {
  {
    "LazyVim/LazyVim",
    opts = {
      extras = {
        -- ============== AI EXTRAS ==============
        -- "lazyvim.plugins.extras.ai.copilot",     -- GitHub Copilot (disabled)
        -- "lazyvim.plugins.extras.ai.copilot-chat", -- Copilot Chat (disabled)
        "lazyvim.plugins.extras.ai.codeium",        -- Free AI autocomplete alternative
        
        -- ============== CODING EXTRAS ==============
        "lazyvim.plugins.extras.coding.mini-surround", -- Better surround operations
        "lazyvim.plugins.extras.coding.neogen",        -- Generate annotations/docs
        "lazyvim.plugins.extras.coding.yanky",         -- Better yank/paste
        "lazyvim.plugins.extras.coding.luasnip",       -- Snippet engine
        
        -- ============== EDITOR EXTRAS ==============
        "lazyvim.plugins.extras.editor.aerial",        -- Code outline window
        "lazyvim.plugins.extras.editor.dial",          -- Increment/decrement enhanced
        "lazyvim.plugins.extras.editor.inc-rename",    -- Incremental rename preview
        "lazyvim.plugins.extras.editor.leap",          -- Fast navigation
        "lazyvim.plugins.extras.editor.mini-diff",     -- Git diff indicators
        "lazyvim.plugins.extras.editor.mini-files",    -- Alternative file explorer
        "lazyvim.plugins.extras.editor.navic",         -- Breadcrumbs in statusline
        "lazyvim.plugins.extras.editor.outline",       -- Code outline sidebar
        "lazyvim.plugins.extras.editor.refactoring",   -- Refactoring tools
        
        -- ============== UI EXTRAS ==============
        "lazyvim.plugins.extras.ui.alpha",             -- Dashboard/startup screen
        "lazyvim.plugins.extras.ui.mini-animate",      -- Smooth animations
        "lazyvim.plugins.extras.ui.mini-indentscope",  -- Active indent guides
        "lazyvim.plugins.extras.ui.treesitter-context", -- Sticky function headers
        
        -- ============== UTIL EXTRAS ==============
        "lazyvim.plugins.extras.util.dot",             -- Dotfile management
        "lazyvim.plugins.extras.util.gitui",           -- Terminal UI for git
        "lazyvim.plugins.extras.util.mini-hipatterns", -- Highlight patterns
        "lazyvim.plugins.extras.util.project",         -- Project management
        "lazyvim.plugins.extras.util.rest",            -- REST client
        
        -- ============== DAP (DEBUGGING) ==============
        "lazyvim.plugins.extras.dap.core",             -- Debug Adapter Protocol
        
        -- ============== TEST EXTRAS ==============
        "lazyvim.plugins.extras.test.core",            -- Test runner framework
        
        -- ============== FORMATTING ==============
        "lazyvim.plugins.extras.formatting.prettier",   -- Prettier formatter
        "lazyvim.plugins.extras.formatting.black",      -- Black for Python
        
        -- ============== LINTING ==============
        "lazyvim.plugins.extras.linting.eslint",        -- ESLint for JS/TS
        
        -- ============== LSP EXTRAS ==============
        "lazyvim.plugins.extras.lsp.none-ls",          -- Additional LSP sources
      },
    },
  },
}

-- HOW TO ENABLE THESE EXTRAS:
-- 
-- Option 1: Use LazyVim's built-in extra management
-- 1. Open Neovim
-- 2. Press <leader>l to open Lazy
-- 3. Press x to open extras
-- 4. Select the extras you want to enable
-- 
-- Option 2: Add to your lazyvim.json file
-- Edit ~/.config/nvim/lazyvim.json and add to the "extras" array:
-- {
--   "extras": [
--     "lazyvim.plugins.extras.ai.copilot",
--     "lazyvim.plugins.extras.editor.aerial",
--     "lazyvim.plugins.extras.ui.alpha",
--     // ... add more as needed
--   ]
-- }
-- 
-- Option 3: Include this file in your config
-- Just having this file will enable all the recommended extras
-- 
-- NOTES:
-- - Some extras may conflict (e.g., copilot vs codeium - choose one)
-- - DAP extras require language-specific DAP configurations
-- - Some extras require additional setup (API keys, external tools)