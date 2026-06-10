FROM archlinux:base-devel

ENV DOTFILES_ROOT=/home/testuser/dotfiles

RUN pacman -Syu --noconfirm bats bash ca-certificates curl git python sudo && \
    pacman -Scc --noconfirm

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/testuser

USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . /home/testuser/dotfiles

CMD ["bats", "scripts/tests/parity.bats"]
