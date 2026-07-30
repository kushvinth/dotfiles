# ~/dotfiles

Declarative macOS setup — Nix, Stow, Homebrew, and a mountain of `defaults`.

---

## One-liner

```bash
git clone https://github.com/you/dotfiles.git ~/dotfiles && cd ~/dotfiles && make install
```

---

## What's Managed

| Layer | Tool | What it controls |
|---|---|---|
| System | **nix-darwin** | packages, launchd services, /etc files, fonts, nix config |
| Homebrew | **Brewfile** | CLI tools, GUI casks, fonts, Mac App Store apps |
| Dotfiles | **GNU Stow** | ~/.config/* for every app (zsh, nvim, tmux, yabai, ghostty, karabiner, sketchybar, etc.) |
| macOS | **defaults** | Dock, Finder, Trackpad, Hot Corners, Keyboard, Screenshots, Spotlight, Window Manager, Control Center, Accessibility |
| Tiling WM | **yabai / skhd / AeroSpace** | BSP window management, hotkeys |
| Menubar | **sketchybar** | Custom menubar (spaces, battery, wifi, volume, calendar, media, brew) |

---

## Structure

```
dotfiles/
├── nix/                          # nix-darwin flake
│   ├── flake.nix                 # Entry point
│   ├── hosts/MacbookPro.nix      # Host config
│   └── modules/darwin/
│       ├── system.nix            # Packages, fonts, nix config
│       ├── services.nix          # launchd: yabai, skhd, sketchybar
│       ├── homebrew.nix          # Brew/casks/masApps
│       ├── defaults.nix          # ALL macOS defaults (declarative)
│       ├── activation.nix        # Scripts run on rebuild
│       └── etc.nix               # /etc/zprofile, /etc/zshenv
├── dot-config/                   # Stow-managed ~/.config/*
│   ├── zsh/
│   ├── nvim/
│   ├── tmux/
│   ├── yabai/
│   ├── skhd/
│   ├── sketchybar/
│   ├── ghostty/
│   ├── karabiner/
│   ├── linearmouse/
│   ├── aerospace/
│   ├── borders/
│   ├── starship/
│   ├── bat/
│   ├── btop/
│   └── ... (~28 app configs)
├── Brewfile                      # Everything Homebrew
├── makefile                      # make install / make stow / make etc
└── archives/                     # Reference docs
```

---

## macOS Defaults — Quick Reference

### System

| Setting | Value | How |
|---|---|---|
| Dark Mode | On | `system.defaults.NSGlobalDomain` |
| Accent color | Blue | `AppleAquaColorVariant = 1` |
| Key repeat | Fast (15, 6) | `InitialKeyRepeat = 15; KeyRepeat = 6` |
| Menu bar | Auto-hide | `_HIHideMenuBar = true` |
| Mouse speed | 3.0 | `com.apple.mouse.scaling` |
| Trackpad speed | 2.5 | `com.apple.trackpad.scaling` |
| Scroll speed | 0.5 | `com.apple.scrollwheel.scaling` |
| Force Click | Off | `com.apple.trackpad.forceClick = false` |
| Natural scrolling | On | `com.apple.swipescrolldirection = true` |
| Font antialiasing | Threshold 4 | `AppleAntiAliasingThreshold = 4` |

### Dock

| Setting | Value |
|---|---|
| Position | Right |
| Auto-hide | On |
| Icon size | 104px (magnified to 46px) |
| Minimize | Into app icon, genie effect |
| Recents | Hidden |
| Spaces MRU | Off |
| Hot corners | TL: Mission Control, TR: Desktop, BL: Launchpad, BR: Screen Saver (all +⌘) |

### Finder

| Setting | Value |
|---|---|
| Path bar | Visible |
| Status bar | Hidden |
| Preview pane | Visible (`⇧⌘P`) |
| Extensions | Always show |
| New window | `~/LocalStorage/` |
| Trash | Auto-empty after 30 days |
| Icon view | Default style |

### Trackpad

| Setting | Value |
|---|---|
| Tap to click | On |
| Three-finger drag | On |
| Right click | Bottom-right corner |
| Force Click | Off |
| Gestures | 4-finger swipe for full-screen apps, 4-finger up for Mission Control, 4-finger pinch for Launchpad, 5-finger pinch for Desktop |

### Screenshots

| Setting | Value |
|---|---|
| Save location | `~/LocalStorage/Screenshot` |
| Show clicks | On |
| Format | PNG |

### Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Spotlight | `⌘Space` |
| Screenshot area | `⇧⌘4` |
| Screenshot full | `⇧⌘3` |
| Screenshot UI | `⇧⌘5` |
| Screenshot clipboard | `^⌃⇧⌘3` |
| Show Desktop | `F11` |
| Mission Control | `^⌃↑` |
| App Expose | `^⌃↓` |
| Desktop N | `^⌃N` |
| Move space L/R | `^⌃←` / `^⌃→` |

**Disabled:** VoiceOver, Zoom, Sticky Keys, Slow Keys, Siri shortcuts, Accessibility Keyboard.

### Window Manager

| Setting | Value |
|---|---|
| Stage Manager | Off |
| Desktop icons | Hidden |
| Widgets | Hidden |
| Native tiling | Off (replaced by yabai) |

### Spotlight

| Feature | Value |
|---|---|
| Clipboard history | On (no timeout) |

---

## App Configs (via Stow → `~/.config/`)

| App | Highlights |
|---|---|
| **yabai** | BSP layout, 6px gaps, floating rules for Finder/VLC/System Settings, sketchybar integration |
| **skhd** | `⌥`-based: hjkl focus, shift+move, resize, space switching 1-0 |
| **sketchybar** | Full custom bar: spaces, apple, battery, bluetooth, wifi, volume, calendar, cpu, brew, spotify, front app, tailscale, github |
| **karabiner** | Caps Lock → Hyper Key, Hyper+key app launchers |
| **ghostty** | Window decorations off, opacity 0.8, option-as-alt, hidden window buttons, xray icon |
| **linearmouse** | Per-device acceleration/speed for Rapoo, USB mouse, trackpad, Dell |
| **nvim** | Full Neovim config |
| **zed** | Editor settings |
| **starship** | Prompt |
| **borders** | Minimal right-side border (0.001px) |

---

## Nix Packages (selected)

**CLI:** neovim, tmux, bat, eza, ripgrep, fd, fzf, zoxide, lazygit, gh, yt-dlp, starship, uv, go, rust

**GUI:** obsidian, discord, zed-editor, vscode

**Fonts:** JetBrains Mono Nerd Font

---

## Homebrew (selected)

**Brews:** immich-go, sketchybar, skhd, yabai, mas

**Casks:** alt-tab, homerow, karabiner-elements, ghostty, linearmouse, raycast, rectangle, google-chrome, zen, cursor, lm-studio, orbstack, cleanshot, tailscale

**Mac App Store:** Battery Health 2, Slack, The Unarchiver, WhatsApp, iMovie

---

## Rebuilding

```bash
darwin-rebuild switch
# or
make nix-switch
```
