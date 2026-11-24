# ════════════════════════════════════════════════════════════════════════════════
# 🌐 BROWSER FLAGS - Evidence harness for Chromium-family flag files
# ════════════════════════════════════════════════════════════════════════════════
# Runs scripts/browser-flags-bench against a temporary profile in the live session.
# WARNING: opens real browser windows on screen (~60 s with default values).

BROWSER_BIN   ?=
BROWSER_FLAGS ?= $(CURDIR)/dot_config/chrome-flags.conf
BROWSER_LABEL ?= $(notdir $(BROWSER_FLAGS))
BENCH_ARGS    ?=

.PHONY: help-browser browser-bench browser-flags-check browser-flags-check-all

help-browser: ## Show browser flag evidence targets
	@printf "\n"
	@printf "$(CYAN)Browser Flags$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make browser-flags-check$(NC)  Check every flag of BROWSER_FLAGS exists in the browser binary\n"
	@printf "  $(GREEN)make browser-flags-check-all$(NC)  Check each Chromium-family flag file against its own installed binary\n"
	@printf "  $(GREEN)make browser-bench$(NC)        Measure BROWSER_FLAGS in a temp profile (opens windows ~60 s)\n"
	@printf "  $(DIM)  vars: BROWSER_BIN (default: Chrome stable), BROWSER_FLAGS, BROWSER_LABEL, BENCH_ARGS (e.g. --codecs h264)$(NC)\n"

browser-flags-check: ## Check that each flag in BROWSER_FLAGS exists in BROWSER_BIN
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔎 browser-flags-check · $(BROWSER_LABEL)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] scripts/browser-flags-bench check-flags $(if $(BROWSER_BIN),-b $(BROWSER_BIN)) -f $(BROWSER_FLAGS)\n"; \
	else \
		"$(CURDIR)/scripts/browser-flags-bench" check-flags $(if $(BROWSER_BIN),-b "$(BROWSER_BIN)") -f "$(BROWSER_FLAGS)"; \
	fi

# <flag file>:<binary> for every browser the dotfiles configure; missing binaries are skipped.
BROWSER_CHECKS := chrome-flags.conf:/opt/google/chrome/chrome \
	chrome-beta-flags.conf:/opt/google/chrome-beta/chrome \
	chromium-flags.conf.tmpl:/usr/lib/chromium/chromium \
	microsoft-edge-stable-flags.conf:/opt/microsoft/msedge/msedge \
	brave-origin-flags.conf:/opt/brave-origin-bin/brave

browser-flags-check-all: ## Check every browser's flag file against its installed binary
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔎 browser-flags-check-all$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] check-flags for: $(BROWSER_CHECKS)\n"; \
	else \
		tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT; rc=0; \
		for pair in $(BROWSER_CHECKS); do \
			file="$(CURDIR)/dot_config/$${pair%%:*}"; bin="$${pair#*:}"; \
			[ -x "$$bin" ] || { printf "  - skip %s (no %s)\n" "$${pair%%:*}" "$$bin"; continue; }; \
			case "$$file" in *.tmpl) \
				CHEZMOI_PROFILE=clavis chezmoi execute-template < "$$file" > "$$tmp/$$(basename "$${file%.tmpl}")"; \
				file="$$tmp/$$(basename "$${file%.tmpl}")" ;; \
			esac; \
			"$(CURDIR)/scripts/browser-flags-bench" check-flags -b "$$bin" -f "$$file" || rc=1; \
		done; \
		exit $$rc; \
	fi

browser-bench: ## Measure BROWSER_FLAGS (decode, CPU H.264/VP9, typing, stability) in a temp profile
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🧪 browser-bench · $(BROWSER_LABEL)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "$(YELLOW)  ⚠ opens real browser windows on this screen for about a minute$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] scripts/browser-flags-bench $(if $(BROWSER_BIN),-b $(BROWSER_BIN)) -f $(BROWSER_FLAGS) -l $(BROWSER_LABEL) $(BENCH_ARGS)\n"; \
	else \
		"$(CURDIR)/scripts/browser-flags-bench" $(if $(BROWSER_BIN),-b "$(BROWSER_BIN)") -f "$(BROWSER_FLAGS)" -l "$(BROWSER_LABEL)" $(BENCH_ARGS); \
	fi
