FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive \
    DOTFILES_ROOT=/home/testuser/dotfiles

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash bats ca-certificates curl git python3 sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/testuser

USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . /home/testuser/dotfiles

CMD ["bats", "scripts/tests/parity.bats"]
