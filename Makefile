# Dotfiles Makefile — unified developer commands
# Inspired by stefanprodan/podinfo's Makefile-as-contract pattern
#
# Usage:
#   make test      — run all tests (smoke + lint + syntax)
#   make lint      — check formatting and static analysis
#   make setup     — run setup.sh with defaults
#   make validate  — full validation suite
#   make doctor    — health check
#   make clean     — remove generated artifacts

.PHONY: test lint setup validate doctor clean help fmt check-dirty

SHELL := /bin/bash
SCRIPTS_DIR := scripts
FISH_DIR := .config/fish

# ============================================================================
# Primary Targets
# ============================================================================

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1;33m%-15s\033[0m %s\n", $$1, $$2}'

test: lint smoke-test ## Run all tests (lint + smoke tests)

lint: shellcheck shfmt-check fish-syntax json-validate yaml-validate ## Run all linters

setup: ## Run setup.sh with default profile
	bash $(SCRIPTS_DIR)/setup.sh

setup-dry-run: ## Preview setup without changes
	bash $(SCRIPTS_DIR)/setup.sh --dry-run

# ============================================================================
# Linting Targets
# ============================================================================

shellcheck: ## Run shellcheck on all shell scripts
	@echo "Running shellcheck..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shellcheck -S warning {} + 2>&1 || true

shfmt-check: ## Check shell script formatting (no write)
	@echo "Checking shell formatting..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shfmt -d -i 4 -ci {} + 2>&1 || true

fmt: ## Auto-format shell scripts
	@echo "Formatting shell scripts..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shfmt -w -i 4 -ci {} +

fish-syntax: ## Validate Fish shell syntax
	@echo "Checking Fish syntax..."
	@if command -v fish >/dev/null 2>&1; then \
		find $(FISH_DIR) -name "*.fish" -type f -exec fish -n {} + 2>&1 || true; \
	else \
		echo "  fish not installed, skipping"; \
	fi

json-validate: ## Validate all JSON files
	@echo "Validating JSON..."
	@find . -name "*.json" -not -path "./.git/*" -not -path "./node_modules/*" \
		-exec python3 -m json.tool {} /dev/null \; 2>&1 || true

yaml-validate: ## Validate YAML files
	@echo "Validating YAML..."
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -d relaxed . 2>&1 || true; \
	else \
		echo "  yamllint not installed, skipping"; \
	fi

# ============================================================================
# Testing Targets
# ============================================================================

smoke-test: ## Run smoke test suite
	@bash $(SCRIPTS_DIR)/smoke-test.sh

validate: lint smoke-test check-dirty ## Full validation (lint + smoke + dirty check)

check-dirty: ## Verify no uncommitted changes (CI gate)
	@echo "Checking for uncommitted changes..."
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is dirty after tests"; \
		git status --short; \
		exit 1; \
	fi

# ============================================================================
# Maintenance Targets
# ============================================================================

doctor: ## Run health checks
	@echo "Running dotfiles health checks..."
	@bash $(SCRIPTS_DIR)/smoke-test.sh
	@echo ""
	@echo "Checking stow status..."
	@command -v stow >/dev/null 2>&1 && stow -n -v -t "$$HOME" . 2>&1 | head -20 || echo "  stow not installed"

clean: ## Remove generated files and logs
	@echo "Cleaning generated artifacts..."
	@find . -name "*.log" -not -path "./.git/*" -delete 2>/dev/null || true
	@find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "Done."

# ============================================================================
# Default
# ============================================================================

.DEFAULT_GOAL := help
