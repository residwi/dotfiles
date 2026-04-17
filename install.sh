#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/state/dotfiles"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${STATE_DIR}/install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

init_logging() {
  mkdir -p "$STATE_DIR"
  echo "" >>"$LOG_FILE"
  echo "=== Install started at $(date) ===" >>"$LOG_FILE"
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
  echo "[INFO] $(date +%H:%M:%S) $1" >>"$LOG_FILE"
}
log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
  echo "[OK] $(date +%H:%M:%S) $1" >>"$LOG_FILE"
}
log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  echo "[WARN] $(date +%H:%M:%S) $1" >>"$LOG_FILE"
}
log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  echo "[ERROR] $(date +%H:%M:%S) $1" >>"$LOG_FILE"
}

prompt_confirm() {
  local message="${1:-Continue?}" default="${2:-y}"
  local prompt
  if [[ "$default" == "y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi
  read -rp "$message $prompt " response
  response="${response:-$default}"
  [[ "$response" =~ ^[Yy]$ ]]
}

backup_and_symlink() {
  local source="$1" target="${2/#\~/$HOME}"
  mkdir -p "$(dirname "$target")"

  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup_path="${BACKUP_DIR}${target#"$HOME"}"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target" "$backup_path"
    log_info "Backed up: $target -> $backup_path"
  elif [[ -L "$target" ]]; then
    rm "$target"
  fi

  ln -sf "$source" "$target"
  log_success "Linked: $source -> $target"
}

detect_os() {
  case "$(uname -s)" in
  Darwin) echo "macos" ;;
  Linux)
    if [[ -f /etc/os-release ]]; then
      # shellcheck source=/dev/null
      . /etc/os-release
      echo "$ID"
    else
      echo "unknown"
    fi
    ;;
  *) echo "unknown" ;;
  esac
}

preflight() {
  echo ""
  log_info "Running preflight checks..."
  OS=$(detect_os)
  log_info "Detected OS: $OS"

  [[ "$OS" == "unknown" ]] && {
    log_error "Unsupported OS. This script only supports macOS and Fedora Linux."
    exit 1
  }

  if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &>/dev/null; then
      log_warn "Homebrew not found"
      if prompt_confirm "Install Homebrew?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed"
      else
        log_error "Homebrew is required for macOS"
        exit 1
      fi
    fi
  elif [[ "$OS" == "fedora" ]]; then
    if ! command -v dnf &>/dev/null; then
      log_error "dnf not found. Is this Fedora?"
      exit 1
    fi
    log_info "Some operations require sudo privileges"
    sudo -v
  else
    log_error "Unsupported OS '$OS'. This script only supports macOS and Fedora Linux."
    exit 1
  fi
  log_success "Preflight checks passed"
}

setup_fedora_repos() {
  [[ "$OS" != "fedora" ]] && return

  echo ""
  log_info "Setting up Fedora repositories..."

  sudo dnf install -y dnf-plugins-core

  sudo dnf copr enable -y jdxcode/mise
  sudo dnf copr enable -y scottames/ghostty

  sudo dnf config-manager addrepo --overwrite --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

  log_success "Fedora repositories configured"
}

install_packages() {
  echo ""
  log_info "Installing packages..."
  if [[ "$OS" == "macos" ]]; then
    if [[ -f "$DOTFILES_DIR/packages/Brewfile" ]]; then
      brew bundle -v --file="$DOTFILES_DIR/packages/Brewfile" && log_success "Homebrew packages installed"
    else
      log_warn "No packages/Brewfile found, skipping"
    fi
  elif [[ "$OS" == "fedora" ]]; then
    local list_file="$DOTFILES_DIR/packages/dnf-list.txt"
    if [[ -f "$list_file" ]]; then
      local packages
      packages=$(grep -v '^#' "$list_file" | grep -v '^$' | tr '\n' ' ')
      # shellcheck disable=SC2086
      [[ -n "$packages" ]] && sudo dnf install -y $packages && log_success "Packages installed"
    else
      log_warn "No packages/dnf-list.txt found, skipping"
    fi
  fi
}

