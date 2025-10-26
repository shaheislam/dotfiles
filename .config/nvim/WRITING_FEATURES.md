# Writing Features in LazyVim

This configuration includes writing-focused plugins integrated from [OVIWrite](https://miragiancycle.github.io/OVIWrite/).

## Integrated Writing Plugins

### LaTeX Editing
**Plugin**: `vimtex`
- Full LaTeX editing support with syntax highlighting
- PDF preview via Skim
- Compilation with latexmk
- Works with `.tex` and `.latex` files

**Usage**:
- `:VimtexCompile` - Compile LaTeX document
- `:VimtexView` - View PDF in Skim
- `:VimtexTocToggle` - Toggle table of contents

### Markdown → Document Conversion
**Plugin**: `auto-pandoc.nvim`
- Automatic Pandoc integration for Markdown files
- Convert Markdown to PDF, DOCX, HTML, and more
- Uses Pandoc (installed via Homebrew)

**Usage**:
- Works automatically with Markdown files
- Pandoc commands available via `:!pandoc` or configured keymaps

### Enhanced Markdown/Org Headers
**Plugin**: `headlines.nvim`
- Visual enhancements for Markdown and Org-mode headers
- Fat headlines with visual separators
- Better visual hierarchy

**Filetypes**: Markdown (`.md`), Org (`.org`)

### Typewriter Mode
**Plugin**: `stay-centered.nvim`
- Keeps cursor centered while writing (distraction-free)
- Reduces eye strain during long writing sessions
- Works across all file types

**Customization**:
Edit `~/.config/nvim/lua/plugins/writing.lua` to enable only for specific filetypes:
```lua
ft = { "markdown", "text", "org", "tex" },
```

### Writing Session Tracking
**Plugin**: `pendulum.nvim` ([ptdewey/pendulum-nvim](https://github.com/ptdewey/pendulum-nvim))
- Automatic time tracking for all file types
- Logs activity to CSV file (`~/pendulum-log.csv`)
- Tracks project, file, git branch, and idle time
- Privacy-focused (local-only data)

**Usage**:
- `:Pendulum` - Generate metrics view
- `:PendulumHours` - Show active hours view
- `:PendulumRebuild` - Recompile Go binary (if Go installed)

**Requirements**:
- Go (optional) - Required for report generation feature
- Install Go via: `brew install go`

**Log File Location**: `~/pendulum-log.csv`

### Smooth Scrolling
**Plugin**: `neoscroll.nvim`
- Smooth scrolling animations
- Better reading experience
- Works with standard Vim motions (`<C-u>`, `<C-d>`, etc.)

## Additional LazyVim Extras

### Org-Mode Support
Enable with LazyVim extra in `init.lua`:
```lua
{ import = "lazyvim.plugins.extras.lang.org" },
```

### Already Enabled
- **Markdown**: Full support via `lazyvim.plugins.extras.lang.markdown`
- **Prettier**: Formatting via `lazyvim.plugins.extras.formatting.prettier`

## Supported Writing Formats

| Format | Extension | Plugin | Purpose |
|--------|-----------|--------|---------|
| Markdown | `.md` | Built-in + headlines | General writing, notes, docs |
| LaTeX | `.tex`, `.latex` | vimtex | Academic papers, technical docs |
| Org-mode | `.org` | LazyVim extra (optional) | Task management, notes |
| Plain Text | `.txt` | Built-in | Simple notes |

## Writing Workflow Tips

### Distraction-Free Writing
1. Use `stay-centered.nvim` to keep cursor centered
2. Enter Zen mode: `:ZenMode` (if you have zen-mode.nvim)
3. Hide line numbers: `:set norelativenumber nonumber`

### Document Conversion (Markdown → PDF)
```bash
# From within Neovim
:!pandoc % -o output.pdf

# Or create a keymap in writing.lua
vim.keymap.set("n", "<leader>wp", ":!pandoc % -o %:r.pdf<CR>", { desc = "Convert to PDF" })
```

### LaTeX Workflow
1. Open `.tex` file
2. `:VimtexCompile` to start continuous compilation
3. `:VimtexView` to open in Skim
4. Edit and save - PDF auto-updates

## Customization

All writing plugins are configured in:
```
~/dotfiles/.config/nvim/lua/plugins/writing.lua
```

Edit this file to:
- Add custom keymaps
- Adjust plugin settings
- Enable/disable specific features
- Add additional writing plugins

## Learning Resources

- **Vim Basics**: Run `vimtutor` in terminal
- **VimTeX**: `:help vimtex`
- **Markdown**: LazyVim has excellent Markdown support built-in
- **Pandoc**: https://pandoc.org/MANUAL.html

---

**Installed**: 2025-01-26
**Source**: Integrated from OVIWrite into existing LazyVim configuration
