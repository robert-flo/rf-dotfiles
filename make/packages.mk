# ════════════════════════════════════════════════════════════════════════════════
# 📦 PACKAGES - SSoT validation & summary (.chezmoidata/packages.json)
# ════════════════════════════════════════════════════════════════════════════════

JQ ?= jq
PACKAGES_FILE ?= $(CURDIR)/.chezmoidata/packages.json

.PHONY: help-packages packages-check packages-summary packages-missing

help-packages: ## Show package manifest targets
	@printf "\n"
	@printf "$(CYAN)Packages SSoT$(NC)\n"
	@printf "$(CYAN)──────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make packages-check$(NC)       Validate .chezmoidata/packages.json schema & duplicates\n"
	@printf "  $(GREEN)make packages-summary$(NC)     Show package counts per repository channel\n"
	@printf "  $(GREEN)make packages-missing$(NC)     List declared packages not installed on this host\n"

packages-check: ## Validate .chezmoidata/packages.json with jq
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 packages-check · validate SSoT manifest$(NC)\n"
	@printf "$(CYAN)──────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(JQ) -e schema & duplicate check on $(PACKAGES_FILE)\n"; \
	else \
		$(JQ) -e '.packages | (.official | type == "array") and (.personal | type == "array") and (.aur | type == "array")' "$(PACKAGES_FILE)" > /dev/null; \
		DUPES=$$($(JQ) -r '[.packages.official[], .packages.personal[], .packages.aur[]] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$(PACKAGES_FILE)"); \
		if [ -n "$$DUPES" ]; then \
			printf "$(RED)  ✗ duplicate package entries found:$(NC)\n"; \
			printf '%s\n' "$$DUPES" | sed 's/^/    - /'; \
			exit 1; \
		fi; \
		printf "$(GREEN)  ✓ $(PACKAGES_FILE) is valid JSON with official, personal, and aur arrays$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • view counts:          $(BLUE)make packages-summary$(NC)\n"
	@printf "  • find missing pkgs:    $(BLUE)make packages-missing$(NC)\n\n"
endif

packages-summary: ## Show package counts by channel
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📊 packages-summary · SSoT package counts$(NC)\n"
	@printf "$(CYAN)──────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(JQ) summary on $(PACKAGES_FILE)\n"; \
	else \
		OFF=$$($(JQ) '.packages.official | length' "$(PACKAGES_FILE)"); \
		PER=$$($(JQ) '.packages.personal | length' "$(PACKAGES_FILE)"); \
		AUR=$$($(JQ) '.packages.aur | length' "$(PACKAGES_FILE)"); \
		TOT=$$((OFF + PER + AUR)); \
		printf "  $(DIM)official:$(NC)  $$OFF\n"; \
		printf "  $(DIM)personal:$(NC)  $$PER\n"; \
		printf "  $(DIM)aur:$(NC)       $$AUR\n"; \
		printf "  $(BOLD)total:$(NC)     $$TOT\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • validate manifest:    $(BLUE)make packages-check$(NC)\n"
	@printf "  • find missing pkgs:    $(BLUE)make packages-missing$(NC)\n\n"
endif

packages-missing: ## List declared packages not installed locally
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔍 packages-missing · compare SSoT against pacman$(NC)\n"
	@printf "$(CYAN)──────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] compare $(PACKAGES_FILE) against pacman -Qq\n"; \
	elif ! command -v pacman > /dev/null 2>&1; then \
		printf "$(YELLOW)  ⚠ pacman not available on this host$(NC)\n"; \
	else \
		INSTALLED=$$(pacman -Qq); \
		MISSING=$$(comm -23 <($(JQ) -r '.packages.official[], .packages.personal[], .packages.aur[]' "$(PACKAGES_FILE)" | sort -u) <(printf '%s\n' "$$INSTALLED" | sort -u)); \
		if [ -z "$$MISSING" ]; then \
			printf "$(GREEN)  ✓ all declared packages are installed$(NC)\n"; \
		else \
			COUNT=$$(printf '%s\n' "$$MISSING" | wc -l | tr -d ' '); \
			printf "$(YELLOW)  ⚠ $$COUNT declared package(s) not installed:$(NC)\n"; \
			printf '%s\n' "$$MISSING" | sed 's/^/    - /'; \
		fi; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • view counts:          $(BLUE)make packages-summary$(NC)\n"
	@printf "  • validate manifest:    $(BLUE)make packages-check$(NC)\n\n"
endif
