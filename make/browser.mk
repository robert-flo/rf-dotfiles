# ════════════════════════════════════════════════════════════════════════════════
# 🌐 BROWSER FLAGS - Evidence harness for Chromium-family flag files
# ════════════════════════════════════════════════════════════════════════════════
# Runs scripts/browser-flags-bench against a temporary profile in the live session.
# WARNING: opens real browser windows on screen (~60 s with default values).

BROWSER_BIN   ?= /opt/google/chrome/chrome
BROWSER_FLAGS ?= $(CURDIR)/dot_config/chrome-flags.conf
BROWSER_LABEL ?= $(notdir $(BROWSER_FLAGS))
BENCH_ARGS    ?=

.PHONY: help-browser browser-bench browser-flags-check

help-browser: ## Show browser flag evidence targets
	@printf "\n"
	@printf "$(CYAN)Browser Flags$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make browser-flags-check$(NC)  Check every flag of BROWSER_FLAGS exists in BROWSER_BIN\n"
	@printf "  $(GREEN)make browser-bench$(NC)        Measure BROWSER_FLAGS in a temp profile (opens windows ~60 s)\n"
	@printf "  $(DIM)  vars: BROWSER_BIN, BROWSER_FLAGS, BROWSER_LABEL, BENCH_ARGS (e.g. --codecs h264)$(NC)\n"

browser-flags-check: ## Check that each flag in BROWSER_FLAGS exists in BROWSER_BIN
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔎 browser-flags-check · $(BROWSER_LABEL)$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] scripts/browser-flags-bench check-flags -b $(BROWSER_BIN) -f $(BROWSER_FLAGS)\n"; \
	else \
		"$(CURDIR)/scripts/browser-flags-bench" check-flags -b "$(BROWSER_BIN)" -f "$(BROWSER_FLAGS)"; \
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
		printf "  ▶ [dry-run] scripts/browser-flags-bench -b $(BROWSER_BIN) -f $(BROWSER_FLAGS) -l $(BROWSER_LABEL) $(BENCH_ARGS)\n"; \
	else \
		"$(CURDIR)/scripts/browser-flags-bench" -b "$(BROWSER_BIN)" -f "$(BROWSER_FLAGS)" -l "$(BROWSER_LABEL)" $(BENCH_ARGS); \
	fi
