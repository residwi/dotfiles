# Dotfiles

My personal dotfiles for **macOS** and **Fedora Linux**.

## Requirements

- **macOS**: Homebrew (installer will offer to install it)
- **Fedora**: Fedora Desktop Workstation (installer handles all repo setup)

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
│   └── dnf-list.txt      # Fedora (dnf)
├── config/               # shared configs (all platforms)
│   ├── ghostty/
│   ├── mise/
│   ├── nvim/             # git submodule -> residwi/nvim-configs
│   ├── tmux.conf
│   ├── gitconfig, gitignore, aliases, editorconfig, ...
├── bin/                  # utility scripts
├── zsh/                  # zshrc, zprofile, path/env helpers
└── tools/
    └── compose.yaml      # local dev services (postgres, redis, etc.)
```

## How it works

### macOS

Installs packages from `packages/Brewfile`, symlinks configs, sets up zsh with oh-my-zsh.

### Fedora Linux

Enables external repositories (Docker CE repo, ghostty COPR, mise COPR), then installs packages from `packages/dnf-list.txt` via dnf.

After install, enable the Docker service:

```bash
sudo systemctl enable --now docker
```

### Symlinks

| Source              | Target            |
| ------------------- | ----------------- |
| `config/<dir>`      | `~/.config/<dir>` |
| `config/<file>`     | `~/.<file>`       |
| `zsh/zshrc`         | `~/.zshrc`        |
| `zsh/zprofile`      | `~/.zprofile`     |

## Neovim

The nvim config is a git submodule pointing to [residwi/nvim-configs](https://github.com/residwi/nvim-configs). If you didn't clone with `--recurse-submodules`:

```bash
git submodule update --init --recursive
```
