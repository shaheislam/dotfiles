# Neovim Modular Autocmd System

This directory contains a modular autocmd system for Neovim, providing better organization, performance, and maintainability.

## Architecture

The autocmd system is split into focused modules, each handling specific aspects of editor behavior:

```
autocmds/
├── core.lua         # Essential functionality
├── lsp.lua          # Language Server Protocol integration
├── performance.lua  # Performance optimizations
├── productivity.lua # Workflow enhancements
└── languages.lua    # Language-specific settings
```

## Modules

### Core (`core.lua`)
Essential autocmds that should always be loaded:
- **Automatic cleanup** - Trim whitespace, auto-save on focus lost
- **File management** - Auto-create directories, reload changed files
- **UI enhancements** - Cursorline management, highlight on yank, window resizing
- **Terminal integration** - Auto-insert mode, clean terminal UI
- **Git integration** - Commit message helpers
- **Error handling** - Quickfix window management, close windows with 'q'
- **Session management** - Restore cursor position

### LSP (`lsp.lua`)
All Language Server Protocol related autocmds:
- **Import organization** - Auto-organize imports on save
- **Document highlighting** - Highlight symbol references under cursor
- **Diagnostics display** - Smart diagnostic hover windows
- **Code lens management** - Safe code lens refresh with capability checking
- **Inlay hints** - Dynamic inlay hint toggling
- **LSP attach enhancements** - Format on save, omnifunc setup
- **Progress notifications** - LSP operation progress display
- **Workspace configuration** - Auto-reload LSP on config changes
- **Semantic tokens** - Enhanced syntax highlighting

### Performance (`performance.lua`)
Optimizations for better Neovim performance:
- **Large file handling** - Disable expensive features for files >1MB
- **Long line detection** - Warn and optimize for files with very long lines
- **Memory management** - Automatic buffer cleanup
- **Lazy loading** - Defer plugin loading until needed
- **Fold optimization** - Smart fold method selection based on file size
- **Undo/swap file management** - Clean up old files periodically
- **Treesitter performance** - Disable for large files
- **Completion optimization** - Smart preview window management
- **Diagnostic throttling** - Reduce diagnostic updates in insert mode

### Productivity (`productivity.lua`)
Workflow enhancements and automation:
- **Smart templates** - Boilerplate for new files (shell, Python, Dockerfile)
- **Test navigation** - Toggle between test and implementation files
- **Smart comments** - Highlight TODO, FIXME, NOTE, WARNING
- **URL handling** - Highlight and open URLs
- **Smart indent detection** - Auto-detect indentation style
- **Session management** - Save/restore folds (nvim-ufo aware)
- **Project settings** - Load `.nvim.lua` project configs
- **Quick notes** - Timestamped note-taking in markdown
- **Mason auto-update** - Optimized background package updates

### Languages (`languages.lua`)
Language-specific settings and keymaps:
- **Python** - Virtual environment activation, Black formatting
- **Go** - Import organization, go commands
- **Rust** - Cargo.toml reload, cargo commands
- **JavaScript/TypeScript** - NPM commands, 2-space indents
- **Lua** - Neovim config reload helpers
- **Shell** - Make executable, shellcheck integration
- **Docker** - Docker build/run commands
- **Terraform** - Terraform commands, HCL formatting
- **Ansible** - Playbook commands, ansible-lint
- **Markdown** - Spell check, preview commands
- **DevOps formats** - YAML/JSON 2-space indents, Makefile tabs

## Configuration

Edit the configuration in `~/.config/nvim/lua/config/autocmds.lua`:

```lua
local config = {
  -- Module loading (disable modules you don't need)
  load_core = true,
  load_lsp = true,
  load_performance = true,
  load_productivity = true,
  load_languages = true,

  -- Feature flags
  auto_refresh_codelens = false,    -- May cause issues with some LSPs
  toggle_inlay_hints_on_insert = false,
  mason_auto_update = true,
  smart_fold_management = true,
}
```

## Adding New Autocmds

1. Identify the appropriate module for your autocmd
2. Add it to the relevant file (e.g., `lsp.lua` for LSP-related autocmds)
3. Use the module's `augroup` function for consistent naming:

```lua
vim.api.nvim_create_autocmd("EventName", {
  group = augroup("your_group_name"),
  pattern = "*.lua",
  callback = function()
    -- Your autocmd logic here
  end,
})
```

## Debugging

Useful commands for debugging autocmds:

```vim
:verbose autocmd BufWritePre  " Show all BufWritePre autocmds
:verbose autocmd lsp_*         " Show all LSP autocmds
:autocmd! core_*               " Remove all core autocmds
:autocmd                       " List all autocmds
```

## Performance Tips

1. **Disable unused modules** - Set `load_<module> = false` for modules you don't need
2. **Adjust thresholds** - Modify large file size limits in `performance.lua`
3. **Feature flags** - Disable expensive features like `auto_refresh_codelens`
4. **Monitor impact** - Use `:profile` to measure autocmd performance

## Troubleshooting

### Common Issues

**Autocmds not loading:**
- Check if the module is enabled in config
- Look for error messages with `:messages`
- Verify file paths are correct

**Performance issues:**
- Disable `load_performance = false` to test without optimizations
- Check for conflicting autocmds with `:verbose autocmd`
- Profile with `:profile start profile.log` and `:profile stop`

**LSP conflicts:**
- Set `auto_refresh_codelens = false` if experiencing LSP errors
- Disable `toggle_inlay_hints_on_insert` for problematic servers

## Migration from Old Setup

The previous monolithic `autocmds.lua` has been replaced with this modular system. All existing autocmds have been preserved and organized into appropriate modules. The old file now serves as a loader for the modular system.

Benefits of the new system:
- ✅ Better organization and maintainability
- ✅ Improved performance through conditional loading
- ✅ Easier debugging with module isolation
- ✅ No duplicate LSP autocmds
- ✅ Optimized Mason updates
- ✅ nvim-ufo aware fold management
- ✅ Safe code lens refresh

## Contributing

When adding new autocmds:
1. Follow the existing module structure
2. Use descriptive group names
3. Add error handling with `pcall` for critical operations
4. Document complex autocmds with comments
5. Test with both modules enabled and disabled