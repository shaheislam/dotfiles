# Tokyo Night Theme Specification

Canonical color reference for maintaining Tokyo Night consistency across all applications.

## Core Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background | `#1a1b26` | Terminal bg, editor bg |
| Background Alt | `#24283b` | Sidebars, panels, selection |
| Foreground | `#c0caf5` | Default text |
| Comment | `#565f89` | Comments, subtle text |
| Blue | `#7aa2f7` | Functions, links |
| Cyan | `#7dcfff` | Types, parameters |
| Green | `#9ece6a` | Strings, success |
| Magenta | `#bb9af7` | Keywords, constants |
| Red | `#f7768e` | Errors, deletions |
| Yellow | `#e0af68` | Warnings, modifications |
| Orange | `#ff9e64` | Numbers, special |

## Application Configs

| App | Config Location | Theme Setting |
|-----|----------------|---------------|
| Ghostty | `.config/ghostty/config` | `theme = tokyonight` |
| WezTerm | `.config/wezterm/wezterm.lua` | `color_scheme = "Tokyo Night"` |
| tmux | `.tmux.conf` | Status bar colors from palette |
| Fish | `.config/fish/` | Prompt colors from palette |
| bat | `.config/bat/config` | `--theme="tokyonight_night"` |
| fzf | Fish/Zsh config | FZF_DEFAULT_OPTS with palette colors |
| lazygit | `.config/lazygit/config.yml` | Theme section with palette |
| delta | `.gitconfig` | syntax-theme = tokyonight |

## When Adding New Tools

1. Check if the tool supports Tokyo Night natively
2. If yes: use the built-in theme name
3. If no: manually configure using the Core Palette above
4. Test visual consistency with adjacent UI elements
