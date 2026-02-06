FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install tools not available as features + firewall requirements
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  man-db \
  unzip \
  gnupg2 \
  # Firewall requirements
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  # Utilities
  jq \
  nano \
  vim \
  curl \
  rsync \
  wget \
  xclip \
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

# Install zoxide (smart cd command, used by fzf-lua)
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
  && mv ~/.local/bin/zoxide /usr/local/bin/ \
  && zoxide --version

# Install atuin (shell history sync, required for Ctrl+R fzf integration)
RUN ARCH=$(dpkg --print-architecture) \
  && ATUIN_VERSION=$(curl -fsSL https://api.github.com/repos/atuinsh/atuin/releases/latest | grep -Po '"tag_name": "v?\K[^"]*') \
  && echo "Installing atuin ${ATUIN_VERSION}..." \
  && if [ "$ARCH" = "arm64" ]; then ATUIN_ARCH="aarch64"; else ATUIN_ARCH="x86_64"; fi \
  && curl -fSL -o /tmp/atuin.tar.gz "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-v${ATUIN_VERSION}-${ATUIN_ARCH}-unknown-linux-gnu.tar.gz" \
  && tar -xzf /tmp/atuin.tar.gz -C /tmp \
  && mv /tmp/atuin-v${ATUIN_VERSION}-${ATUIN_ARCH}-unknown-linux-gnu/atuin /usr/local/bin/ \
  && rm -rf /tmp/atuin* \
  && atuin --version

# Install eza (modern ls replacement, used by fish aliases and FZF previews)
RUN ARCH=$(dpkg --print-architecture) \
  && EZA_VERSION=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest | grep -Po '"tag_name": "v?\K[^"]*') \
  && echo "Installing eza ${EZA_VERSION}..." \
  && if [ "$ARCH" = "arm64" ]; then EZA_ARCH="aarch64"; else EZA_ARCH="x86_64"; fi \
  && curl -fSL -o /tmp/eza.tar.gz "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_${EZA_ARCH}-unknown-linux-gnu.tar.gz" \
  && tar -xzf /tmp/eza.tar.gz -C /usr/local/bin \
  && rm /tmp/eza.tar.gz \
  && eza --version

# Install bat (cat replacement with syntax highlighting, used by FZF previews)
RUN ARCH=$(dpkg --print-architecture) \
  && BAT_VERSION=$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest | grep -Po '"tag_name": "v?\K[^"]*') \
  && echo "Installing bat ${BAT_VERSION}..." \
  && curl -fSL -o /tmp/bat.deb "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_${ARCH}.deb" \
  && dpkg -i /tmp/bat.deb \
  && rm /tmp/bat.deb \
  && bat --version

# Install fd (find replacement, used by FZF default command)
RUN ARCH=$(dpkg --print-architecture) \
  && FD_VERSION=$(curl -fsSL https://api.github.com/repos/sharkdp/fd/releases/latest | grep -Po '"tag_name": "v?\K[^"]*') \
  && echo "Installing fd ${FD_VERSION}..." \
  && curl -fSL -o /tmp/fd.deb "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd_${FD_VERSION}_${ARCH}.deb" \
  && dpkg -i /tmp/fd.deb \
  && rm /tmp/fd.deb \
  && fd --version

# Install ripgrep (grep replacement, used by FZF default command)
RUN ARCH=$(dpkg --print-architecture) \
  && RG_VERSION=$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep -Po '"tag_name": "\K[^"]*') \
  && echo "Installing ripgrep ${RG_VERSION}..." \
  && curl -fSL -o /tmp/ripgrep.deb "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep_${RG_VERSION}-1_${ARCH}.deb" \
  && dpkg -i /tmp/ripgrep.deb \
  && rm /tmp/ripgrep.deb \
  && rg --version

# Install git-delta
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set environment variables
ENV DEVCONTAINER=true
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/usr/bin/fish
ENV EDITOR=nvim
ENV VISUAL=nvim

# Create workspace and config directories
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

# Switch to node user for npm install
USER node

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Copy and set up scripts (requires root)
USER root
COPY init-firewall.sh /usr/local/bin/
COPY setup-nvim-env.sh /usr/local/bin/
RUN chmod a+rx /usr/local/bin/init-firewall.sh /usr/local/bin/setup-nvim-env.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

# Switch back to node user
USER node
