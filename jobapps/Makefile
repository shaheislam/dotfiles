# CV Generation Workflow Makefile
# Simplifies CV generation with single commands

.PHONY: help generate analyze optimize clean test batch

# Variables
SCRIPTS_DIR = ../scripts/cv
OUTPUT_DIR = generated
JOB_FILE ?= jobdesciption.md
CV_FILE ?= CV.tex

# Color output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)CV Generation Workflow$(NC)"
	@echo "Usage: make [target] [ARGS]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make generate RECRUITER=Google TYPE=perm SALARY=150K"
	@echo "  make analyze JOB_FILE=google_sre.md"
	@echo "  make optimize"

generate: ## Generate CV with parameters (RECRUITER, TYPE, SALARY)
	@echo "$(GREEN)Generating CV...$(NC)"
	python $(SCRIPTS_DIR)/cv-generator.py \
		--recruiter "$(RECRUITER)" \
		--date "$$(date +%d%m%y)" \
		--type "$(TYPE)" \
		--salary "$(SALARY)" \
		--verbose

quick: ## Quick CV generation with metadata matching
	@echo "$(GREEN)Quick CV Generation with Smart Matching...$(NC)"
	python $(SCRIPTS_DIR)/cv-generator-enhanced.py \
		--job $(JOB_FILE) \
		--cv $(CV_FILE) \
		--output "CV_$$(date +%Y%m%d_%H%M%S)"

analyze: ## Analyze job description
	@echo "$(YELLOW)Analyzing Job Description...$(NC)"
	@python $(SCRIPTS_DIR)/job-analyzer.py $(JOB_FILE)

optimize: ## Run full optimization pipeline
	@echo "$(GREEN)Running CV Optimization Pipeline...$(NC)"
	@python $(SCRIPTS_DIR)/cv-optimizer.py \
		--job $(JOB_FILE) \
		--cv $(CV_FILE) \
		--format html \
		--open

test: ## Test CV compilation
	@echo "$(YELLOW)Testing LaTeX compilation...$(NC)"
	@pdflatex -interaction=nonstopmode $(CV_FILE) > /dev/null 2>&1 && \
		echo "$(GREEN)✓ LaTeX compilation successful$(NC)" || \
		echo "$(RED)✗ LaTeX compilation failed$(NC)"

batch: ## Generate multiple CV versions for different focuses
	@echo "$(GREEN)Generating CV variants...$(NC)"
	@for focus in tech leadership impact; do \
		echo "  → Generating $$focus-focused version..."; \
		python $(SCRIPTS_DIR)/cv-generator-enhanced.py \
			--output "CV_$$focus_$$(date +%Y%m%d)" \
			--job $(JOB_FILE) \
			--cv $(CV_FILE); \
	done
	@echo "$(GREEN)✓ All variants generated$(NC)"

clean: ## Clean generated files
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	@rm -f $(OUTPUT_DIR)/*.aux $(OUTPUT_DIR)/*.log $(OUTPUT_DIR)/*.out
	@echo "$(GREEN)✓ Cleaned$(NC)"

install-deps: ## Install required dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@pip install -q pyyaml
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

validate: ## Validate all configuration files
	@echo "$(YELLOW)Validating configuration...$(NC)"
	@python -c "import yaml; yaml.safe_load(open('skill-taxonomy.yaml'))" && \
		echo "  $(GREEN)✓$(NC) skill-taxonomy.yaml valid" || \
		echo "  $(RED)✗$(NC) skill-taxonomy.yaml invalid"
	@test -f CV.tex && echo "  $(GREEN)✓$(NC) CV.tex exists" || echo "  $(RED)✗$(NC) CV.tex missing"
	@test -f skills.md && echo "  $(GREEN)✓$(NC) skills.md exists" || echo "  $(RED)✗$(NC) skills.md missing"

stats: ## Show CV statistics
	@echo "$(YELLOW)CV Statistics:$(NC)"
	@echo "  Bullet points in CV.tex: $$(grep -c '\\item' CV.tex)"
	@echo "  Achievements in skills.md: $$(grep -c '^- ' skills.md)"
	@echo "  Metadata tags: $$(grep -o '% (' CV.tex | wc -l)"
	@echo "  Generated CVs: $$(ls -1 $(OUTPUT_DIR)/*.pdf 2>/dev/null | wc -l)"

# Default target
.DEFAULT_GOAL := help