# Testing Conventions

## Shell Script Validation

- Fish functions: `fish --no-execute <file>` for syntax checking
- Bash scripts: `bash -n <file>` for syntax checking
- ShellCheck: `shellcheck <file>` for linting (Bash scripts only)

## Stow Testing

- Always run `stow --simulate --verbose .` before actual stow operations
- Verify symlinks resolve correctly after stow: `ls -la ~/.<config>`
- Test stow in a clean state: resolve conflicts before deploying

## Integration Testing

- Cross-platform testing via Docker containers (`scripts/docker/`)
- Use Colima + Docker for macOS container testing
- Test scripts should verify: installation, PATH setup, config loading

## What to Validate Before Committing

1. **Fish syntax**: `fish --no-execute` on all changed `.fish` files
2. **Bash syntax**: `bash -n` on all changed `.sh` files
3. **Stow**: `stow --simulate .` succeeds without conflicts
4. **Theme**: Tokyo Night colors consistent in new config files
5. **Paths**: New tool paths added to both Fish and Zsh configs

## When Tests Don't Exist

- For new Fish functions: at minimum verify syntax with `fish --no-execute`
- For new scripts: at minimum verify syntax with `bash -n`
- For config changes: manually verify the application loads the config
