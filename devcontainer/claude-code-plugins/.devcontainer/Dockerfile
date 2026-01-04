FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fish \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  # Neovim dependencies
  ripgrep \
  fd-find \
  curl \
  rsync \
  # Locale support
  locales \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  # Generate locales
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && sed -i '/en_GB.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

# Install fzf (latest from GitHub for --tmux support, requires 0.53.0+)
RUN FZF_VERSION=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | grep -Po '"tag_name": "v?\K[^"]*') \
  && echo "Installing fzf ${FZF_VERSION}..." \
  && ARCH=$(dpkg --print-architecture) \
  && if [ "$ARCH" = "arm64" ]; then FZF_ARCH="arm64"; else FZF_ARCH="amd64"; fi \
  && curl -fSL -o /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz" \
  && tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin \
  && rm /tmp/fzf.tar.gz \
  && fzf --version

# Install Neovim (latest stable via tarball - AppImage requires FUSE which isn't available in Docker)
# Detect architecture and download appropriate tarball
RUN NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | grep -Po '"tag_name": "\K[^"]*') \
  && echo "Downloading Neovim ${NVIM_VERSION}..." \
  && ARCH=$(uname -m) \
  && if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
       NVIM_FILE="nvim-linux-arm64.tar.gz"; \
     else \
       NVIM_FILE="nvim-linux-x86_64.tar.gz"; \
     fi \
  && curl -fSL -o /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${NVIM_FILE}" \
  && tar -xzf /tmp/nvim.tar.gz -C /opt \
  && ln -sf /opt/nvim-linux-*/bin/nvim /usr/local/bin/nvim \
  && rm -rf /tmp/nvim.tar.gz \
  && nvim --version

# Install zoxide (smart cd command, used by fzf-lua)
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
  && mv ~/.local/bin/zoxide /usr/local/bin/ \
  && zoxide --version

# Install starship prompt
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y \
  && starship --version

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to fish rather than sh
ENV SHELL=/usr/bin/fish

# Set the default editor and visual (prefer nvim if available)
ENV EDITOR=nvim
ENV VISUAL=nvim

# Install Rust toolchain for Neovim plugins that need native compilation (blink.pairs, etc.)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/node/.cargo/bin:$PATH"

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
# Copy and set up Neovim environment script
COPY setup-nvim-env.sh /usr/local/bin/
USER root
RUN chmod a+rx /usr/local/bin/init-firewall.sh /usr/local/bin/setup-nvim-env.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
