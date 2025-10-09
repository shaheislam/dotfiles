# Powerful Neovim Autocmd Use Cases

Autocmds are one of Neovim's most powerful features for automating workflows. This reference guide contains excellent use cases organized by category.

## Table of Contents
- [File-Type Specific Behavior](#1-file-type-specific-behavior)
- [Session Management](#2-session-management)
- [Automatic Cleanup](#3-automatic-cleanup)
- [UI/UX Enhancements](#4-uiux-enhancements)
- [Build & Development Workflows](#5-build--development-workflows)
- [File Management](#6-file-management)
- [Git Integration](#7-git-integration)
- [Performance Optimizations](#8-performance-optimizations)
- [Terminal Integration](#9-terminal-integration)
- [LSP Integration](#10-lsp-integration)
- [Productivity Boosters](#11-productivity-boosters)
- [Advanced Patterns](#advanced-pattern-autocommand-groups)

## 1. File-Type Specific Behavior

### Language-Specific Settings
```lua
-- Set tab width for different languages
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "lua" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Auto-format on save for specific languages
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.js", "*.ts", "*.jsx", "*.tsx" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
```

### Language-Specific Keymaps
```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.keymap.set("n", "<leader>gr", ":!go run %<CR>", { buffer = true })
    vim.keymap.set("n", "<leader>gt", ":!go test ./...<CR>", { buffer = true })
  end,
})
```

## 2. Session Management

### Auto-Save Session
```lua
-- Save session on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.cmd("mksession! ~/.config/nvim/session.vim")
  end,
})

-- Restore last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})
```

## 3. Automatic Cleanup

### Trim Trailing Whitespace
```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    -- Save cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- Remove trailing whitespace
    vim.cmd([[%s/\s\+$//e]])
    -- Restore cursor position
    vim.api.nvim_win_set_cursor(0, cursor)
  end,
})
```

### Auto-Create Missing Directories
```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local dir = vim.fn.expand("<afile>:p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})
```

## 4. UI/UX Enhancements

### Highlight on Yank
```lua
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})
```

### Auto-Resize Windows
```lua
-- Resize splits when terminal is resized
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("wincmd =")
  end,
})
```

### Focus-Based Settings
```lua
-- Highlight current line only in focused window
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  callback = function()
    vim.opt_local.cursorline = true
  end,
})

vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
  callback = function()
    vim.opt_local.cursorline = false
  end,
})
```

## 5. Build & Development Workflows

### Auto-Compile on Save
```lua
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.tex",
  callback = function()
    vim.fn.jobstart("pdflatex " .. vim.fn.expand("%"))
  end,
})
```

### Auto-Run Tests
```lua
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*_test.go",
  callback = function()
    vim.cmd("!go test -v")
  end,
})
```

### Live Reload for Web Development
```lua
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.html", "*.css", "*.js" },
  callback = function()
    -- Trigger browser reload via LiveServer or similar
    vim.fn.system("browser-sync reload")
  end,
})
```

### Auto-Sync with rsync
```lua
-- Sync specific project directories to remote server
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "~/dotfiles/**",
  callback = function()
    vim.fn.system("rsync -avz --delete ~/dotfiles/ user@remote:~/dotfiles/")
  end,
})

-- Sync with notification
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*",
  callback = function()
    local file = vim.fn.expand("%:p")
    local result = vim.fn.system(string.format(
      "rsync -avz %s user@remote-host:/path/to/destination/",
      vim.fn.shellescape(file)
    ))
    if vim.v.shell_error == 0 then
      print("✓ Synced to remote")
    else
      print("✗ Sync failed: " .. result)
    end
  end,
})
```

## 6. File Management

### Auto-Reload Files Changed Outside Vim
```lua
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  callback = function()
    vim.cmd("checktime")
  end,
})
```

### Auto-Save on Focus Lost
```lua
vim.api.nvim_create_autocmd("FocusLost", {
  callback = function()
    vim.cmd("silent! wa")
  end,
})
```

### Template Insertion for New Files
```lua
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*.sh",
  callback = function()
    vim.cmd([[
      0r ~/.config/nvim/templates/bash.sh
      $d
    ]])
  end,
})
```

## 7. Git Integration

### Auto-Stage on Save
```lua
vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function()
    local file = vim.fn.expand("%")
    vim.fn.system("git add " .. vim.fn.shellescape(file))
  end,
})
```

### Show Git Diff on Commit Messages
```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.cmd("DiffviewOpen HEAD")
  end,
})
```

## 8. Performance Optimizations

### Disable Features in Large Files
```lua
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function()
    local file_size = vim.fn.getfsize(vim.fn.expand("%"))
    if file_size > 1000000 then -- 1MB
      vim.opt_local.syntax = "off"
      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
    end
  end,
})
```

## 9. Terminal Integration

### Auto-Enter Insert Mode in Terminal
```lua
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.cmd("startinsert")
  end,
})
```

### Terminal Window Settings
```lua
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})
```

## 10. LSP Integration

### Auto-Format on Save
```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.lua", "*.py", "*.js", "*.ts" },
  callback = function()
    vim.lsp.buf.format({ timeout_ms = 2000 })
  end,
})
```

### Show Diagnostics on Hover
```lua
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focus = false })
  end,
})
```

## 11. Productivity Boosters

### Auto-Close Certain Windows
```lua
-- Auto-close quickfix/help windows with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "help", "man", "lspinfo" },
  callback = function()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true })
  end,
})
```

### Auto-Update Plugins on Startup
```lua
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Check for updates weekly
    local last_update = vim.fn.getftime(vim.fn.stdpath("data") .. "/lazy/lazy.nvim/.git/FETCH_HEAD")
    local week_ago = os.time() - (7 * 24 * 60 * 60)
    if last_update < week_ago then
      require("lazy").sync()
    end
  end,
})
```

## Advanced Pattern: Autocommand Groups

Organize related autocmds for better management:

```lua
local augroup = vim.api.nvim_create_augroup("MyGroup", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*.py",
  callback = function()
    vim.lsp.buf.format()
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup,
  pattern = "*.py",
  callback = function()
    vim.cmd("!black %")
  end,
})
```

## Tips for Using Autocmds

1. **Use `vim.opt_local`** for buffer-specific settings to avoid affecting other buffers
2. **Organize with groups** to keep related autocmds together and prevent duplicates
3. **Be careful with performance** - avoid heavy operations in frequently triggered events
4. **Test thoroughly** - autocmds can have unexpected side effects if not carefully designed
5. **Use `buffer = true`** in keymaps created by autocmds to keep them buffer-local
6. **Consider async operations** for time-consuming tasks using `vim.fn.jobstart()` or `vim.loop`

## Common Events Reference

- `BufReadPre/Post` - Before/after reading a buffer
- `BufWritePre/Post` - Before/after writing a buffer
- `FileType` - When file type is set
- `VimEnter` - After starting Vim
- `VimLeavePre` - Before exiting Vim
- `WinEnter/Leave` - When entering/leaving a window
- `BufEnter/Leave` - When entering/leaving a buffer
- `FocusGained/Lost` - When Vim gains/loses focus
- `TextYankPost` - After yanking text
- `CursorHold` - When cursor is idle for 'updatetime' ms
- `TermOpen` - When opening a terminal buffer

For a complete list, see `:help autocmd-events`

## Where to Place Your Autocmds

In LazyVim, autocmds can be placed in:
- `~/.config/nvim/lua/config/autocmds.lua` - General autocmds
- `~/.config/nvim/lua/plugins/*.lua` - Plugin-specific autocmds
- Plugin config functions when using Lazy.nvim

## Resources

- `:help autocmd` - Neovim autocmd documentation
- `:help events` - List of all available events
- `:help lua-guide-autocommands` - Lua API guide for autocmds
