# ════════════════════════════════════════════════════════════════════════════════
# 🏠 CHEZMOI - Profile-aware dotfile lifecycle & verification
# ════════════════════════════════════════════════════════════════════════════════

CHEZMOI_BIN ?= chezmoi
CHEZMOI_PROFILES ?= clavis nyxuri omarchy

.PHONY: help-chezmoi status diff apply apply-clavis apply-nyxuri apply-omarchy managed ignored verify

help-chezmoi: ## Show Chezmoi lifecycle targets
	@printf "\n"
	@printf "$(CYAN)Chezmoi Lifecycle$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make status$(NC)               Show pending changes against the chezmoi source copy\n"
	@printf "  $(GREEN)make diff$(NC)                 Show full diff against the chezmoi source copy\n"
	@printf "  $(GREEN)make apply$(NC)                Apply dotfiles for current user (DRY_RUN=1)\n"
	@printf "  $(GREEN)make apply-clavis$(NC)         Apply with CHEZMOI_PROFILE=clavis (DRY_RUN=1)\n"
	@printf "  $(GREEN)make apply-nyxuri$(NC)         Apply with CHEZMOI_PROFILE=nyxuri (DRY_RUN=1)\n"
	@printf "  $(GREEN)make apply-omarchy$(NC)        Apply with CHEZMOI_PROFILE=omarchy (DRY_RUN=1)\n"
	@printf "  $(GREEN)make managed$(NC)              List managed paths for active profile\n"
	@printf "  $(GREEN)make ignored$(NC)              List ignored paths for active profile\n"
	@printf "  $(GREEN)make verify$(NC)               Verify templates and Makefile/make/* exclusion\n"

status: ## Show chezmoi status using the production source copy
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📊 status · chezmoi drift (copia de producción)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) $(CHEZMOI_BIN) status -S "$(shell $(DAILY_SH) source)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • inspect full diff:    $(BLUE)make diff$(NC)\n"
	@printf "  • preview apply:        $(BLUE)make apply DRY_RUN=1$(NC)\n\n"
endif

diff: ## Show chezmoi diff using the production source copy
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 diff · chezmoi changes (copia de producción)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) $(CHEZMOI_BIN) --no-pager diff -S "$(shell $(DAILY_SH) source)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • preview apply:        $(BLUE)make apply DRY_RUN=1$(NC)\n"
	@printf "  • verify templates:     $(BLUE)make verify$(NC)\n\n"
endif

apply: ## Apply dotfiles using repo as source (supports DRY_RUN=1)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🚀 apply · chezmoi apply (-S $(CURDIR))$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) $(CHEZMOI_BIN) apply -S "$(CURDIR)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check drift:          $(BLUE)make status$(NC)\n"
	@printf "  • verify exclusions:    $(BLUE)make verify$(NC)\n\n"
endif

apply-clavis apply-nyxuri apply-omarchy: apply-%: ## Apply dotfiles for a specific CHEZMOI_PROFILE (supports DRY_RUN=1)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🚀 apply-$* · chezmoi apply (CHEZMOI_PROFILE=$*)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) env CHEZMOI_PROFILE="$*" $(CHEZMOI_BIN) apply -S "$(CURDIR)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check drift:          $(BLUE)make status$(NC)\n"
	@printf "  • verify exclusions:    $(BLUE)make verify$(NC)\n\n"
endif

managed: ## List chezmoi managed paths
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📂 managed · tracked paths (-S $(CURDIR))$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) $(CHEZMOI_BIN) managed -S "$(CURDIR)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • list ignored paths:   $(BLUE)make ignored$(NC)\n"
	@printf "  • verify exclusions:    $(BLUE)make verify$(NC)\n\n"
endif

ignored: ## List chezmoi ignored paths
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🚫 ignored · excluded paths (-S $(CURDIR))$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(EXEC) $(CHEZMOI_BIN) ignored -S "$(CURDIR)"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • list managed paths:   $(BLUE)make managed$(NC)\n"
	@printf "  • verify exclusions:    $(BLUE)make verify$(NC)\n\n"
endif

verify: ## Verify .chezmoiignore.tmpl rendering and Makefile/make/* exclusion across profiles
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🛡️  verify · template & exclusion checks$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(CHEZMOI_BIN) execute-template -S $(CURDIR) < $(CURDIR)/.chezmoiignore.tmpl\n"; \
		printf "  ▶ [dry-run] check Makefile and make/* excluded for profiles: $(CHEZMOI_PROFILES)\n"; \
	else \
		for p in $(CHEZMOI_PROFILES); do \
			CHEZMOI_PROFILE="$$p" $(CHEZMOI_BIN) execute-template -S "$(CURDIR)" < "$(CURDIR)/.chezmoiignore.tmpl" > /dev/null; \
			MANAGED=$$(CHEZMOI_PROFILE="$$p" $(CHEZMOI_BIN) managed -S "$(CURDIR)"); \
			IGNORED=$$(CHEZMOI_PROFILE="$$p" $(CHEZMOI_BIN) ignored -S "$(CURDIR)"); \
			if printf '%s\n' "$$MANAGED" | grep -Eq '^(Makefile|make/)'; then \
				printf "$(RED)  ✗ Makefile or make/* leaked into managed paths for profile=$$p$(NC)\n"; \
				exit 1; \
			fi; \
			if ! printf '%s\n' "$$IGNORED" | grep -Fxq 'Makefile' || ! printf '%s\n' "$$IGNORED" | grep -Fxq 'make'; then \
				printf "$(RED)  ✗ Makefile or make not found in ignored paths for profile=$$p$(NC)\n"; \
				exit 1; \
			fi; \
			printf "$(GREEN)  ✓ profile=$$p template OK and excludes Makefile + make/*$(NC)\n"; \
		done; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check drift:          $(BLUE)make status$(NC)\n"
	@printf "  • preview apply:        $(BLUE)make apply DRY_RUN=1$(NC)\n\n"
endif
