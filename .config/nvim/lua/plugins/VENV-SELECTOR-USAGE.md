# Venv-Selector.nvim Usage Guide

## Overview
The `venv-selector.nvim` plugin has been properly configured for managing Python virtual environments within Neovim.

## Key Bindings
- `<leader>vs` - Open virtual environment selector (`:VenvSelect`)
- `<leader>vc` - Select from cached virtual environments (`:VenvSelectCached`)

## Features
- **Automatic Detection**: Searches for virtual environments in:
  - `.venv`, `venv`, `.virtualenv`, `virtualenv`, `env`, `.env` directories
  - Poetry environments (via `poetry env info`)
  - Pipenv environments (via `pipenv --venv`)
  - Searches in current directory and parent directory

- **Auto-Activation**: Automatically activates `.venv` when opening Python files if it exists

- **LSP Integration**: Automatically configures `basedpyright` LSP to use the selected environment

- **Notifications**: Shows a notification when switching environments

- **Telescope Integration**: Uses Telescope picker if available, falls back to native vim.ui.select

## How to Use

1. **Open a Python file** in a project with a virtual environment

2. **Select a virtual environment**:
   - Press `<leader>vs` (typically `<space>vs`)
   - Navigate through the telescope picker to find your environment
   - Press `<Enter>` to select

3. **The plugin will**:
   - Update the Python interpreter path
   - Restart the LSP server with the new environment
   - Show a notification confirming the switch

## Supported Virtual Environment Types
- Standard Python venv/virtualenv
- Poetry
- Pipenv
- Anaconda/Miniconda
- Pyenv
- Custom virtual environments

## Configuration Location
The plugin configuration is in: `.config/nvim/lua/plugins/venv-selector.lua`

## Troubleshooting
- Ensure `fd` is installed: `brew install fd`
- If Poetry environments aren't detected, ensure `poetry` is in your PATH
- If Pipenv environments aren't detected, ensure `pipenv` is in your PATH
- The plugin searches up to 2 parent directories by default
- LSP servers are automatically restarted when switching environments
- Check `:messages` for any error messages
- The plugin uses the `main` branch which is more stable

## Integration with Other Tools
- **basedpyright**: Automatically configured to use selected environment
- **ruff**: Works with the selected environment for linting
- **nvim-dap**: Debugger uses the selected Python interpreter

## Notes
- The plugin is installed from the `main` branch for stability
- Virtual environment changes persist for the current Neovim session
- The selected environment is shown in notifications after switching
- If a `.venv` directory exists, the plugin can auto-activate it when opening Python files
- The plugin integrates seamlessly with Telescope for a nice selection UI