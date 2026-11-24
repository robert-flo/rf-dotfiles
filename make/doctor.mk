# ════════════════════════════════════════════════════════════════════════════════
# 🩺 DOCTOR - Tool availability, SSoT manifest, and declarative symlinks
# ════════════════════════════════════════════════════════════════════════════════

PACKAGES_FILE ?= $(CURDIR)/.chezmoidata/packages.json

.PHONY: help-doctor doctor

help-doctor: ## Show doctor diagnostic targets
	@printf "\n"
	@printf "$(CYAN)Diagnostics$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make doctor$(NC)               Check required tools, SSoT manifest, and symlinks\n"

doctor: ## Check required tools, packages.json, and declarative symlinks
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🩺 doctor · rf-dotfiles environment diagnostics$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] check tools (chezmoi, jq, shellcheck, git), packages.json, and symlinks\n"; \
	else \
		ERRORS=0; \
		for tool in chezmoi jq shellcheck git; do \
			if command -v "$$tool" > /dev/null 2>&1; then \
				printf "$(GREEN)  ✓ tool:$(NC) $$tool ($$(command -v "$$tool"))\n"; \
			else \
				printf "$(RED)  ✗ missing required tool:$(NC) $$tool\n"; \
				ERRORS=1; \
			fi; \
		done; \
		if [ -f "$(PACKAGES_FILE)" ]; then \
			printf "$(GREEN)  ✓ manifest:$(NC) $(PACKAGES_FILE)\n"; \
		else \
			printf "$(RED)  ✗ missing manifest:$(NC) $(PACKAGES_FILE)\n"; \
			ERRORS=1; \
		fi; \
		while IFS= read -r sym_path; do \
			sym=$${sym_path#"$(CURDIR)/"}; \
			TARGET=$$(tr -d '\n' < "$$sym_path"); \
			if [ -e "$$TARGET" ]; then \
				printf "$(GREEN)  ✓ symlink:$(NC) $$sym -> $$TARGET\n"; \
			else \
				printf "$(YELLOW)  ⚠ symlink target missing on host:$(NC) $$sym -> $$TARGET\n"; \
			fi; \
		done < <(find "$(CURDIR)" -maxdepth 4 -name 'symlink_*' | sort); \
		if [ "$$ERRORS" -ne 0 ]; then \
			exit 1; \
		fi; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run full check:       $(BLUE)make check$(NC)\n"
	@printf "  • check git status:     $(BLUE)make git-status$(NC)\n\n"
endif
