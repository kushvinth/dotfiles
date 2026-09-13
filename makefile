# dotfiles Makefile (macOS)
#
# Thin wrapper around the `dotfiles` CLI built by nix/packages/dotfiles-cli,
# which is the single source of truth for this logic. The same CLI also runs
# automatically on every `darwin-rebuild switch` via
# nix/modules/darwin/dotfiles-stow.nix (see `dotfiles.stow.enable`).

FLAKE_DIR := ./nix
NIX_DOTFILES := nix run $(FLAKE_DIR)\#dotfiles --

VERBOSITY ?= 1
RUN := DOTFILES_REPO_ROOT=$(CURDIR) VERBOSITY=$(VERBOSITY) $(NIX_DOTFILES)

.PHONY: help install stow unstow restow etc setup get-etc \
	update update-submodules update-nvim update-completions

.DEFAULT_GOAL := help

help:
	@$(RUN) help

install:
	@$(RUN) install
	@echo ""
	@echo "Optional: make setup"

stow:
	@$(RUN) stow

unstow:
	@$(RUN) unstow

restow:
	@$(RUN) restow

etc:
	@$(RUN) etc

get-etc:
	@$(RUN) get-etc

setup:
	@$(RUN) setup

update:
	@$(RUN) update

update-submodules:
	@$(RUN) update-submodules

update-nvim:
	@$(RUN) update-nvim

update-completions:
	@$(RUN) update-completions
