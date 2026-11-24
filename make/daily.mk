# ════════════════════════════════════════════════════════════════════════════════
# ☀️ DAILY - Tablero, pérdida local y pull de la copia que chezmoi lee
# ════════════════════════════════════════════════════════════════════════════════

CHEZMOI_BIN ?= chezmoi
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
	source="$$($(DAILY_SH) source --canonical)"; \
	fetch_state=no; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(GIT) -C %s fetch $(GIT_REMOTE) $(BASE_BRANCH)\n" "$$source"; \
	elif $(GIT) -C "$$source" fetch $(GIT_REMOTE) $(BASE_BRANCH); then \
		fetch_state=yes; \
	fi; \
	commit="$$($(GIT) -C "$$source" rev-parse HEAD)"; \
	if $(GIT) -C "$$source" rev-parse --verify $(GIT_REMOTE)/$(BASE_BRANCH) >/dev/null 2>&1; then \
		origin="$$($(GIT) -C "$$source" rev-parse $(GIT_REMOTE)/$(BASE_BRANCH))"; \
		behind="$$($(GIT) -C "$$source" rev-list --count HEAD..$(GIT_REMOTE)/$(BASE_BRANCH))"; \
		ahead="$$($(GIT) -C "$$source" rev-list --count $(GIT_REMOTE)/$(BASE_BRANCH)..HEAD)"; \
		if [ "$$commit" = "$$origin" ]; then same=yes; else same=no; fi; \
	else \
		origin=unknown; behind=unknown; ahead=unknown; same=unknown; \
	fi; \
	profile="$$($(DAILY_SH) profile)"; \
	sudo_state="$$($(DAILY_SH) sudo-state)"; \
	status_text="$$($(CHEZMOI_BIN) --color=false status -S "$$source")"; \
	printf "commit: %s\n" "$$commit"; \
	printf "origin: %s\n" "$$origin"; \
	printf "same: %s\n" "$$same"; \
	printf "behind: %s\n" "$$behind"; \
	printf "ahead: %s\n" "$$ahead"; \
	printf "fetch: %s\n" "$$fetch_state"; \
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
	show=$(if $(EMBEDDED),0,1); \
	set +e; \
	$(DAILY_SH) lose; \
	code=$$?; \
	set -e; \
	if [ "$$code" -eq 0 ]; then \
		if [ "$$show" -eq 1 ]; then \
			printf "\n$(GREEN)  ✓ nada que perder$(NC)\n"; \
			printf "\n$(YELLOW)📋 Qué hacer ahora:$(NC)\n"; \
			printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
			printf "  • aplicar cambios al home: $(BLUE)make safe$(NC)\n\n"; \
		fi; \
	elif [ "$$code" -eq 1 ]; then \
		if [ "$$show" -eq 1 ]; then \
			printf "\n$(YELLOW)  ⚠ estos archivos en \$$HOME tienen cambios locales que un apply pisaría$(NC)\n"; \
			printf "\n$(YELLOW)📋 Qué hacer ahora:$(NC)\n"; \
			printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
			printf "  1. Ver qué cambió exactamente:        $(BLUE)make diff$(NC)\n"; \
			printf "  2. Conservar tus cambios en el repo:  $(BLUE)chezmoi re-add <archivo>$(NC)\n"; \
			printf "  3. Descartar cambios locales:         $(BLUE)make apply$(NC) $(DIM)(o make apply DRY_RUN=1 para previsualizar)$(NC)\n\n"; \
		fi; \
	else \
		exit "$$code"; \
	fi

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
	@$(DAILY_SH) lose
	@set -euo pipefail; \
	source="$$($(DAILY_SH) source)"; \
	profile="$$($(DAILY_SH) profile)"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] env CHEZMOI_PROFILE=%s $(CHEZMOI_BIN) apply -S %s\n" "$$profile" "$$source"; \
	else \
		env CHEZMOI_PROFILE="$$profile" $(CHEZMOI_BIN) apply -S "$$source"; \
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
			printf "  ▶ [dry-run] $(CHEZMOI_BIN) execute-template --file %s/%s -S %s | bash\n" "$$source" "$$tmpl" "$$source"; \
		else \
			rendered="$$($(CHEZMOI_BIN) execute-template --file "$$source/$$tmpl" -S "$$source")"; \
			printf '%s\n' "$$rendered" | bash; \
		fi; \
	done
