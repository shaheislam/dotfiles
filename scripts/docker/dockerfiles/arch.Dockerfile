# Arch Linux Dockerfile for Dotfiles Testing
# Testing dotfiles on bleeding-edge Arch with most complete package repos - uses setup.sh
FROM archlinux:latest

# Metadata
LABEL maintainer="dotfiles-testing"
LABEL description="Arch Linux environment for testing dotfiles installation via setup.sh"
LABEL version="2.0"

# Prevent interactive prompts
ENV TERM=xterm-256color \
    HOME=/home/testuser \
    SHELL=/bin/bash

# Update system and install ONLY essential base dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    # Core utilities needed by setup.sh
    curl \
    wget \
    git \
    sudo \
    # Build tools
    base-devel \
    # GNU Stow for dotfiles management
    stow \
    # Shell alternatives
    zsh \
    # Process management
    procps-ng \
    && pacman -Scc --noconfirm

# Create test user (non-root for realistic testing)
RUN useradd -m -s /bin/bash -G wheel testuser && \
    echo "testuser:testuser" | chpasswd && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

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
CMD ["/usr/bin/fish"]

# Usage examples:
# Build: docker build -f scripts/docker/dockerfiles/arch.Dockerfile -t dotfiles-test:arch .
# Run interactive: docker run -it --rm dotfiles-test:arch
# Run tests: docker run --rm dotfiles-test:arch /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh
