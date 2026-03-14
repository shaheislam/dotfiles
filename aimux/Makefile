PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/aimux
SHAREDIR = $(PREFIX)/share/aimux
FISH_COMP = $(PREFIX)/share/fish/vendor_completions.d
BASH_COMP = $(PREFIX)/etc/bash_completion.d
ZSH_COMP = $(PREFIX)/share/zsh/site-functions

.PHONY: install uninstall test lint

install:
	@echo "Installing aimux to $(PREFIX)..."
	install -d $(BINDIR) $(LIBDIR) $(SHAREDIR)
	install -m 755 bin/aimux $(BINDIR)/aimux
	install -m 644 lib/aimux/*.sh $(LIBDIR)/
	[ -d config ] && install -d $(SHAREDIR) && install -m 644 config/*.conf config/*.tmux.conf $(SHAREDIR)/ 2>/dev/null || true
	@if [ -d completions ]; then \
		[ -f completions/aimux.fish ] && install -d $(FISH_COMP) && install -m 644 completions/aimux.fish $(FISH_COMP)/ || true; \
		[ -f completions/aimux.bash ] && install -d $(BASH_COMP) && install -m 644 completions/aimux.bash $(BASH_COMP)/ || true; \
		[ -f completions/_aimux ] && install -d $(ZSH_COMP) && install -m 644 completions/_aimux $(ZSH_COMP)/ || true; \
	fi
	@echo "Done. Run 'aimux doctor' to verify installation."

uninstall:
	rm -f $(BINDIR)/aimux
	rm -rf $(LIBDIR)
	rm -rf $(SHAREDIR)
	rm -f $(FISH_COMP)/aimux.fish $(BASH_COMP)/aimux.bash $(ZSH_COMP)/_aimux

test:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "BATS not found. Install with: brew install bats-core"; \
		exit 1; \
	fi

lint:
	@shellcheck bin/aimux lib/aimux/*.sh
