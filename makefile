# dotfiles Makefile (macOS)

HOME_DIR := $(HOME)
CONFIGS_DIR := ./assets/configs

# Dirs to create before stow so merges into existing ~/.config / ~/.local work
STOW_CONFIG_NO_DIRS :=
STOW_NO_DIRS := dot-local/share

VERBOSITY ?= 1
V_FLAG := $(shell [ "$(VERBOSITY)" -gt 0 ] && echo "-v" || echo "")

.PHONY: help install stow unstow restow etc setup get-etc \
	update update-submodules update-nvim update-completions

.DEFAULT_GOAL := help	

help:
	@echo "--- Available targets ---"
	@echo "  help              Show this message"
	@echo "  install           stow + init submodules"
	@echo "  stow              Deploy dotfiles (stow --dotfiles .)"
	@echo "  unstow            Remove stow symlinks"
	@echo "  restow            unstow, then stow"
	@echo "  etc               Install assets/configs/etc → /etc (sudo)"
	@echo "  get-etc           Copy /etc files back into assets/configs/etc"
	@echo "  setup             Submodules, bat cache, nvim plugins"
	@echo "  update            update-submodules + update-nvim"
	@echo "  update-submodules Refresh git submodules"
	@echo "  update-nvim       Lazy.nvim sync (dot-config/nvim)"
	@echo "  update-completions  Update Homebrew and custom Zsh completions"
	@echo ""
	@echo "Verbosity: make VERBOSITY=2 stow  (stow --verbose=N)"

install: stow update-submodules
	@echo ""
	@echo "Next: brew bundle install --file ./Brewfile"
	@echo "Optional: make setup"
	@$(MAKE) update-completions

stow:
	@echo "--- Stowing dotfiles ---"
	@for dir in $(STOW_CONFIG_NO_DIRS); do \
		d=$$(echo $$dir | sed 's/^dot-/./'); \
		mkdir -p $(HOME_DIR)/.config/$$d; \
		touch $(HOME_DIR)/.config/$$d/.stow-keep; \
	done
	@for dir in $(STOW_NO_DIRS); do \
		d=$$(echo $$dir | sed 's/^dot-/./'); \
		mkdir -p $(HOME_DIR)/$$d; \
		touch $(HOME_DIR)/$$d/.stow-keep; \
	done
	stow --target=$(HOME_DIR) --dotfiles --verbose=$(VERBOSITY) .
	@for dir in $(STOW_CONFIG_NO_DIRS); do \
		d=$$(echo $$dir | sed 's/^dot-/./'); \
		rm -f $(HOME_DIR)/.config/$$d/.stow-keep; \
	done
	@for dir in $(STOW_NO_DIRS); do \
		d=$$(echo $$dir | sed 's/^dot-/./'); \
		rm -f $(HOME_DIR)/$$d/.stow-keep; \
	done
	@test -f $(HOME_DIR)/.zshenv || printf '%s\n' 'export ZDOTDIR=$$HOME/.config/zsh' > $(HOME_DIR)/.zshenv

unstow:
	@echo "--- Unstowing dotfiles ---"
	stow -D --target=$(HOME_DIR) --dotfiles --verbose=$(VERBOSITY) .

restow: unstow stow

etc:
	@echo "--- Installing etc configs (run: make etc — not sudo make) ---"
	@find $(CONFIGS_DIR)/etc -type f 2>/dev/null 2>/dev/null | while read -r file; do \
		dest=$$(echo "$$file" | sed 's|$(CONFIGS_DIR)||'); \
		mode=644; [ -x "$$file" ] && mode=755; \
		echo "$$file -> $$dest"; \
		sudo install $(V_FLAG) -m $$mode -o root -g wheel "$$file" "$$dest"; \
	done

get-etc:
	@echo "--- Copy system /etc files into $(CONFIGS_DIR)/etc ---"
	@find $(CONFIGS_DIR)/etc -type f 2>/dev/null | while read -r file; do \
		dest=$$(echo "$$file" | sed 's|$(CONFIGS_DIR)||'); \
		if [ -f "$$dest" ]; then \
			sudo cp $(V_FLAG) "$$dest" "$$file"; \
		else \
			echo "skip (missing): $$dest"; \
		fi; \
	done

setup:
	@echo "--- Setup ---"
	git submodule update --init --recursive
	@command -v bat >/dev/null && bat cache --build || echo "skip: bat not installed"
	@command -v nvim > /dev/null && nvim --headless '+Lazy! restore' +qa || echo "skip: nvim not installed"
	@$(MAKE) update-completions

update: update-submodules update-nvim

update-submodules:
	@echo "--- Updating git submodules ---"
	git submodule update --init --recursive
	git submodule foreach --recursive 'git pull --ff-only 2>/dev/null || true'

update-nvim:
	@echo "--- Updating neovim plugins ---"
	@command -v nvim >/dev/null || { echo "skip: nvim not installed"; exit 0; }
	nvim --headless '+Lazy! sync' +qa
	@git diff --quiet dot-config/nvim/lazy-lock.json 2>/dev/null || \
		git commit dot-config/nvim/lazy-lock.json -m "nvim: update lazy-lock" || true

update-completions:
	@echo "--- Updating zsh completions ---"
	@mkdir -p $(HOME_DIR)/.config/zsh/completions
	@command -v bat >/dev/null && bat --completion zsh > $(HOME_DIR)/.config/zsh/completions/_bat 2>/dev/null && echo "  bat: OK" || true
	@command -v gh >/dev/null && gh completion -s zsh > $(HOME_DIR)/.config/zsh/completions/_gh 2>/dev/null && echo "  gh: OK" || true
	@command -v uv >/dev/null && uv generate-shell-completion zsh > $(HOME_DIR)/.config/zsh/completions/_uv 2>/dev/null && echo "  uv: OK" || true
	@cp $(HOME_DIR)/.config/zsh/completions/_uv $(HOME_DIR)/.config/zsh/completions/_uvx 2>/dev/null && echo "  uvx: OK (copied from uv)" || true
	@command -v deno >/dev/null && deno completions zsh > $(HOME_DIR)/.config/zsh/completions/_deno 2>/dev/null && echo "  deno: OK" || true
	@command -v docker >/dev/null && docker completion zsh > $(HOME_DIR)/.config/zsh/completions/_docker 2>/dev/null && echo "  docker: OK" || true
	@command -v podman >/dev/null && podman completion zsh > $(HOME_DIR)/.config/zsh/completions/_podman 2>/dev/null && echo "  podman: OK" || true
	@command -v tailscale >/dev/null && tailscale completion zsh > $(HOME_DIR)/.config/zsh/completions/_tailscale 2>/dev/null && echo "  tailscale: OK" || true
	@command -v git-lfs >/dev/null && git-lfs completion zsh > $(HOME_DIR)/.config/zsh/completions/_git-lfs 2>/dev/null && echo "  git-lfs: OK" || true
	@command -v yt-dlp >/dev/null && yt-dlp --dump-completion zsh > $(HOME_DIR)/.config/zsh/completions/_yt-dlp 2>/dev/null && echo "  yt-dlp: OK" || true
	@rm -f $(HOME_DIR)/.zcompdump
