# Docker Configuration

Best practice Docker configuration for macOS.

## Configuration

The `config.json` file includes:

- **`credsStore: "osxkeychain"`**: Uses macOS Keychain for secure credential storage
- **`currentContext: "colima"`**: Default Docker context (Colima instead of Docker Desktop)
- **`auths: {}`**: Authentication tokens stored securely in keychain, not in file

## Usage

This config is automatically symlinked via `stow`:

```bash
cd ~/dotfiles
stow .
```

Creates symlink: `~/.docker/config.json` → `~/dotfiles/.docker/config.json`

## Authentication

To authenticate with container registries:

```bash
# GitHub Container Registry (GHCR)
gh auth refresh -h github.com -s write:packages
echo $(gh auth token) | docker login ghcr.io -u <username> --password-stdin

# Docker Hub
docker login

# Other registries
docker login <registry-url> -u <username>
```

Credentials are stored in macOS Keychain via `osxkeychain`, not in this config file.

## Platform Notes

- **macOS**: Uses `osxkeychain`
- **Linux**: Would use `secretservice` or `pass`
- **Windows**: Would use `wincred`

This configuration is optimized for macOS.
