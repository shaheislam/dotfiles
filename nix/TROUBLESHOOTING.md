# Nix Troubleshooting Guide

## Reducing direnv/Nix Warnings on Directory Change

### Problem
When changing directories, you see numerous Nix warnings:
- "ignoring the client-specified setting"
- "ignoring untrusted substituter"
- "you are not a trusted user"
- "mismatch in field 'narHash'"

### Solutions Implemented

#### 1. direnv Configuration (`.config/direnv/direnv.toml`)
- **Disabled "taking a while" warnings**: Set `warn_timeout = "0s"`
- **Auto-whitelist home directory**: No more "direnv allow" prompts
- **Optimized caching**: Faster directory changes

#### 2. Suppress Non-Critical Warnings (`.envrc`)
- **Filter out trusted-user warnings**: These are noise in single-user setups
- **Keep critical warnings visible**: Lock file issues, eval errors still shown
- **Grep-based filtering**: Removes repetitive Nix multi-user warnings

### Optional: Become a Nix Trusted User (Complete Fix)

If you want to eliminate ALL warnings permanently:

1. **Edit system Nix config** (requires sudo):
   ```bash
   sudo nano /etc/nix/nix.conf
   ```

2. **Add yourself to trusted-users**:
   ```
   trusted-users = root shaheislam
   ```

3. **Restart Nix daemon**:
   ```bash
   sudo launchctl stop org.nixos.nix-daemon
   sudo launchctl start org.nixos.nix-daemon
   ```

4. **Verify**:
   ```bash
   cd ~/neovim  # Should be much quieter now
   ```

#### Why This Works
- Nix has a multi-user daemon that restricts non-root users by default
- Trusted users can modify restricted settings without warnings
- Single-user macOS installations rarely need this restriction
- Adding yourself to trusted-users is safe for personal machines

### Other Common Issues

#### Lock File Mismatches
**Symptom**: `mismatch in field 'narHash'`

**Solution**:
```bash
cd ~/dotfiles/nix/global
nix flake update --commit-lock-file
```

#### Slow Directory Changes
**Symptom**: direnv takes >5 seconds to load

**Solutions**:
1. Check if flake lock file is up to date
2. Enable Nix binary cache (already configured)
3. Use `direnv reload` to force cache update
4. Consider using `use_nix` instead of `use flake` for simpler projects

#### Missing Dependencies in Nix Shell
**Symptom**: LSPs or tools not found after `cd`

**Solutions**:
1. Verify flake.nix includes the package
2. Run `nix flake show` to see available packages
3. Check if direnv actually loaded: `echo $IN_NIX_SHELL`
4. Force reload: `direnv reload`

### Best Practices

1. **Keep flake.lock committed**: Ensures reproducible builds
2. **Use cachix for custom packages**: Faster builds, less compilation
3. **Pin nixpkgs versions**: Prevents surprise breakages on updates
4. **Test in clean environment**: Use `nix develop` directly before relying on direnv

### Performance Tuning

If direnv is still slow after these fixes:

1. **Enable more aggressive caching** in `direnv.toml`:
   ```toml
   [global]
   warn_timeout = "0s"
   load_dotenv = true
   strict_env = false  # Slightly faster, less secure
   ```

2. **Use `layout_dir` in .envrc** for project-specific cache:
   ```bash
   layout_dir=$HOME/.cache/direnv/layouts/$(basename $PWD)
   use flake ./nix/global
   ```

3. **Simplify flake.nix**: Remove unused inputs, minimize dependencies

### Verification

Test your changes:
```bash
# Should be fast and quiet now
cd ~/neovim
cd ~/dotfiles
cd ~/work/github-actions

# Check what's loaded
echo $PATH | tr ':' '\n' | grep nix
which lua-language-server
```

### Rollback

If something breaks, restore defaults:
```bash
# Remove direnv config
rm ~/.config/direnv/direnv.toml

# Restore simple .envrc
echo "use flake ./nix/global" > ~/.envrc

# Reload
direnv allow ~
```
