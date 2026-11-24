# ════════════════════════════════════════════════════════════════════════════════
# 🧭 HELP - Categorized command center
# ════════════════════════════════════════════════════════════════════════════════

.PHONY: help help-general

help: ## Show all rf-dotfiles commands
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)════════════════════════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(CYAN)  🏠 rf-dotfiles · chezmoi SSoT command center$(NC)\n"
	@printf "$(CYAN)════════════════════════════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@printf "  $(DIM)Manage dotfiles across clavis, nyxuri, and omarchy profiles safely.$(NC)\n"
	@printf "  $(DIM)Set DRY_RUN=1 to preview mutating targets without changing \$$HOME.$(NC)\n"
endif
	@$(MAKE) -s --no-print-directory help-general
ifndef EMBEDDED
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • show this menu:       $(BLUE)make help$(NC)\n"
	@printf "  • dry-run convention:   $(DIM)make <target> DRY_RUN=1$(NC)\n\n"
endif

help-general: ## Show general targets
	@printf "\n"
	@printf "$(CYAN)General$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make help$(NC)                 Show this categorized command center\n"
