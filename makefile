# Makefile for dotfiles

STOW := stow
STOW_FLAGS := --verbose

.PHONY: all install uninstall restow

all: install

install:
# dot-config -> ~/.config
	$(STOW) $(STOW_FLAGS) --target=$$HOME/.config dot-config

# dot-claude -> ~/.claude
	$(STOW) $(STOW_FLAGS) --target=$$HOME dot-claude

uninstall:
	$(STOW) -D $(STOW_FLAGS) --target=$$HOME/.config dot-config
	$(STOW) -D $(STOW_FLAGS) --target=$$HOME dot-claude

restow: uninstall install