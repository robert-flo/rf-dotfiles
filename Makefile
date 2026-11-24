# ════════════════════════════════════════════════════════════════════════════════
# 🏠 RF-DOTFILES - Chezmoi SSoT & Workstation Profile Command Center
# ════════════════════════════════════════════════════════════════════════════════
# 🎯 Purpose: Manage dotfiles, profiles (clavis, nyxuri, omarchy), packages, and checks
# 📎 Details: Modular targets live in ./make/

.DEFAULT_GOAL := help
SHELL := /bin/bash

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
PURPLE := \033[0;35m
CYAN   := \033[0;36m
DIM    := \033[2m
BOLD   := \033[1m
NC     := \033[0m

include make/help.mk
include make/chezmoi.mk
