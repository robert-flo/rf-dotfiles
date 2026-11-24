# ════════════════════════════════════════════════════════════════════════════════
# ☀️ DAILY - Tablero, pérdida local y pull de la copia que chezmoi lee
# ════════════════════════════════════════════════════════════════════════════════

CHEZMOI ?= chezmoi
GIT ?= git
GIT_REMOTE ?= origin
BASE_BRANCH ?= master
RF_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DAILY_SH := $(RF_ROOT)/scripts/rf-make-daily.sh

.PHONY: help-daily morning lose pull safe root

ROOT_SCRIPTS := \
	run_onchange_before_01-install-packages.sh.tmpl \
	run_onchange_after_02-install-system-tools.sh.tmpl

help-daily: ## Show daily chezmoi targets
	@printf "\n"
	@printf "$(CYAN)Día a día$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make morning$(NC)              Commit, perfil, sudo, archivos a perder y scripts\n"
	@printf "  $(GREEN)make lose$(NC)                 Archivos del home que un apply pisaría\n"
	@printf "  $(GREEN)make pull$(NC)                 Actualiza la copia de chezmoi y el clon invocador\n"
	@printf "  $(GREEN)make safe$(NC)                 Aplica el home solo si lose está vacío\n"
	@printf "  $(GREEN)make root$(NC)                 Instala herramientas, hook y paquetes; no toca el home\n"

morning: ## Read-only board for the chezmoi source copy (may fetch)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)☀️  morning · copia que chezmoi lee$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	source="$$($(DAILY_SH) source)"; \
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
	source="$$($(DAILY_SH) source)"; \
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
	source="$$($(DAILY_SH) source)"; \
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

safe: ## Apply the home only when lose is empty
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🛟 safe · apply del home solo si no hay nada que perder$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	source="$$($(DAILY_SH) source)"; \
	files="$$($(CHEZMOI) --color=false status -S "$$source" | $(DAILY_SH) lose-paths)"; \
	if [ -n "$$files" ]; then \
		printf '%s\n' "$$files"; \
		exit 1; \
	fi; \
	profile="$$($(DAILY_SH) profile)"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] env CHEZMOI_PROFILE=%s $(CHEZMOI) apply -S %s\n" "$$profile" "$$source"; \
	else \
		env CHEZMOI_PROFILE="$$profile" $(CHEZMOI) apply -S "$$source"; \
	fi

root: ## Run root install scripts only; do not apply the home tree
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔐 root · herramientas, hook y paquetes$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$$($(DAILY_SH) sudo-state)" != yes ]; then \
		printf 'sudo: no\n'; \
		printf 'root: no instalada (sin sudo -n)\n'; \
		exit 1; \
	fi; \
	source="$$($(DAILY_SH) source)"; \
	for tmpl in $(ROOT_SCRIPTS); do \
		if [ "$(DRY_RUN)" = "1" ]; then \
			printf "  ▶ [dry-run] $(CHEZMOI) execute-template --file %s/%s -S %s | bash\n" "$$source" "$$tmpl" "$$source"; \
		else \
			rendered="$$($(CHEZMOI) execute-template --file "$$source/$$tmpl" -S "$$source")"; \
			printf '%s\n' "$$rendered" | bash; \
		fi; \
	done
