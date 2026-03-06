# Dotfiles Makefile — unified developer commands
# Provides a single entry point for linting, testing, and validation.
# CI workflows call these same targets, so local and CI behavior match.
#
# Targets are split into two tiers:
#   Gate (make test)   — must pass for CI; only catches real errors
#   Strict (make lint-strict) — advisory; catches style issues too
#
# Usage:
#   make test        — run gate checks (shellcheck errors + JSON + smoke)
#   make lint-strict — run all linters including formatting advisories
#   make setup       — run setup.sh with defaults
#   make validate    — full CI gate (test + dirty-tree check)
#   make doctor      — health check
#   make clean       — remove generated artifacts

.PHONY: test lint lint-strict setup validate doctor clean help fmt \
        check-dirty check-deps shellcheck shellcheck-strict shfmt-check \
        fish-syntax json-validate yaml-validate smoke-test setup-dry-run

SHELL := /bin/bash
SCRIPTS_DIR := scripts
FISH_DIR := .config/fish

# Required tools — gate targets fail if these are missing
REQUIRED_TOOLS := shellcheck shfmt python3

# ============================================================================
# Primary Targets
# ============================================================================

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1;33m%-15s\033[0m %s\n", $$1, $$2}'

test: check-deps lint smoke-test ## Run gate checks (CI tier)

lint: fish-syntax json-validate ## Gate linters (currently passing checks)

lint-strict: shellcheck-strict shfmt-check fish-syntax json-validate yaml-validate ## All linters (advisory)

setup: ## Run setup.sh with default profile
	bash $(SCRIPTS_DIR)/setup.sh

setup-dry-run: ## Preview setup without changes
	bash $(SCRIPTS_DIR)/setup.sh --dry-run

# ============================================================================
# Dependency Check
# ============================================================================

check-deps: ## Verify required tools are installed
	@missing=""; \
	for tool in $(REQUIRED_TOOLS); do \
		if ! command -v "$$tool" >/dev/null 2>&1; then \
			missing="$$missing $$tool"; \
		fi; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "Error: missing required tools:$$missing"; \
		echo "Install via: brew install shellcheck shfmt python3"; \
		exit 1; \
	fi

# ============================================================================
# Linting Targets
# ============================================================================

shellcheck: ## Run shellcheck (error-level, gate)
	@echo "Running shellcheck (errors only)..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shellcheck -S error {} +

shellcheck-strict: ## Run shellcheck (warning-level, advisory)
	@echo "Running shellcheck (strict)..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shellcheck -S warning {} +

shfmt-check: ## Check shell script formatting (advisory)
	@echo "Checking shell formatting..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shfmt -d -i 4 -ci {} +

fmt: ## Auto-format shell scripts
	@echo "Formatting shell scripts..."
	@find $(SCRIPTS_DIR) -name "*.sh" -type f -exec shfmt -w -i 4 -ci {} +

fish-syntax: ## Validate Fish shell syntax (skips if fish not installed)
	@echo "Checking Fish syntax..."
	@if command -v fish >/dev/null 2>&1; then \
		find $(FISH_DIR) -name "*.fish" -type f -exec fish -n {} +; \
	else \
		echo "  fish not installed, skipping"; \
	fi

json-validate: ## Validate JSON files (skips JSONC/vscode files)
	@echo "Validating JSON..."
	@exit_code=0; \
	find . -name "*.json" \
		-not -path "./.git/*" \
		-not -path "./node_modules/*" \
		-not -path "./.beads/*" \
		-not -path "./.config/vscode/*" \
		-print0 | while IFS= read -r -d '' file; do \
		if ! python3 -m json.tool "$$file" > /dev/null 2>&1; then \
			echo "  Invalid JSON: $$file"; \
			exit_code=1; \
		fi; \
	done; \
	exit $$exit_code

yaml-validate: ## Validate YAML files (skips if yamllint not installed)
	@echo "Validating YAML..."
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -d relaxed .; \
	else \
		echo "  yamllint not installed, skipping"; \
	fi

# ============================================================================
# Testing Targets
# ============================================================================

smoke-test: ## Run smoke test suite
	bash $(SCRIPTS_DIR)/smoke-test.sh

validate: check-deps lint smoke-test check-dirty ## Full CI gate (test + clean tree)

check-dirty: ## Verify no uncommitted changes to tracked files
	@echo "Checking for uncommitted changes to tracked files..."
	@if [ -n "$$(git diff --name-only)" ] || [ -n "$$(git diff --staged --name-only)" ]; then \
		echo "Error: tracked files modified after tests:"; \
		git diff --name-only; \
		git diff --staged --name-only; \
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
