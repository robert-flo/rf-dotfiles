# ════════════════════════════════════════════════════════════════════════════════
# 🧪 LINT & TEST - ShellCheck, script tests, and composite check
# ════════════════════════════════════════════════════════════════════════════════

SHELLCHECK ?= shellcheck

.PHONY: help-lint lint test check

help-lint: ## Show lint, test, and check targets
	@printf "\n"
	@printf "$(CYAN)Quality & Checks$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make lint$(NC)                 Run shellcheck on scripts/yt-* and scripts/tests/*.sh\n"
	@printf "  $(GREEN)make test$(NC)                 Run test suites under scripts/tests/\n"
	@printf "  $(GREEN)make check$(NC)                Run verify, packages-check, lint, and test\n"

lint: ## Run shellcheck on repo shell scripts
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔎 lint · shellcheck scripts$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(SHELLCHECK) $(CURDIR)/scripts/yt-* $(CURDIR)/scripts/rf-make-daily.sh $(CURDIR)/scripts/tests/*.sh\n"; \
	else \
		$(SHELLCHECK) "$(CURDIR)"/scripts/yt-* "$(CURDIR)"/scripts/rf-make-daily.sh "$(CURDIR)"/scripts/tests/*.sh; \
		printf "$(GREEN)  ✓ shellcheck passed cleanly$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run script tests:     $(BLUE)make test$(NC)\n"
	@printf "  • run full check:       $(BLUE)make check$(NC)\n\n"
endif

test: ## Run test suites in scripts/tests/
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🧪 test · scripts/tests/*.sh$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] run bash on $(CURDIR)/scripts/tests/*.sh\n"; \
	else \
		for t in "$(CURDIR)"/scripts/tests/*.sh; do \
			printf "  $(DIM)running:$(NC) $$(basename "$$t")\n"; \
			bash "$$t"; \
		done; \
		printf "$(GREEN)  ✓ all script tests passed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run shellcheck:       $(BLUE)make lint$(NC)\n"
	@printf "  • run full check:       $(BLUE)make check$(NC)\n\n"
endif

check: ## Run all verification, package, lint, and test checks
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)✅ check · full rf-dotfiles verification suite$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(MAKE) -s --no-print-directory verify EMBEDDED=1
	@$(MAKE) -s --no-print-directory packages-check EMBEDDED=1
	@$(MAKE) -s --no-print-directory lint EMBEDDED=1
	@$(MAKE) -s --no-print-directory test EMBEDDED=1
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ all checks passed$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • inspect dotfile diff: $(BLUE)make diff$(NC)\n"
	@printf "  • check git status:     $(BLUE)make git-status$(NC)\n\n"
endif
