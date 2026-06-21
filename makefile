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

GEN_DIR := $(HOME_DIR)/.config/zsh/completions

# generate-completion(tool, [gen-command...])
# Tries: 1) gen-command, 2) nix store copy, 3) homebrew symlink
define gen-comp
  @TARGET=$(GEN_DIR)/_$(1); \
  rm -f $$TARGET 2>/dev/null; \
  if command -v $(1) >/dev/null 2>&1; then \
    if [ -n "$(2)" ]; then \
      $(2) > $$TARGET 2>/dev/null && SZ=$$(wc -c < $$TARGET) && echo "  $(1): generated ($$SZ bytes)"; \
    fi; \
  fi; \
  if [ ! -s $$TARGET ]; then \
    NIX_SRC=$$(find /nix/store -maxdepth 8 -path "*/share/zsh/site-functions/_$(1)" -type f 2>/dev/null | head -1); \
    if [ -n "$$NIX_SRC" ]; then \
      cp "$$NIX_SRC" $$TARGET; \
      SZ=$$(wc -c < $$TARGET) && echo "  $(1): nix store copy ($$SZ bytes)"; \
    fi; \
  fi; \
  if [ ! -s $$TARGET ] && [ -f /opt/homebrew/share/zsh/site-functions/_$(1) ]; then \
    ln -sf /opt/homebrew/share/zsh/site-functions/_$(1) $$TARGET; \
    echo "  $(1): homebrew symlink"; \
  elif [ ! -s $$TARGET ]; then \
    echo "  $(1): SKIPPED (not available)"; \
  fi
endef

# brew is special — it needs a manual generation since `brew` has no zsh completion command
define gen-brew
  @TARGET=$(GEN_DIR)/_brew; \
  rm -f $$TARGET 2>/dev/null; \
  if command -v brew >/dev/null 2>&1; then \
    { printf '#compdef brew\n_brew() {\n  local -a cmds\n  cmds=(\n'; \
      brew commands 2>/dev/null | awk '{print "    \""$$1"\""}'; \
      printf '  )\n  _describe brew cmds\n}\n_brew "$$@"\n'; } > $$TARGET; \
    echo "  brew: generated ($$(wc -c < $$TARGET) bytes)"; \
  fi; \
  if [ ! -s $$TARGET ]; then \
    echo "  brew: SKIPPED (not available)"; \
  fi
endef

update-completions:
	@echo "--- Updating zsh completions ---"
	@mkdir -p $(GEN_DIR)
	$(call gen-comp,bat,bat --completion zsh)
	$(call gen-comp,gh,gh completion -s zsh)
	$(call gen-comp,uv,uv generate-shell-completion zsh)
	@cp $(GEN_DIR)/_uv $(GEN_DIR)/_uvx 2>/dev/null && echo "  uvx: copy" || true
	$(call gen-comp,deno,deno completions zsh)
	$(call gen-comp,docker,docker completion zsh)
	$(call gen-comp,podman,podman completion zsh)
	$(call gen-comp,tailscale,tailscale completion zsh)
	$(call gen-comp,git-lfs,git-lfs completion zsh)
	$(call gen-comp,eza)
	$(call gen-comp,fd)
	$(call gen-comp,zoxide)
	$(call gen-comp,yt-dlp)
	$(call gen-comp,starship)
	$(call gen-brew)
	@rm -f $(HOME_DIR)/.zcompdump
	@echo "--- Done ---"
