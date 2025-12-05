# Dotfiles Linux Testing with Colima

Container-based testing framework for validating dotfiles work correctly across multiple Linux distributions using Colima.

## Overview

This testing framework allows you to:
- ✅ Test dotfiles installation on Linux without a VM
- ✅ Validate configurations across multiple distributions
- ✅ Automate testing with repeatable containers
- ✅ Debug installation issues in isolated environments
- ✅ Develop Linux-compatible dotfiles from macOS

## Quick Start

### Prerequisites

- **Colima**: Container runtime (already installed ✓)
- **Docker CLI**: `brew install docker` (if not installed)
- **Dotfiles**: This repository cloned to `~/dotfiles`

### Run Your First Test

```bash
# 1. Start Colima
./scripts/docker/colima-setup.sh start

# 2. Build the Ubuntu test container
docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile \
  -t dotfiles-test:ubuntu .

# 3. Run the test suite
docker run --rm dotfiles-test:ubuntu \
  /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh

# 4. Or run interactive session
docker run -it --rm dotfiles-test:ubuntu
```

## Project Structure

```
scripts/docker/
├── README.md                    # This file
├── colima-setup.sh             # Colima management helper
├── build-netshoot-nvim.sh      # Build script for Neovim debug container
├── test-runner.sh              # Multi-distribution test orchestrator
├── .dockerignore               # Build optimization
│
├── dockerfiles/                # Distribution-specific Dockerfiles
│   ├── ubuntu.Dockerfile       # Ubuntu 22.04 LTS (primary)
│   ├── debian.Dockerfile       # Debian 12 Bookworm (stable)
│   ├── fedora.Dockerfile       # Fedora 40 (modern packages)
│   ├── arch.Dockerfile         # Arch Linux (bleeding edge)
│   ├── alpine.Dockerfile       # Alpine Linux (minimal/musl)
│   └── netshoot-nvim.Dockerfile # Kubernetes debug container with Neovim
│
├── scripts/                    # Test scripts
│   ├── run-all-tests.sh       # Main test orchestrator
│   ├── test-packages.sh       # Package manager tests
│   ├── test-stow.sh           # GNU Stow operations tests
│   ├── test-fish.sh           # Fish shell config tests
│   ├── test-zsh.sh            # Zsh shell config tests
│   └── test-setup.sh          # Setup script validation tests
│
├── docker-compose.test.yml     # Multi-distro parallel testing
└── docker-compose.dev.yml      # Interactive development environments
```

## Neovim + Netshoot Debug Container

A specialized Kubernetes debug container with Ubuntu 22.04 base, networking tools, Neovim with full plugin support, and DevOps-focused LSPs.

### Quick Start

```bash
# Build the image
./scripts/docker/build-netshoot-nvim.sh

# Run locally
docker run -it --rm netshoot-nvim:latest

# Use in Kubernetes
kubectl run debug --rm -it --image=netshoot-nvim:latest -- /bin/bash
```

### What's Included

| Category | Tools |
|----------|-------|
| **Base** | Ubuntu 22.04 (glibc - full plugin compatibility) |
| **Networking** | tcpdump, nmap, netcat, socat, iperf3, mtr, dig, traceroute, etc. |
| **Editor** | Neovim (latest stable) with 68 plugins via lazy.nvim |
| **LSPs** | yaml-ls, json-ls, dockerfile-ls, bash-ls, lua-ls (via Mason) |
| **Utilities** | ripgrep, fzf, fd, git, jq, yq, httpie |

### Why Ubuntu Instead of Alpine/Netshoot?

- **Full plugin compatibility** - blink.cmp, blink.pairs work out of the box
- **Treesitter** - C compiler available for parser compilation
- **Mason.nvim** - Pre-built LSP binaries work on glibc
- **No musl issues** - All Rust/Go binaries work correctly

### Use Cases

- Edit Kubernetes manifests directly in a debug pod with full LSP support
- Network debugging with professional tooling
- Troubleshoot container networking issues with Neovim for notes/configs

### Image Size

~1.0-1.2GB (Ubuntu + build tools + Neovim + plugins + LSPs)

---

## Colima Management

The `colima-setup.sh` script simplifies Colima operations:

```bash
# Start Colima with optimal settings
./scripts/docker/colima-setup.sh start

# Check Colima status
./scripts/docker/colima-setup.sh status

# Show detailed info
./scripts/docker/colima-setup.sh info

# Stop Colima
./scripts/docker/colima-setup.sh stop

# Restart Colima
./scripts/docker/colima-setup.sh restart

# Custom resource allocation
COLIMA_CPU=8 COLIMA_MEMORY=16 ./scripts/docker/colima-setup.sh start
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COLIMA_CPU` | 4 | Number of CPUs |
| `COLIMA_MEMORY` | 8 | Memory in GB |
| `COLIMA_DISK` | 50 | Disk size in GB |
| `COLIMA_ARCH` | auto | Architecture (aarch64/x86_64) |

## Multi-Distribution Testing

### Quick Test All Distributions

Use the test runner script for coordinated multi-distribution testing:

```bash
# Test all distributions sequentially
./scripts/docker/test-runner.sh

# Test all distributions in parallel (faster)
./scripts/docker/test-runner.sh --parallel

# Test specific distributions only
./scripts/docker/test-runner.sh ubuntu debian

# Build images only, don't run tests
./scripts/docker/test-runner.sh --build-only

# Test only (skip builds)
./scripts/docker/test-runner.sh --test-only

# Verbose output for debugging
./scripts/docker/test-runner.sh --verbose

# Clean and rebuild everything
./scripts/docker/test-runner.sh --clean --build-only
```

### Docker Compose Orchestration

#### Parallel Testing Across All Distributions

```bash
# Build all images
docker-compose -f scripts/docker/docker-compose.test.yml build

# Run tests on all distributions in parallel
docker-compose -f scripts/docker/docker-compose.test.yml up --abort-on-container-exit

# Test specific distribution
docker-compose -f scripts/docker/docker-compose.test.yml up test-ubuntu

# Clean up
docker-compose -f scripts/docker/docker-compose.test.yml down --rmi all --volumes
```

#### Interactive Development Environments

```bash
# Start interactive Ubuntu shell with live dotfiles mounting
docker-compose -f scripts/docker/docker-compose.dev.yml run --rm dev-ubuntu

# Start interactive Debian shell
docker-compose -f scripts/docker/docker-compose.dev.yml run --rm dev-debian

# Start interactive Fedora shell
docker-compose -f scripts/docker/docker-compose.dev.yml run --rm dev-fedora

# Use Bash instead of Fish
docker-compose -f scripts/docker/docker-compose.dev.yml run --rm dev-arch /bin/bash
```

**Note**: Development mode mounts dotfiles as a volume, so changes in the container are immediately reflected on your host and vice versa!

### Distribution Comparison

| Distribution | Base Image | Package Manager | Modern Tools in Repos | Best For |
|-------------|------------|-----------------|----------------------|----------|
| **Ubuntu 22.04** | ubuntu:22.04 | apt | Moderate | Most common, general testing |
| **Debian 12** | debian:12 | apt | Moderate | Stability, production environments |
| **Fedora 40** | fedora:40 | dnf | High | Modern packages, Red Hat ecosystem |
| **Arch Linux** | archlinux:latest | pacman | Very High | Bleeding edge, latest tools |
| **Alpine** | alpine:latest | apk | Low | Minimal footprint, containers |

## Docker Testing Workflow

### Building Images

```bash
# Ubuntu (primary target)
docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile \
  -t dotfiles-test:ubuntu .

# With build cache optimization
docker build --cache-from dotfiles-test:ubuntu \
  -f scripts/docker/dockerfiles/ubuntu.Dockerfile \
  -t dotfiles-test:ubuntu .
```

### Running Tests

#### Automated Test Suite

```bash
# Run all tests
docker run --rm dotfiles-test:ubuntu \
  /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh

# Run specific test
docker run --rm dotfiles-test:ubuntu \
  /home/testuser/dotfiles/scripts/docker/scripts/test-stow.sh
```

#### Interactive Testing

```bash
# Drop into Fish shell
docker run -it --rm dotfiles-test:ubuntu

# Drop into Bash shell
docker run -it --rm --entrypoint /bin/bash dotfiles-test:ubuntu

# Mount local dotfiles for live development
docker run -it --rm \
  -v ~/dotfiles:/home/testuser/dotfiles \
  dotfiles-test:ubuntu
```

### Test Results

Test results are saved to `/tmp/dotfiles-test-results/` inside the container:

```bash
# View results after test run
docker run --rm dotfiles-test:ubuntu \
  cat /tmp/dotfiles-test-results/*.log
```

## Test Suites

### 1. Package Manager Tests (`test-packages.sh`)

Validates package manager detection and operations:
- ✅ Distribution detection
- ✅ Package manager availability (apt/dnf/yum/pacman/apk)
- ✅ Package query operations
- ✅ Essential tools installation (git, curl, wget, stow)
- ✅ Sudo/privilege escalation
- ✅ Repository connectivity

### 2. GNU Stow Tests (`test-stow.sh`)

Validates dotfiles symlinking:
- ✅ Stow installation and version
- ✅ Basic stow operations (.gitconfig)
- ✅ Directory stowing (.config/fish)
- ✅ Conflict detection
- ✅ Unstow operations

### 3. Fish Shell Tests (`test-fish.sh`)

Validates Fish shell configuration:
- ✅ Fish installation
- ✅ Config file existence and loading
- ✅ Configuration error detection
- ✅ Environment variables (including BAT_PAGING fix!)
- ✅ Functions and aliases
- ✅ Completion system
- ✅ Fisher plugin manager
- ✅ PATH configuration
- ✅ Starship prompt integration

### 4. Zsh Shell Tests (`test-zsh.sh`)

Validates Zsh shell configuration:
- ✅ Zsh installation
- ✅ .zshrc existence and loading
- ✅ Configuration error detection
- ✅ Environment variables (including BAT_PAGING fix!)
- ✅ Oh My Zsh installation
- ✅ Plugins and themes
- ✅ Aliases
- ✅ Completion system
- ✅ PATH configuration
- ✅ FZF and Starship integration

## What Gets Tested

### ✅ Tested in Containers

- Package manager operations (apt/dnf/pacman)
- GNU Stow symlink operations
- Shell configurations (Fish, Zsh)
- CLI tool configs (fzf, bat, ripgrep, eza, zoxide)
- Git configuration
- Tmux configuration (basic)
- Environment variables
- PATH modifications
- Script execution

### ⚠️ Requires Adaptation

- Homebrew → Translated to apt/dnf/pacman equivalents
- macOS-specific tools → Skip or find Linux alternatives
- GUI applications → Skip in container tests

### ❌ Cannot Test

- macOS-specific applications (Alfred, Aerospace, etc.)
- macOS system preferences
- Keyboard remapping
- GUI-only features

## Troubleshooting

### Colima Issues

**Problem**: `colima start` fails
```bash
# Check Colima status
colima status

# Delete and recreate
colima delete
./scripts/docker/colima-setup.sh start
```

**Problem**: Docker commands fail after Colima starts
```bash
# Verify Docker socket
echo $DOCKER_HOST

# Should show: unix://$HOME/.colima/default/docker.sock
# If not set:
export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"

# Or switch Docker context
docker context use colima
```

### Build Issues

**Problem**: Docker build is slow
```bash
# The .dockerignore file should optimize builds
# Check it exists:
cat scripts/docker/.dockerignore

# Clean up old images
docker system prune -a
```

**Problem**: Package installation fails in Dockerfile
```bash
# Rebuild without cache
docker build --no-cache \
  -f scripts/docker/dockerfiles/ubuntu.Dockerfile \
  -t dotfiles-test:ubuntu .
```

### Test Failures

**Problem**: Stow tests fail
- Ensure GNU Stow is installed in the container
- Check file permissions
- Verify dotfiles are copied correctly into container

**Problem**: Shell tests fail
- Fish/Zsh may not be installed
- Config files might not be symlinked yet
- Check test expects correct default state

**Problem**: BAT_PAGING errors persist
- Verify the BAT_PAGING fix is in both Fish and Zsh configs
- Restart shell session to load new environment variable
- Check: `echo $BAT_PAGING` should output "never"

## Current Capabilities

### ✅ Implemented (Phase 1-7)

