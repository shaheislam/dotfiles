# Git Local Exclude Management System

This directory contains tools and templates for managing local git excludes across multiple repositories.

## What is `.git/info/exclude`?

`.git/info/exclude` is Git's **local gitignore** file that:
- Works exactly like `.gitignore` but is **never committed**
- Perfect for personal configurations that shouldn't affect team members
- Stays local to your machine only

## Quick Start

### Setup all repos in ~/work
```bash
gitlocal-setup
```

### Setup a specific directory
```bash
gitlocal-setup ~/projects
```

### Dry run to see what would be done
```bash
gitlocal-setup --dry-run
```

### Add custom patterns to all repos
```bash
gitlocal-setup --add-pattern "*.myconfig"
```

## What the Setup Does

For each git repository, the script:

1. **Creates `.git/info/exclude`** if it doesn't exist
2. **Creates `.gitignore_local`** symlink pointing to `.git/info/exclude`
3. **Adds common patterns** that should be excluded locally:
   - `.gitignore_local` (the symlink itself)
   - `*.local` files
   - Editor configs (`.vscode/`, `.idea/`, `.claude/`, `.codex/`)
   - Language-specific configs (`.pyrightconfig.json`, etc.)
   - Personal notes and scripts

## Directory Structure

```
.config/git-local/
├── README.md                 # This file
├── default-excludes.txt      # Default patterns added to all repos
└── templates/                # Config templates for different languages
    ├── python/
    │   └── pyrightconfig.json
    ├── javascript/
    │   └── eslintrc.local.json
    └── common/
        └── (shared templates)
```

## Using Templates

Copy templates to your project and they'll be automatically ignored:

### Python Project
```bash
cp ~/.config/git-local/templates/python/pyrightconfig.json ~/work/my-project/
```

### JavaScript Project
```bash
cp ~/.config/git-local/templates/javascript/eslintrc.local.json ~/work/my-project/.eslintrc.local.json
```

## Manual Management

If you prefer to manage individual repos:

### Add pattern to local exclude
```bash
echo "*.mypattern" >> .gitignore_local
```

### Edit local excludes
```bash
nvim .gitignore_local
```

### Check what's excluded locally
```bash
cat .gitignore_local
```

## Benefits

1. **Team-Friendly**: Your personal configs don't pollute the shared repository
2. **Convenient**: `.gitignore_local` symlink makes editing easy
3. **Consistent**: Same setup across all your repos
4. **Safe**: Won't overwrite existing configurations
5. **Flexible**: Add project-specific patterns as needed

## Common Use Cases

### LSP Configurations
Keep your editor's language server configs local:
- `.pyrightconfig.json` for Python
- `tsconfig.local.json` for TypeScript
- `.eslintrc.local.json` for JavaScript

### Personal Scripts
Store helper scripts without committing them:
- `.scripts/` directory for automation
- `local-scripts/` for project-specific tools

### Environment Files
Keep sensitive or personal environment variables:
- `.env.local`
- `.env.development.local`

### Personal Notes
Track your TODOs and notes:
- `TODO.local.md`
- `NOTES.md`
- `.notes/` directory

## Troubleshooting

### Symlink already exists but points elsewhere
The script will automatically fix incorrect symlinks.

### Permission denied
Make sure you have write access to the repository directories.

### Changes still showing in `git status`
If files were already tracked before being added to exclude:
```bash
git rm --cached <filename>
```

## Integration with Other Tools

This system works seamlessly with:
- **Fish shell**: `gitlocal-setup` function available globally
- **Neovim/LazyVim**: LSP configs automatically ignored
- **VS Code**: `.vscode/` directory ignored by default

## Maintenance

### Re-run to catch new repos
```bash
gitlocal-setup
```

### Update patterns in all repos
```bash
gitlocal-setup --add-pattern "*.newpattern"
```

### Check setup status
```bash
gitlocal-setup --dry-run
```

## Tips

1. **Run regularly**: Add to your weekly maintenance routine
2. **Use templates**: Copy from `templates/` for consistency
3. **Document patterns**: Add comments in `.gitignore_local`
4. **Share selectively**: Some patterns might be worth adding to the real `.gitignore`

## Related Commands

- `git status --ignored` - Show ignored files
- `git check-ignore <file>` - Check if a file is ignored
- `git clean -ndX` - Preview what ignored files would be removed