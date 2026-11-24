# ════════════════════════════════════════════════════════════════════════════════
# ☀️ DAILY - Tablero, pérdida local y pull de la copia que chezmoi lee
# ════════════════════════════════════════════════════════════════════════════════

CHEZMOI ?= chezmoi
GIT ?= git
GIT_REMOTE ?= origin
BASE_BRANCH ?= master
RF_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DAILY_SH := $(RF_ROOT)/scripts/rf-make-daily.sh

.PHONY: help-daily morning lose pull

help-daily: ## Show daily chezmoi targets
	@printf "\n"
	@printf "$(CYAN)Día a día$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make morning$(NC)              Commit, perfil, sudo, archivos a perder y scripts\n"
	@printf "  $(GREEN)make lose$(NC)                 Archivos del home que un apply pisaría\n"
	@printf "  $(GREEN)make pull$(NC)                 Actualiza la copia de chezmoi y el clon invocador\n"

morning: ## Read-only board for the chezmoi source copy (may fetch)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)☀️  morning · copia que chezmoi lee$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	source="$$($(CHEZMOI) source-path)"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(GIT) -C %s fetch $(GIT_REMOTE) $(BASE_BRANCH)\n" "$$source"; \
	else \
		$(GIT) -C "$$source" fetch $(GIT_REMOTE) $(BASE_BRANCH); \
	fi; \
	commit="$$($(GIT) -C "$$source" rev-parse HEAD)"; \
	behind="$$($(GIT) -C "$$source" rev-list --count HEAD..$(GIT_REMOTE)/$(BASE_BRANCH))"; \
	profile="$$($(DAILY_SH) profile)"; \
	sudo_state="$$($(DAILY_SH) sudo-state)"; \
	status_text="$$($(CHEZMOI) --color=false status -S "$$source")"; \
	printf "commit: %s\n" "$$commit"; \
	printf "behind: %s\n" "$$behind"; \
	printf "profile: %s\n" "$$profile"; \
	printf "sudo: %s\n" "$$sudo_state"; \
	printf "lose:\n"; \
	printf '%s\n' "$$status_text" | $(DAILY_SH) lose-paths; \
	printf "scripts:\n"; \
	printf '%s\n' "$$status_text" | $(DAILY_SH) script-paths
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif

lose: ## List home files an apply would modify or delete
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)⚠️  lose · archivos del home que un apply pisaría$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	source="$$($(CHEZMOI) source-path)"; \
	files="$$($(CHEZMOI) --color=false status -S "$$source" | $(DAILY_SH) lose-paths)"; \
	if [ -n "$$files" ]; then \
		printf '%s\n' "$$files"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ nada que perder$(NC)\n"
endif

pull: ## Pull origin/master into the chezmoi source and the invoking clone
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)⬇️  pull · origin/$(BASE_BRANCH) sin apply$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	source="$$($(CHEZMOI) source-path)"; \
	source_real="$$(realpath "$$source")"; \
	invoker_real="$$(realpath "$(CURDIR)")"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(GIT) -C %s pull --rebase --autostash $(GIT_REMOTE) $(BASE_BRANCH)\n" "$$source_real"; \
		if [ "$$source_real" != "$$invoker_real" ]; then \
			printf "  ▶ [dry-run] $(GIT) -C %s pull --rebase --autostash $(GIT_REMOTE) $(BASE_BRANCH)\n" "$$invoker_real"; \
		fi; \
	else \
		$(GIT) -C "$$source_real" pull --rebase --autostash $(GIT_REMOTE) $(BASE_BRANCH); \
		if [ "$$source_real" != "$$invoker_real" ]; then \
			$(GIT) -C "$$invoker_real" pull --rebase --autostash $(GIT_REMOTE) $(BASE_BRANCH); \
		fi; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
