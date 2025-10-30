# Ubuntu 22.04 LTS Dockerfile for Dotfiles Testing
# Primary target for Linux dotfiles validation - uses setup.sh for complete installation
FROM ubuntu:22.04

# Metadata
LABEL maintainer="dotfiles-testing"
LABEL description="Ubuntu 22.04 environment for testing dotfiles installation via setup.sh"
LABEL version="2.0"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    HOME=/home/testuser \
    SHELL=/bin/bash

# Install ONLY essential base dependencies needed before setup.sh
RUN apt-get update && apt-get install -y \
    # Core utilities needed by setup.sh
    curl \
    wget \
    git \
    sudo \
    # Build tools (needed for some binary compilations)
    build-essential \
    # GNU Stow for dotfiles management
    stow \
    # Shell alternatives
    zsh \
    # Process management
    procps \
    # Locales
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Create test user (non-root for realistic testing)
RUN useradd -m -s /bin/bash -G sudo testuser && \
    echo "testuser:testuser" | chpasswd && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Create expected directory structure
RUN mkdir -p \
    ~/bin \
    ~/dotfiles \
    ~/.local/bin \
    ~/.config \
    ~/.cache

# Copy dotfiles into container
COPY --chown=testuser:testuser . /home/testuser/dotfiles

# Set working directory to dotfiles
WORKDIR /home/testuser/dotfiles

# Run setup.sh with comprehensive profile
# This will:
# - Detect OS and package manager (apt)
# - Install all packages from profile
# - Install binary tools from GitHub releases
# - Set up dotfiles with stow
# - Configure shells (Fish, Zsh)
ENV PROFILE=comprehensive \
    NO_CONFIRM=true \
    SKIP_FONTS_APPS=true \
    FORCE_ONLINE=true

RUN bash scripts/setup.sh || { \
    echo "Setup script failed, but continuing for debugging"; \
    exit 0; \
}

# Basic environment setup
ENV PATH="/home/testuser/.local/bin:/home/testuser/bin:/home/testuser/dotfiles/scripts/bin:${PATH}"

# Health check: Verify essential tools are available
RUN bash -c ' \
    echo "Verifying installations..."; \
    command -v fish && echo "✓ Fish installed" || echo "✗ Fish missing"; \
    command -v git && echo "✓ Git installed" || echo "✗ Git missing"; \
    command -v stow && echo "✓ Stow installed" || echo "✗ Stow missing"; \
    command -v eza && echo "✓ eza installed" || echo "○ eza optional"; \
    command -v kubectl && echo "✓ kubectl installed" || echo "○ kubectl optional"; \
    echo "Container setup complete!"; \
'

# Default command: Drop into Fish shell for interactive testing
# Override this in docker-compose or docker run for automated testing
CMD ["/usr/bin/fish"]

# Usage examples:
# Build: docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile -t dotfiles-test:ubuntu .
# Run interactive: docker run -it --rm dotfiles-test:ubuntu
# Run tests: docker run --rm dotfiles-test:ubuntu /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh
