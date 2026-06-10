FROM fedora:40

ENV DOTFILES_ROOT=/home/testuser/dotfiles

RUN dnf install -y bats bash ca-certificates curl git python3 sudo && dnf clean all

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/testuser

USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . /home/testuser/dotfiles

CMD ["bats", "scripts/tests/parity.bats"]
