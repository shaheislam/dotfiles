# Neovim + Netshoot Debug Container
# Ubuntu-based for full plugin compatibility (blink.cmp, Treesitter, Mason LSPs)
#
# Build: ./scripts/docker/build-netshoot-nvim.sh
# Run:   docker run -it --rm netshoot-nvim:latest

FROM ubuntu:22.04

LABEL maintainer="Shah Islam"
LABEL description="Debug container with Neovim, networking tools, and DevOps LSPs"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Core utilities + netshoot networking tools
RUN apt update -y && apt install -y \
    # Basic utilities
    curl wget git unzip sudo coreutils file locales ca-certificates \
    # Build tools for Treesitter and plugins
    build-essential \
    # Netshoot networking tools
    tcpdump net-tools dnsutils iputils-ping traceroute \
    nmap netcat-openbsd socat iperf3 mtr-tiny \
    iproute2 iptables conntrack ethtool bridge-utils \
    # Additional networking tools
    httpie jq openssh-client \
    # Shell
    zsh bash-completion \
    # Neovim dependencies
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install fzf from GitHub releases (Ubuntu's version is too old for fzf-lua)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then FZF_ARCH="linux_amd64"; else FZF_ARCH="linux_arm64"; fi && \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v0.56.3/fzf-0.56.3-${FZF_ARCH}.tar.gz" -o /tmp/fzf.tar.gz && \
    tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin && \
    rm /tmp/fzf.tar.gz

# Install fd-find and create symlink
RUN apt update -y && apt install -y fd-find \
    && ln -s $(which fdfind) /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) for LSPs and plugins
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install yq (not in Ubuntu repos, install from binary)
# Detect architecture for correct binary
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Install Neovim (latest stable from GitHub releases)
# PPA version is too old, doesn't support statuscolumn (Neovim 0.9+)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then NVIM_ARCH="linux-x86_64"; else NVIM_ARCH="linux-arm64"; fi && \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-${NVIM_ARCH}.tar.gz" -o /tmp/nvim.tar.gz && \
    tar -xzf /tmp/nvim.tar.gz -C /opt && \
    ln -s /opt/nvim-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim && \
    rm /tmp/nvim.tar.gz

# Configure locales
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup Neovim directories
RUN mkdir -p /root/.config/nvim /root/.local/share/nvim /root/.cache/nvim

# Copy Neovim config (from build context - the ~/neovim directory)
COPY --chown=root:root . /root/.config/nvim

# Set environment variables
ENV TERM=xterm-256color
ENV EDITOR=nvim
ENV VISUAL=nvim

# Bootstrap lazy.nvim and install all plugins
RUN nvim --headless "+Lazy! sync" +qa 2>&1 || echo "Plugin sync completed"

# Download blink.pairs and blink.cmp pre-built Rust binaries for offline use
# These plugins normally download binaries on first load - we pre-download during build
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then RUST_ARCH="x86_64-unknown-linux-gnu"; else RUST_ARCH="aarch64-unknown-linux-gnu"; fi && \
    mkdir -p /root/.local/share/nvim/lazy/blink.pairs/target/release && \
    curl -fsSL "https://github.com/saghen/blink.pairs/releases/download/v0.4.1/${RUST_ARCH}.so" \
        -o /root/.local/share/nvim/lazy/blink.pairs/target/release/libblink_pairs.so && \
    mkdir -p /root/.local/share/nvim/lazy/blink.cmp/target/release && \
    curl -fsSL "https://github.com/saghen/blink.cmp/releases/download/v1.8.0/${RUST_ARCH}.so" \
        -o /root/.local/share/nvim/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.so && \
    echo "Blink binaries downloaded successfully"

# Install Treesitter parsers for DevOps languages
# Use timeout to prevent hanging, parsers will install on first use if this fails
RUN timeout 120 nvim --headless "+TSInstall yaml json dockerfile bash lua markdown toml" "+sleep 60" +qa 2>&1 || echo "TSInstall timed out, parsers will install on first use"

# Install LSPs via Mason (DevOps focused)
# Note: This requires Mason to be configured in the Neovim config
# Use timeout to prevent hanging, LSPs will install on first use if this fails
RUN timeout 180 nvim --headless \
    -c "MasonInstall yaml-language-server json-lsp dockerfile-language-server-nodejs bash-language-server lua-language-server" \
    -c "sleep 60" \
    -c "qall" 2>&1 || echo "MasonInstall timed out, LSPs will install on first use"

# Verify installation
RUN nvim --version && echo "Neovim installed successfully"

# Set working directory
WORKDIR /root

# Default shell
CMD ["/bin/bash"]