- **Multi-Distribution Support**: 5 Linux distributions fully supported
  - Ubuntu 22.04 LTS (primary, most common)
  - Debian 12 Bookworm (stable base)
  - Fedora 40 (modern packages)
  - Arch Linux (bleeding edge)
  - Alpine Linux (minimal/musl)

- **Package Management Infrastructure**:
  - Abstract package manager interface (apt/dnf/yum/pacman/apk)
  - 100+ package mappings from Homebrew to Linux equivalents
  - Binary installer for 30+ modern tools from GitHub releases
  - Profile-based installation (minimal/standard/comprehensive/dev/ops)

- **Testing Framework**:
  - Multi-distribution test runner script
  - Docker Compose orchestration (test & dev environments)
  - Parallel and sequential test execution
  - Comprehensive test suites:
    - Package manager detection and validation
    - GNU Stow operations
    - Fish shell configuration
    - Zsh shell configuration
    - Setup script validation

- **Development Tools**:
  - Colima management helper
  - Interactive development environments with live mounting
  - BAT_PAGING pager error fix

- **Comprehensive Documentation**:
  - Complete usage guides
  - Distribution comparison matrix
  - Troubleshooting guides

### 🚧 Future Enhancements

- Phase 4: Simplify Dockerfiles to use setup.sh (currently manual installations)
- Additional test scripts:
  - CLI tools (fzf, bat, ripgrep, eza, etc.)
  - Git configuration validation
  - Tmux configuration validation
- CI/CD integration for automated testing
- Performance benchmarking across distributions

## Development Workflow

### Testing Changes to Dotfiles

```bash
# 1. Make changes to your dotfiles locally
vim ~/.config/fish/config.fish

# 2. Rebuild container with new changes
docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile \
  -t dotfiles-test:ubuntu .

# 3. Test in container
docker run -it --rm dotfiles-test:ubuntu

# 4. Or run automated tests
docker run --rm dotfiles-test:ubuntu \
  /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh
```

### Live Development Mode

For faster iteration, mount dotfiles as volume:

```bash
docker run -it --rm \
  -v ~/dotfiles:/home/testuser/dotfiles \
  --workdir /home/testuser/dotfiles \
  dotfiles-test:ubuntu fish
```

Changes to dotfiles are immediately reflected in the container!

## Performance Tips

1. **Use build cache**: Don't use `--no-cache` unless necessary
2. **Layer optimization**: Dockerfile layers are optimized for caching
3. **Parallel builds**: Build multiple images simultaneously
4. **Resource allocation**: Adjust Colima resources based on needs
5. **Image cleanup**: Regularly run `docker system prune`

## Best Practices

1. **Test before deployment**: Always test dotfiles changes in containers before deploying to production Linux systems
2. **Multi-distro testing**: Test on Ubuntu first (most common), then expand to other distros
3. **Incremental development**: Make small changes and test frequently
4. **Version control**: Commit working container configurations
5. **Document assumptions**: Note any distribution-specific requirements

## Integration with Dotfiles Project

This testing framework integrates with the existing dotfiles structure:

```
~/dotfiles/
├── .config/                    # Application configs (testable)
├── .gitconfig                  # Git config (testable)
├── .zshrc                      # Zsh config (testable)
├── homebrew/Brewfile          # macOS packages (needs translation)
├── scripts/
│   ├── docker/                # This testing framework
│   ├── linux/                 # Linux-specific scripts
│   └── setup/                 # Setup scripts
└── CLAUDE.md                  # Updated with testing workflow
```

## Contributing

When adding new tests or distributions:

1. Follow existing script patterns
2. Add appropriate error handling
3. Use color-coded output (GREEN/RED/YELLOW)
4. Document expected behavior
5. Update this README

## Resources

- [Colima Documentation](https://github.com/abiosoft/colima)
- [Docker Documentation](https://docs.docker.com/)
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
- [Fish Shell Documentation](https://fishshell.com/docs/current/)

## Support

For issues or questions:
1. Check this README first
2. Review test script output for clues
3. Check Colima and Docker logs
4. Verify dotfiles structure and permissions

---

**Last Updated**: 2025-10-30
**Status**: Phase 1-7 Complete (Multi-Distribution Testing Framework)
**Distributions**: Ubuntu, Debian, Fedora, Arch, Alpine
**Next**: Phase 4 (Dockerfile simplification) and additional test coverage
