# Scripts Directory

This directory contains custom scripts and utilities for the dotfiles setup.

## Organization

Scripts are organized into the following categories:

- **setup/** - Installation, setup, and configuration scripts
- **aws/** - AWS-related utilities and log viewers
- **tmux/** - tmux session management and utilities
- **tools/** - Miscellaneous development tools
- **cv/** - CV generation and compilation tools
- **bin/** - Binary executables in PATH
- **footyres/** - Football results fetcher

## bin/

### tmpmail

A command-line utility for creating and managing temporary email addresses using Mail.tm API.

**Features:**
- Generate random temporary email addresses
- View inbox and read emails in terminal
- Copy email address to clipboard
- Render HTML emails using w3m
- Reliable Mail.tm API backend

**Installation:**
The script is automatically added to PATH via Fish and Zsh configurations.

**Dependencies (installed via Homebrew):**
- w3m - For HTML email rendering
- curl - For API calls
- jq - For JSON parsing
- pbcopy (built-in on macOS) - For clipboard support

**Usage:**

```bash
# Generate a new temporary email
tmpmail --generate
# or use the alias
tmp

# Check inbox
tmpmail
# or use the alias
tmpm

# View specific email by ID
tmpmail [ID]

# Copy email to clipboard
tmpmail --copy

# View most recent email
tmpmail --recent

# Get help
tmpmail --help
```

**Notes:**
- Modified to work on macOS by using `pbcopy` instead of `xclip` for clipboard operations
- Uses Mail.tm API for reliable temporary email service
- Stores account credentials temporarily in `/tmp/tmpmail-tm/` directory
- Credentials are cleared on system restart

## setup-script.sh

The main setup script for configuring a new macOS development environment with all dotfiles and tools.

## tools/

### healthcheck-repos.sh

A comprehensive repository healthcheck scanner that validates configuration across all git repositories under ~/work.

**Features:**
- Scans all git repositories recursively
- Validates `.gitignore_local` symlink setup (→ `.git/info/exclude`)
- Checks that `.gitignore_local` is self-referenced in git exclude
- Validates Nix flake configurations (flake.nix, flake.lock)
- Detects stale flake.lock files (>90 days old)
- Interactive fix prompts for all detected issues
- Summary report with statistics

**Healthchecks Performed:**
1. **Git Exclude Symlink** - Verifies `.gitignore_local` → `.git/info/exclude`
2. **Git Exclude Content** - Ensures `.gitignore_local` is listed in `.git/info/exclude`
3. **Nix Flake Presence** - Checks for `flake.nix` (informational)
4. **Nix Flake Lock Age** - Validates `flake.lock` is < 90 days old

**Usage:**

```bash
# Run full healthcheck with interactive fixes
~/dotfiles/scripts/tools/healthcheck-repos.sh

# Report only (no fixes offered)
~/dotfiles/scripts/tools/healthcheck-repos.sh --dry-run

# Show only repositories with issues
~/dotfiles/scripts/tools/healthcheck-repos.sh --failures-only

# Verbose mode (show all checks including passes)
~/dotfiles/scripts/tools/healthcheck-repos.sh --verbose

# Quiet mode (summary only)
~/dotfiles/scripts/tools/healthcheck-repos.sh --quiet

# Override work directory
~/dotfiles/scripts/tools/healthcheck-repos.sh --work-dir ~/projects
```

**Options:**
- `--dry-run` - Report issues without offering fixes
- `--verbose` - Show all checks including informational messages
- `--quiet` - Show only summary statistics
- `--failures-only` - Show only repositories with issues
- `--work-dir DIR` - Override work directory (default: ~/work)
- `--help` - Show usage information

**Interactive Fix Workflow:**
When issues are detected, the script offers to fix them interactively:
1. Missing symlink → Creates `.gitignore_local` → `.git/info/exclude`
2. Missing self-reference → Adds `.gitignore_local` to `.git/info/exclude`
3. Stale flake.lock → Runs `nix flake update` in repository

**Output:**
- Color-coded status messages (✓ success, ✗ error, ⚠ warning, ℹ info)
- Per-repository detailed results
- Summary statistics with issue breakdown
- Exit code 0 if all repos healthy, 1 if issues found

**Notes:**
- Skips git submodules automatically
- Preserves existing `.git/info/exclude` content
- Compatible with both macOS and Linux
- Follows established validation framework patterns
