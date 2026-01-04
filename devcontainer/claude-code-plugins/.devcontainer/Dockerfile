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
