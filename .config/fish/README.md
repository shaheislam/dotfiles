# Fish Shell Configuration

This Fish shell configuration replicates all the functionality from your `.zshrc` file. Here's what has been translated:

## Main Configuration (`config.fish`)

### ✅ Features Migrated from Zsh:

- **Starship prompt** - Same beautiful prompt you're used to
- **Environment variables** - All PATH additions and BAT_THEME
- **Tool initializations** - zoxide, direnv, atuin, asdf
- **FZF configuration** - Same theme colors and commands
- **Aliases** - All your aliases (python, cd, ls, cat, k)
- **Custom functions** - `code()` and `aws-sso()` functions
- **thefuck integration** - Same functionality

## Plugin Configuration (`conf.d/plugins.fish`)

### ✅ Oh My Zsh Plugins Replaced:

| Zsh Plugin                     | Fish Equivalent                          | Status        |
| ------------------------------ | ---------------------------------------- | ------------- |
| `git`                          | Git abbreviations + built-in completions | ✅ Configured |
| `zsh-completions`              | Fish built-in completions                | ✅ Built-in   |
| `fzf-tab`                      | FZF integration with previews            | ✅ Configured |
| `zsh-kubectl-prompt`           | kubectl completion + abbreviations       | ✅ Configured |
| `docker-zsh-completion`        | Fish built-in docker completions         | ✅ Built-in   |
| `zsh-syntax-highlighting`      | Fish built-in syntax highlighting        | ✅ Configured |
| `zsh-autosuggestions`          | Fish built-in autosuggestions            | ✅ Enabled    |
| `zsh-history-substring-search` | Fish built-in (up/down arrows)           | ✅ Built-in   |

### ✅ Additional Features:

- **Git+FZF integration** - Fish-native functions replacing `fzf-git.sh`:
  - `gb_fzf` - Browse and select git branches with preview
  - `gc_fzf` - Browse and select git commits with preview
  - `gf_fzf` - Browse and select git files with preview
  - `gm_fzf` - Browse modified files with git diff preview

## Key Differences from Zsh

### Advantages of Fish:

1. **Built-in features** - No need for plugins for syntax highlighting, autosuggestions, etc.
2. **Better tab completion** - Intelligent completions out of the box
3. **Simpler syntax** - More readable configuration
4. **Better defaults** - Sane defaults without configuration

### New Shortcuts & Abbreviations:

- **Git**: `g`, `ga`, `gc`, `gp`, `gst`, etc.
- **Git+FZF**: `gb_fzf`, `gc_fzf`, `gf_fzf`, `gm_fzf`
- **Kubectl**: `kgp`, `kgs`, `kgd`, `kaf`, etc.
- **History search**: `Ctrl+R` for FZF history search
- **File search**: `Ctrl+T` for FZF file search
- **Directory navigation**: `Alt+C` for FZF directory search

## How to Switch to Fish

1. **Install Fish** (if not already installed):

   ```bash
   brew install fish
   ```

2. **Test the configuration**:

   ```bash
   fish
   ```

3. **Make Fish your default shell**:

   ```bash
   echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
   chsh -s /opt/homebrew/bin/fish
   ```

4. **Restart your terminal** or open a new tab

## Additional Fish Features

### Abbreviations vs Aliases

Fish uses abbreviations (`abbr`) which expand when you type them, showing you the full command. This is more transparent than aliases.

### Web-based Configuration

Run `fish_config` to open a web interface for customizing colors, prompts, and more.

### Package Manager (Optional)

Consider installing [Fisher](https://github.com/jorgebucaran/fisher) for additional plugins:

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
```

## Troubleshooting

If something doesn't work as expected:

1. Check that all tools (starship, zoxide, etc.) are still installed
2. Reload the configuration: `source ~/.config/fish/config.fish`
3. Check Fish syntax: Fish is stricter about syntax than Zsh

### Common Issues:

- **mise warnings** (e.g., "missing: terraform@1.7.4") are just informational and won't prevent Fish from working
- **fzf-git.sh compatibility**: The original `fzf-git.sh` is bash/zsh-specific and has been replaced with Fish-native functions
- **Syntax errors**: Make sure you're not mixing bash/zsh syntax in Fish configuration

## Going Back to Zsh

If you want to switch back to Zsh:

```bash
chsh -s /bin/zsh
```

Your original `.zshrc` is unchanged and will work as before.
