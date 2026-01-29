# Dotfiles

Personal dotfiles for macOS and Arch Linux with Hyprland.

## Quick Start

```bash
git clone https://github.com/residwi/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Structure

```
dotfiles/
├── install.sh              # Main installation script
├── packages/
│   ├── Brewfile            # macOS packages (Homebrew)
│   ├── arch.pacman         # Arch Linux packages (official repos)
│   └── arch.aur            # Arch Linux packages (AUR)
├── config/
│   ├── common/             # Shared configs (both OS)
│   │   ├── gitconfig
│   │   ├── gitignore
│   │   ├── tmux.conf
│   │   ├── aliases
│   │   └── zsh/            # Zsh configuration
│   ├── macos/              # macOS-specific
│   │   └── ghostty/
│   └── arch/               # Arch Linux-specific
│       ├── hypr/           # Hyprland configs
│       ├── waybar/
│       ├── mako/
│       ├── hypridle/
│       ├── hyprlock/
│       ├── hyprpaper/
│       ├── walker/
│       ├── btop/
│       ├── lazygit/
│       └── themes/         # Theme assets
│           └── catppuccin-mocha/
├── bin/
│   └── arch/               # Arch-specific commands
│       ├── screenshot
│       ├── screenrecord
│       ├── lock
│       └── theme
└── nvim/                   # Neovim config (git submodule)
```

## Features

### macOS

- Homebrew packages via Brewfile
- Ghostty terminal configuration

### Arch Linux

- Hyprland tiling window manager
- Minimal keybindings
- Theme system (catppuccin-mocha default)
- NVIDIA/Intel GPU auto-detection
- Services: sddm, docker, ufw, power-profiles-daemon

## Theme System

Themes are located in `config/arch/themes/`. The active theme is symlinked to `~/.config/theme/current/`.

Switch themes:

```bash
~/.local/bin/theme set catppuccin-mocha
hyprctl reload
```

## Key Bindings (Arch/Hyprland)

| Binding               | Action                |
| --------------------- | --------------------- |
| `Super + Return`      | Terminal (Ghostty)    |
| `Super + Space`       | App launcher (Walker) |
| `Super + W`           | Close window          |
| `Super + F`           | Fullscreen            |
| `Super + T`           | Toggle floating       |
| `Super + 1-0`         | Switch workspace      |
| `Super + Shift + 1-0` | Move to workspace     |
| `Super + L`           | Lock screen           |
| `Print`               | Screenshot            |

## Requirements

- **macOS**: Homebrew (installer handles it)
- **Arch**: limine bootloader, git, base-devel, yay

Limine is required for btrfs snapshot rollback with snapper. Install it during Arch installation.
