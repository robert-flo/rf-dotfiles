# ════════════════════════════════════════════════════════════════════════════════
# 🔀 GIT - Repository status & branch state against master
# ════════════════════════════════════════════════════════════════════════════════

GIT_REMOTE ?= origin
BASE_BRANCH ?= master

.PHONY: help-git git-status

help-git: ## Show Git status targets
	@printf "\n"
	@printf "$(CYAN)Git$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(GREEN)make git-status$(NC)           Show branch, drift vs $(GIT_REMOTE)/$(BASE_BRANCH), and worktree state\n"

git-status: ## Show current repository state
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📊 git-status · repository overview$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@set -euo pipefail; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] git status and branch comparison against $(GIT_REMOTE)/$(BASE_BRANCH)\n"; \
	elif git rev-parse --git-dir > /dev/null 2>&1; then \
		REMOTE_URL=$$(git remote get-url $(GIT_REMOTE) 2>/dev/null || true); \
		REPO_NAME=$$(printf '%s' "$$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
		BRANCH=$$(git branch --show-current); \
		AHEAD=$$(git rev-list --count $(GIT_REMOTE)/$(BASE_BRANCH)..HEAD 2>/dev/null || echo 0); \
		BEHIND=$$(git rev-list --count HEAD..$(GIT_REMOTE)/$(BASE_BRANCH) 2>/dev/null || echo 0); \
		STAGED=$$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNSTAGED=$$(git diff --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNTRACKED=$$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '); \
		printf "  $(DIM)repo:$(NC)      $$REPO_NAME\n"; \
		printf "  $(DIM)branch:$(NC)    $$BRANCH  $(DIM)(vs $(GIT_REMOTE)/$(BASE_BRANCH): ↑$$AHEAD ↓$$BEHIND)$(NC)\n"; \
		printf "  $(DIM)path:$(NC)      $(CURDIR)\n\n"; \
		if [ "$$STAGED" -eq 0 ] && [ "$$UNSTAGED" -eq 0 ] && [ "$$UNTRACKED" -eq 0 ]; then \
			printf "  $(GREEN)✓ nothing to commit — working tree clean$(NC)\n\n"; \
		else \
			printf "  $(YELLOW)staged:$(NC) $$STAGED  $(YELLOW)modified:$(NC) $$UNSTAGED  $(DIM)untracked:$(NC) $$UNTRACKED\n\n"; \
		fi; \
		printf "  $(DIM)recent commits:$(NC)\n"; \
		git --no-pager log --max-count=5 --pretty=format:"  %C(green)%h%C(reset)  %<(50,trunc)%s  %C(dim)%<(15)%ar%C(reset)" 2>/dev/null || true; \
		printf "\n"; \
	else \
		printf "$(RED)  ✗ not a git repository$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run full check:       $(BLUE)make check$(NC)\n"
	@printf "  • inspect dotfile diff: $(BLUE)make diff$(NC)\n\n"
endif
