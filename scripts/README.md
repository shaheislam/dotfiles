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
