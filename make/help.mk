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
	@$(MAKE) -s --no-print-directory help-chezmoi
	@$(MAKE) -s --no-print-directory help-packages
	@$(MAKE) -s --no-print-directory help-lint
	@$(MAKE) -s --no-print-directory help-browser
	@$(MAKE) -s --no-print-directory help-doctor
	@$(MAKE) -s --no-print-directory help-git
	@$(MAKE) -s --no-print-directory help-daily
ifndef EMBEDDED
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check dotfile drift:  $(BLUE)make status$(NC)\n"
	@printf "  • see what apply loses: $(BLUE)make lose$(NC)  $(DIM)(apply overwrites local changes)$(NC)\n"
	@printf "  • preview apply:        $(BLUE)make apply DRY_RUN=1$(NC)\n"
	@printf "  • verify exclusions:    $(BLUE)make verify$(NC)\n\n"
endif

help-general: ## Show general targets
	@printf "\n"
	@printf "$(CYAN)General$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make help$(NC)                 Show this categorized command center\n"
