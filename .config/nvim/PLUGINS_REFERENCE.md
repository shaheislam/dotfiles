# Neovim Plugins Reference Guide

Complete reference of all Neovim plugins in your configuration, organized by category.

## Table of Contents
- [Currently Installed Plugins](#currently-installed-plugins)
- [File Management](#file-management)
- [Navigation & Movement](#navigation--movement)
- [Editing & Text Manipulation](#editing--text-manipulation)
- [Git Integration](#git-integration)
- [LSP & Development](#lsp--development)
- [UI & Aesthetics](#ui--aesthetics)
- [Search & Replace](#search--replace)
- [Session & Project Management](#session--project-management)
- [DevOps & Infrastructure](#devops--infrastructure)
- [Testing & Debugging](#testing--debugging)
- [Documentation & Diagrams](#documentation--diagrams)
- [Productivity Enhancements](#productivity-enhancements)
- [LazyVim Extras Available](#lazyvim-extras-available)

---

## Currently Installed Plugins

These plugins are currently active in your Neovim setup (from lazy-lock.json):

### Core Framework
- **LazyVim** - Modern Neovim configuration framework
- **lazy.nvim** - Fast plugin manager for Neovim
- **lazydev.nvim** - Neovim development setup

### Completion & Snippets
- **blink.cmp** - Completion engine
- **friendly-snippets** - Collection of snippets for various languages

### UI Components
- **bufferline.nvim** - Visual buffer tabs
- **lualine.nvim** - Fast statusline
- **noice.nvim** - Better UI for messages, cmdline, popupmenu
- **nui.nvim** - UI component library
- **tokyonight.nvim** - Tokyo Night colorscheme (your active theme)
- **catppuccin** - Alternative colorscheme

### File Browsing
- **oil.nvim** - File explorer as buffer (your primary file browser)
- **nvim-web-devicons** - File type icons

### Navigation
- **harpoon** - Quick file navigation (ThePrimeagen's plugin)
- **flash.nvim** - Enhanced character motions
- **telescope.nvim** - Fuzzy finder
- **telescope-fzf-native.nvim** - FZF sorter for telescope
- **fzf** & **fzf.vim** - Command-line fuzzy finder integration

### Git
- **vim-fugitive** - Git commands in Neovim
- **vim-rhubarb** - GitHub integration for fugitive
- **toggleterm.nvim** - Terminal integration (for lazygit/lazydocker)

### Editing Enhancements
- **vim-cutlass** - Separate cut and delete operations
- **vim-yoink** - Yank history cycling
- **vim-subversive** - Substitute operator motions
- **vim-ReplaceWithRegister** - Replace text with register content
- **vim-ReplaceWithSameIndentRegister** - Replace with indent preservation
- **vim-visualrepeat** - Repeat for visual selections
- **vim-sort-motion** - Sort text objects
- **vim-abolish** - Case conversion and abbreviation
- **vim-sleuth** - Auto-detect indentation
- **vim-surround** - Surround text with pairs
- **vim-repeat** - Better repeat with '.'

### Treesitter
- **nvim-treesitter** - Syntax highlighting and code understanding
- **nvim-treesitter-textobjects** - Text objects based on syntax tree
- **nvim-ts-autotag** - Auto close/rename HTML tags
- **ts-comments.nvim** - Context-aware commenting

### LSP & Formatting
- **nvim-lspconfig** - LSP configurations
- **mason.nvim** - LSP/formatter/linter installer
- **mason-lspconfig.nvim** - Bridge between mason and lspconfig
- **conform.nvim** - Formatter plugin
- **nvim-lint** - Linter integration

### Search & Analysis
- **grug-far.nvim** - Find and replace across files
- **nvim-spectre** - Search and replace panel
- **todo-comments.nvim** - Highlight TODO/FIXME comments
- **trouble.nvim** - Pretty diagnostics list

### Visual Enhancements
- **vim-css-color** - Color preview in CSS
- **rainbow_parentheses.vim** - Colored bracket pairs
- **vim-indent-guides** - Visual indent guides
- **vim-indent-object** - Text object for indentation
- **vim-smoothie** - Smooth scrolling

### Movement
- **vim-easymotion** - Fast cursor movement
- **vim-mundo** - Undo tree visualization
- **vim-peekaboo** - Register preview
- **vim-rsi** - Readline keybindings

### Project Management
- **project.nvim** - Project detection and switching
- **persistence.nvim** - Session management
- **obsidian.nvim** - Obsidian vault integration

### Mini.nvim Suite
- **mini.ai** - Better text objects
- **mini.icons** - Icon provider
- **mini.nvim** - Collection of minimal plugins
- **mini.pairs** - Auto pairs

### Special File Support
- **vim-terraform** - Terraform file support
- **render-markdown.nvim** - Markdown rendering
- **sixelview.nvim** - Image viewing in terminal

### Utility
- **plenary.nvim** - Lua utility library (dependency for many plugins)
- **snacks.nvim** - Collection of small utilities
- **which-key.nvim** - Keybinding helper

---

## Plugins by Category (Including Recommended)

### File Management
- ✅ **oil.nvim** - Edit filesystem like a buffer
- ✅ **telescope.nvim** - Fuzzy file finder
- 🔲 **mini.files** - Alternative floating file explorer
- 🔲 **neo-tree.nvim** - Tree-style file explorer (disabled)

### Navigation & Movement
- ✅ **harpoon** - Quick file switching (Ctrl+1/2/3/4)
- ✅ **flash.nvim** / **leap.nvim** - Jump to any character
- ✅ **vim-easymotion** - Quick cursor movement
- 🔲 **smart-splits.nvim** - Better window navigation
- 🔲 **aerial.nvim** - Code outline navigation

### Editing & Text Manipulation
- ✅ **vim-surround** - Change surrounding pairs
- ✅ **vim-cutlass/yoink/subversive** - Advanced clipboard
- ✅ **vim-abolish** - Case coercion
- 🔲 **Comment.nvim** - Smart commenting (gcc)
- 🔲 **mini.surround** - Alternative surround
- 🔲 **refactoring.nvim** - Code refactoring tools

### Git Integration
- ✅ **vim-fugitive** - Git commands
- ✅ **toggleterm.nvim** - LazyGit/LazyDocker integration
- 🔲 **gitsigns.nvim** - Git decorations (disabled)
- 🔲 **gitui** - Terminal UI for git
- 🔲 **mini.diff** - Inline diff indicators

### LSP & Development

#### Language Servers (Configured)
- 🔲 **terraform-ls** - Terraform
- 🔲 **ansible-language-server** - Ansible
- 🔲 **helm-ls** - Helm charts
- 🔲 **dockerfile-language-server** - Docker
- 🔲 **yaml-language-server** - YAML with schemas
- 🔲 **pyright** - Python
- 🔲 **gopls** - Go
- 🔲 **rust-analyzer** - Rust
- 🔲 **bash-language-server** - Shell scripts
- 🔲 **sqlls** - SQL

### UI & Aesthetics
- ✅ **tokyonight.nvim** - Current theme
- ✅ **bufferline.nvim** - Buffer tabs
- ✅ **lualine.nvim** - Status line
- 🔲 **indent-blankline.nvim** - Indent guides
- 🔲 **nvim-notify** - Notification popups
- 🔲 **alpha.nvim** - Dashboard
- 🔲 **zen-mode.nvim** - Distraction-free mode

### Testing & Debugging
- 🔲 **nvim-dap** - Debug Adapter Protocol
- 🔲 **nvim-dap-ui** - DAP UI
- 🔲 **neotest** - Test runner
- 🔲 **vim-test** - Alternative test runner

### DevOps & Infrastructure

#### Cloud Providers
- 🔲 **vim-cloudformation** - AWS CloudFormation
- 🔲 **vim-azurearmtemplate** - Azure ARM
- 🔲 **vim-consul** - HashiCorp Consul
- 🔲 **pulumi-lsp** - Pulumi IaC

#### CI/CD
- 🔲 **github-actions-yaml.vim** - GitHub Actions
- 🔲 **vim-gitlab-ci** - GitLab CI
- 🔲 **Jenkinsfile-vim-syntax** - Jenkins

#### Monitoring
- 🔲 **vim-prometheus** - Prometheus/PromQL
- 🔲 **vim-grafana** - Grafana dashboards
- 🔲 **vim-log-highlighting** - Log files

#### Networking
- 🔲 **nginx.vim** - nginx config
- 🔲 **apachestyle** - Apache config
- 🔲 **vim-openapi** - OpenAPI/Swagger

#### Containers & Orchestration
- 🔲 **vim-docker-tools** - Docker management
- 🔲 **vimkubectl** - Kubernetes control

### Documentation & Diagrams
- ✅ **render-markdown.nvim** - Markdown preview
- 🔲 **plantuml-previewer.vim** - UML diagrams
- 🔲 **mermaid.vim** - Mermaid diagrams
- 🔲 **venn.nvim** - ASCII diagrams
- 🔲 **neogen** - Generate annotations

### Database & API
- 🔲 **vim-dadbod** - Database client
- 🔲 **rest.nvim** - REST client

### Configuration Files
- 🔲 **vim-jsonnet** - Jsonnet support
- 🔲 **dhall-vim** - Dhall language
- 🔲 **vim-dotenv** - .env files
- 🔲 **vim-ssh-config** - SSH configs
- 🔲 **vim-systemd-syntax** - Systemd units
- 🔲 **crontab.vim** - Crontab files

### AI Assistance
- 🔲 **codeium.vim** - Free AI autocomplete (alternative to Copilot)
- 🔲 **ChatGPT.nvim** - ChatGPT integration (optional)

---

## LazyVim Extras Available

These are built-in LazyVim modules you can enable:

### Coding Extras
- `lazyvim.plugins.extras.coding.mini-surround`
- `lazyvim.plugins.extras.coding.neogen`
- `lazyvim.plugins.extras.coding.yanky`
- `lazyvim.plugins.extras.coding.luasnip`

### Editor Extras
- `lazyvim.plugins.extras.editor.aerial`
- `lazyvim.plugins.extras.editor.dial`
- `lazyvim.plugins.extras.editor.inc-rename`
- `lazyvim.plugins.extras.editor.leap`
- `lazyvim.plugins.extras.editor.mini-diff`
- `lazyvim.plugins.extras.editor.navic`
- `lazyvim.plugins.extras.editor.outline`
- `lazyvim.plugins.extras.editor.refactoring`

### UI Extras
- `lazyvim.plugins.extras.ui.alpha`
- `lazyvim.plugins.extras.ui.mini-animate`
- `lazyvim.plugins.extras.ui.mini-indentscope`
- `lazyvim.plugins.extras.ui.treesitter-context`

### Utility Extras
- `lazyvim.plugins.extras.util.dot`
- `lazyvim.plugins.extras.util.gitui`
- `lazyvim.plugins.extras.util.mini-hipatterns`
- `lazyvim.plugins.extras.util.project`
- `lazyvim.plugins.extras.util.rest`

### Language Extras (DevOps relevant)
- `lazyvim.plugins.extras.lang.terraform`
- `lazyvim.plugins.extras.lang.ansible`
- `lazyvim.plugins.extras.lang.docker`
- `lazyvim.plugins.extras.lang.helm`
- `lazyvim.plugins.extras.lang.yaml`
- `lazyvim.plugins.extras.lang.json`
- `lazyvim.plugins.extras.lang.python`
- `lazyvim.plugins.extras.lang.go`
- `lazyvim.plugins.extras.lang.rust`
- `lazyvim.plugins.extras.lang.sql`

---

## Key Plugins to Study

### Essential for DevOps
1. **telescope.nvim** - Master the fuzzy finder
2. **oil.nvim** - File management as text
3. **vim-fugitive** - Git integration
4. **nvim-lspconfig** - Language server protocol
5. **conform.nvim** - Auto-formatting

### Productivity Boosters
1. **harpoon** - Quick file switching
2. **vim-surround** - Text manipulation
3. **telescope.nvim** - Fuzzy finding everything
4. **which-key.nvim** - Learn keybindings
5. **todo-comments.nvim** - Track TODOs

### Advanced Features
1. **nvim-dap** - Debugging
2. **neotest** - Test running
3. **rest.nvim** - API testing
4. **vim-dadbod** - Database queries
5. **refactoring.nvim** - Code refactoring

---

## Legend
- ✅ Currently installed and active
- 🔲 Configured but not yet installed/activated
- ❌ Disabled or removed

---

## How to Enable Plugins

1. **For plugins in config files**: Run `:Lazy sync` in Neovim
2. **For LazyVim extras**: Use `:LazyExtras` or edit `lazyvim.json`
3. **For missing LSPs**: They'll auto-install via Mason on first use

---

## Quick Reference Commands

- `:Lazy` - Plugin manager UI
- `:Mason` - LSP/formatter/linter installer
- `:LazyExtras` - Enable/disable LazyVim extras
- `:checkhealth` - Verify plugin health
- `:Telescope keymaps` - Browse all keybindings