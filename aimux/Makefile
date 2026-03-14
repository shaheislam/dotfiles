PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/aimux
SHAREDIR = $(PREFIX)/share/aimux
FISH_COMP = $(PREFIX)/share/fish/vendor_completions.d
BASH_COMP = $(PREFIX)/etc/bash_completion.d
ZSH_COMP = $(PREFIX)/share/zsh/site-functions
GOBIN = lib/aimux

.PHONY: all build install uninstall test test-bash test-go clean lint help

all: build ## Build everything

build: ## Build Go daemon
	@echo "Building aimuxd..."
	go build -o $(GOBIN)/aimuxd ./cmd/aimuxd/

install: ## Install aimux to PREFIX (default: /usr/local)
	@echo "Installing aimux to $(PREFIX)..."
	install -d $(BINDIR) $(LIBDIR) $(SHAREDIR)
	install -m 755 bin/aimux $(BINDIR)/aimux
	install -m 644 lib/aimux/*.sh $(LIBDIR)/
	@if [ -d lib/aimux/providers ]; then \
		install -d $(LIBDIR)/providers; \
		install -m 644 lib/aimux/providers/*.sh $(LIBDIR)/providers/; \
	fi
	@if [ -f $(GOBIN)/aimuxd ]; then \
		install -m 755 $(GOBIN)/aimuxd $(BINDIR)/aimuxd; \
	fi
	[ -d config ] && install -d $(SHAREDIR) && install -m 644 config/*.toml config/*.tmux.conf $(SHAREDIR)/ 2>/dev/null || true
	@if [ -d templates ]; then \
		install -d $(SHAREDIR)/templates/launch; \
		install -m 644 templates/launch/*.tmpl $(SHAREDIR)/templates/launch/ 2>/dev/null || true; \
	fi
	@if [ -d completions ]; then \
		[ -f completions/aimux.fish ] && install -d $(FISH_COMP) && install -m 644 completions/aimux.fish $(FISH_COMP)/ || true; \
		[ -f completions/aimux.bash ] && install -d $(BASH_COMP) && install -m 644 completions/aimux.bash $(BASH_COMP)/ || true; \
		[ -f completions/_aimux ] && install -d $(ZSH_COMP) && install -m 644 completions/_aimux $(ZSH_COMP)/ || true; \
	fi
	@echo "Done. Run 'aimux doctor' to verify installation."

uninstall: ## Remove aimux from PREFIX
	rm -f $(BINDIR)/aimux $(BINDIR)/aimuxd
	rm -rf $(LIBDIR)
	rm -rf $(SHAREDIR)
	rm -f $(FISH_COMP)/aimux.fish $(BASH_COMP)/aimux.bash $(ZSH_COMP)/_aimux

test: test-bash test-go ## Run all tests

test-bash: ## Run BATS tests
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "BATS not found. Install with: brew install bats-core"; \
		exit 1; \
	fi

test-go: ## Run Go tests
	go test -race ./...

clean: ## Remove build artifacts
	rm -f $(GOBIN)/aimuxd

lint: ## Run shellcheck and go vet
	@shellcheck bin/aimux lib/aimux/*.sh
	@go vet ./...

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
