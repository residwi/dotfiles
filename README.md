# Dotfiles

My personal dotfiles for **macOS** and **Arch Linux** (with [Omarchy](https://github.com/basecamp/omarchy)).

## Requirements

- **macOS**: Homebrew (installer will offer to install it)
- **Arch**: [Omarchy](https://github.com/basecamp/omarchy) installed first

## Quick start

```bash
git clone --recurse-submodules https://github.com/residwi/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer is interactive and will prompt before making changes.

## Structure

```
dotfiles/
├── install.sh
├── packages/
│   ├── Brewfile          # macOS (Homebrew)
│   └── arch/
│       ├── add           # packages to install on top of omarchy
│       └── remove        # omarchy defaults to remove
├── config/
│   └── common/           # shared configs (both OS)
│       ├── ghostty/
│       ├── mise/
│       ├── nvim/         # git submodule -> residwi/nvim-configs
│       ├── tmux.conf
│       ├── gitconfig, gitignore, aliases, editorconfig, ...
├── bin/                  # utility scripts
├── zsh/                  # zshrc, zprofile, path/env helpers
└── tools/
    └── compose.yaml      # local dev services (postgres, redis, etc.)
```

## How it works

### macOS

Installs packages from `packages/Brewfile`, symlinks configs, sets up zsh with oh-my-zsh.

### Arch Linux

Designed to run on top of [Omarchy](https://github.com/basecamp/omarchy), which provides the base Hyprland setup. This repo just customizes it:

- Installs extra packages (firefox, bitwarden)
- Removes unwanted omarchy defaults (chromium, 1password, starship, etc.)
- Removes unwanted omarchy webapps (Discord, Figma, etc.)
- Symlinks shared configs

### Symlinks

| Source                 | Target            |
| ---------------------- | ----------------- |
| `config/common/<dir>`  | `~/.config/<dir>` |
| `config/common/<file>` | `~/.<file>`       |
| `zsh/zshrc`            | `~/.zshrc`        |
| `zsh/zprofile`         | `~/.zprofile`     |

## Neovim

The nvim config is a git submodule pointing to [residwi/nvim-configs](https://github.com/residwi/nvim-configs). If you didn't clone with `--recurse-submodules`:

```bash
git submodule update --init --recursive
```
