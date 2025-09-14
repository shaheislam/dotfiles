# Unified CV Generation Workflow
# Single streamlined workflow with metadata-based matching and ATS optimization

.PHONY: help unified clean test validate stats

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
	@echo "  make unified RECRUITER=Google TYPE=perm SALARY=150K"
	@echo "  make test                                           # Test LaTeX compilation"
	@echo "  make stats                                          # Show CV statistics"

unified: ## Generate both standard and ATS-optimized CVs with metadata matching
	@echo "$(GREEN)🚀 Unified CV Generation...$(NC)"
	@python3 $(SCRIPTS_DIR)/cv-generator-unified.py \
		--recruiter "$(RECRUITER)" \
		--type "$(TYPE)" \
		--salary "$(SALARY)" \
		--open
	@echo "$(GREEN)✅ Complete: Standard + ATS versions generated$(NC)"

test: ## Test CV compilation
	@echo "$(YELLOW)Testing LaTeX compilation...$(NC)"
	@pdflatex -interaction=nonstopmode $(CV_FILE) > /dev/null 2>&1 && \
		echo "$(GREEN)✓ LaTeX compilation successful$(NC)" || \
		echo "$(RED)✗ LaTeX compilation failed$(NC)"


clean: ## Clean generated files
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	@rm -f $(OUTPUT_DIR)/*.aux $(OUTPUT_DIR)/*.log $(OUTPUT_DIR)/*.out
	@echo "$(GREEN)✓ Cleaned$(NC)"


validate: ## Validate all configuration files
	@echo "$(YELLOW)Validating configuration...$(NC)"
	@python3 -c "import yaml; yaml.safe_load(open('skill-taxonomy.yaml'))" && \
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