setup_symlinks() {
  echo ""
  log_info "Setting up symlinks..."
  mkdir -p "$BACKUP_DIR"

  if [[ -d "$DOTFILES_DIR/config" ]]; then
    for item in "$DOTFILES_DIR/config"/*; do
      [[ -e "$item" ]] || continue

      local name
      name=$(basename "$item")
      [[ "$name" == "README.md" ]] && continue
      if [[ -d "$item" ]]; then
        backup_and_symlink "$item" "$HOME/.config/$name"
      else
        backup_and_symlink "$item" "$HOME/.$name"
      fi
    done
  fi

  log_success "Symlinks configured"
}

setup_zsh_plugins() {
  local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
  local plugins=(
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
  )

  mkdir -p "$plugins_dir"

  for entry in "${plugins[@]}"; do
    local name="${entry%%|*}"
    local url="${entry##*|}"
    local target="$plugins_dir/$name"

    if [[ -d "$target/.git" ]]; then
      log_info "Updating $name..."
      git -C "$target" pull --quiet && log_success "Updated: $name"
    else
      log_info "Installing $name..."
      git clone --depth 1 "$url" "$target" && log_success "Installed: $name"
    fi
  done
}

setup_shell() {
  echo ""
  log_info "Setting up shell..."
  if [[ ! -d "$HOME/.oh-my-zsh" ]] && prompt_confirm "Install Oh My Zsh?"; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "Oh My Zsh installed"
  fi

  [[ -d "$HOME/.oh-my-zsh" ]] && setup_zsh_plugins

  # Symlink zsh files after Oh My Zsh installation (it creates its own .zshrc)
  local zsh_dir="$DOTFILES_DIR/zsh"
  [[ -f "$zsh_dir/zshrc" ]] && backup_and_symlink "$zsh_dir/zshrc" "$HOME/.zshrc"
  [[ -f "$zsh_dir/zprofile" ]] && backup_and_symlink "$zsh_dir/zprofile" "$HOME/.zprofile"

  if [[ "$SHELL" != *"zsh"* ]] && prompt_confirm "Set zsh as default shell?"; then
    local zsh_path
    zsh_path=$(command -v zsh)
    [[ -n "$zsh_path" ]] && chsh -s "$zsh_path" && log_success "Default shell set to zsh"
  fi
  log_success "Shell setup complete"
}

setup_nvim_plugins() {
  command -v nvim &>/dev/null || return
  echo ""

  if [[ -d "$HOME/.config/nvim" ]]; then
    log_info "Installing Neovim plugins..."
    nvim --headless "+Lazy! sync" +qa
    log_success "Neovim plugins installed"
  fi
}

install_mise() {
  echo ""
  log_info "Installing mise..."
  if command -v mise &>/dev/null; then
    log_success "mise already installed"
    return
  fi

  if [[ "$OS" == "macos" ]]; then
    brew install mise && log_success "mise installed"
  elif [[ "$OS" == "fedora" ]]; then
    log_warn "mise not found; it should have been installed via dnf. Re-running install..."
    sudo dnf install -y mise && log_success "mise installed"
  fi
}

install_dev_tools() {
  command -v mise &>/dev/null || return

  echo ""
  log_info "Installing dev tools via mise..."

  mise trust "$DOTFILES_DIR/config/mise/config.toml"
  mise install && log_success "Dev tools installed"
}

setup_docker() {
  [[ "$OS" != "fedora" ]] && return
  command -v docker &>/dev/null || return

  echo ""
  log_info "Configuring Docker..."

  sudo systemctl enable --now docker

  if ! getent group docker &>/dev/null; then
    sudo groupadd docker
  fi
  sudo usermod -aG docker "$USER"

  if [[ -d "$HOME/.docker" ]]; then
    sudo chown "$USER":"$USER" "$HOME/.docker" -R
    sudo chmod g+rwx "$HOME/.docker" -R
  fi

  log_info "Installing lazydocker..."
  curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

  log_success "Docker configured (re-login or run 'newgrp docker' to use without sudo)"
}

print_summary() {
  echo -e "\n========================================\n${GREEN}Installation Complete!${NC}\n========================================"
  echo "OS: $OS | Log: $LOG_FILE"
  [[ -d "$BACKUP_DIR" && "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]] && echo "Backups: $BACKUP_DIR"
  echo -e "\nNext steps:\n  1. Restart terminal or: source ~/.zshrc"
  [[ "$OS" == "fedora" ]] && echo "  2. Re-login or run 'newgrp docker' to use Docker without sudo"
  echo "=== Install completed at $(date) ===" >>"$LOG_FILE"
}

main() {
  echo -e "\n========================================\n       Dotfiles Installation\n========================================\n"
  init_logging

  prompt_confirm "This will install dotfiles and may overwrite existing configs. Continue?" || {
    log_info "Cancelled"
    exit 0
  }

  # Initialize submodules (e.g., nvim config)
  if [[ -f "$DOTFILES_DIR/.gitmodules" ]]; then
    log_info "Initializing git submodules..."
    git -C "$DOTFILES_DIR" submodule update --init --recursive
    log_success "Git submodules initialized"
  fi

  preflight
  setup_fedora_repos
  install_packages
  setup_symlinks
  install_mise
  install_dev_tools
  setup_docker
  setup_shell
  setup_nvim_plugins
  print_summary
}

main "$@"
