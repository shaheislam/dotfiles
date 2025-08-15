# Vet - Safe Remote Script Execution

**vet** is a security tool that acts as a safety net for the risky `curl | bash` pattern. It downloads, analyzes, and requires approval before executing remote scripts.

## Installation

Already installed in your dotfiles! Available commands:
- `vet` - Main command for safe script execution
- `vetf` - Alias for `vet --force` (skips prompts - use with caution!)

## How Vet Works

1. **Downloads** the script to a temporary location
2. **Analyzes** with ShellCheck for potential issues
3. **Shows** you the script content for review
4. **Prompts** for confirmation before execution
5. **Tracks** changes between script versions

## Basic Usage Examples

### 1. Basic Script Execution
```bash
# Instead of: curl -fsSL https://example.com/install.sh | bash
vet https://example.com/install.sh
```

### 2. With Script Arguments
```bash
# Pass arguments to the remote script
vet https://example.com/setup.sh --user myuser --version latest
```

### 3. Force Mode (Skip Prompts)
```bash
# Use only in trusted environments!
vet --force https://trusted-source.com/script.sh
# Or use the alias:
vetf https://trusted-source.com/script.sh
```

## Real-World Examples

### Install Node.js via NVM
```bash
# Unsafe way:
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Safe way with vet:
vet https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh
```

### Install Docker
```bash
# Instead of Docker's "convenience script":
vet https://get.docker.com/
```

### Install Rust
```bash
# Safe Rust installation:
vet https://sh.rustup.rs/
```

### Install Oh-My-Zsh
```bash
# Safe Oh-My-Zsh installation:
vet https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
```

### AWS CLI Installation Script
```bash
# Review AWS CLI install script before running:
vet https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.install.sh
```

## Advanced Usage

### Environment Variables
```bash
# Scripts can still use environment variables
export NODE_VERSION=18.20.0
vet https://nodejs.org/dist/install.sh
```

### Complex Arguments
```bash
# Scripts with complex arguments
vet https://example.com/setup.sh \
    --config /path/to/config.json \
    --env production \
    --features "ssl,monitoring,backup"
```

### Pipeline Integration
```bash
# Use in scripts with error handling
if vet https://example.com/verify-system.sh; then
    echo "System verification passed"
    vet https://example.com/deploy.sh
else
    echo "System verification failed"
    exit 1
fi
```

## What Vet Shows You

When you run vet, you'll see:

1. **Download Progress**: `==> Downloading script from: URL`
2. **ShellCheck Analysis**: Potential issues and warnings
3. **Script Content**: Full script source for review
4. **Approval Prompt**: `[?] Execute this script? [y/N]`

## Safety Features

### ShellCheck Integration
- Automatically runs `shellcheck` on downloaded scripts
- Warns about potential security issues, bugs, and bad practices
- Shows specific line numbers and explanations

### Change Detection
- Tracks script versions and changes
- Shows diff when scripts are updated
- Helps detect malicious modifications

### User Control
- Always requires explicit approval (unless using `--force`)
- Shows full script content before execution
- Allows you to cancel at any time

## Best Practices

### ✅ DO Use Vet When:
- Installing software from `curl | bash` instructions
- Running setup scripts from GitHub repositories
- Executing deployment or configuration scripts
- Any time you're running remote code

### ⚠️ BE CAREFUL With:
- `--force` flag - only use in trusted, automated environments
- Scripts from untrusted sources
- Scripts that modify system files or install software

### ❌ DON'T:
- Blindly approve scripts without reading them
- Use `--force` for untrusted scripts
- Ignore ShellCheck warnings without understanding them

## Integration with Existing Workflow

### Replace Dangerous Patterns
```bash
# OLD (dangerous):
curl -fsSL https://example.com/install.sh | bash

# NEW (safe):
vet https://example.com/install.sh
```

### In Your Scripts
```bash
#!/bin/bash
# Use vet in your own scripts for safety

echo "Installing dependencies..."
vet https://nodejs.org/install.sh --version 18

echo "Setting up development environment..."
vet https://raw.githubusercontent.com/company/setup/main/dev-setup.sh
```

### CI/CD Integration
```bash
# In CI/CD, you might use force mode for trusted scripts
if [[ "$CI" == "true" && "$TRUSTED_ENVIRONMENT" == "true" ]]; then
    vetf https://trusted-internal.com/deploy.sh
else
    vet https://trusted-internal.com/deploy.sh
fi
```

## Troubleshooting

### Script Fails ShellCheck
- Review the warnings carefully
- Some warnings might be false positives for your use case
- You can still proceed if you understand and accept the risks

### Script Won't Execute
- Check that the URL is accessible
- Verify the script has proper shebang (`#!/bin/bash`)
- Ensure your network allows the download

### Need to Re-run
- Vet caches scripts temporarily
- If you need to re-download, wait a moment or restart your shell

## Security Benefits

1. **Visibility**: See exactly what code will run
2. **Analysis**: Automatic detection of common issues  
3. **Control**: Explicit approval before execution
4. **Tracking**: Know when scripts change
5. **Safety**: No more blind `curl | bash`

## Performance Notes

- Scripts are downloaded to temporary storage first
- Minimal overhead for analysis
- ShellCheck analysis is fast and cached
- No impact on script execution performance once approved

Remember: **vet** makes the dangerous `curl | bash` pattern safe by giving you visibility and control over remote script execution!
