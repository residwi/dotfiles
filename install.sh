#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/state/dotfiles"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${STATE_DIR}/install.log"
THEME_NAME="${THEME_NAME:-catppuccin-mocha}"

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
  Linux) [[ -f /etc/arch-release ]] && echo "arch" || echo "linux" ;;
  *) echo "unknown" ;;
  esac
}

# reference: https://github.com/basecamp/omarchy/blob/bb91f90839efb9b5fcbf9893484046741c3747c8/install/config/hardware/nvidia.sh
detect_nvidia() {
  local nvidia
  nvidia="$(lspci | grep -i 'nvidia' || true)"
  [[ -z "$nvidia" ]] && return 1
  log_info "NVIDIA GPU detected: $nvidia"

  local kernel_headers
  kernel_headers="$(pacman -Qqs '^linux(-zen|-lts|-hardened)?$' | head -1)-headers"
  local packages=()

  if echo "$nvidia" | grep -qE "RTX [2-9][0-9]|GTX 16"; then
    packages=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver)
  elif echo "$nvidia" | grep -qE "GTX 9|GTX 10|Quadro P|MX1|MX2|MX3"; then
    packages=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
  else
    log_warn "No compatible NVIDIA driver. See: https://wiki.archlinux.org/title/NVIDIA"
    return 1
  fi

  if command -v yay &>/dev/null; then
    yay -S --needed --noconfirm "$kernel_headers" "${packages[@]}"
  else
    sudo pacman -S --needed --noconfirm "$kernel_headers" "${packages[@]}"
  fi

  echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
  echo "MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)" | sudo tee /etc/mkinitcpio.conf.d/nvidia.conf >/dev/null
  log_success "Configured NVIDIA modprobe and mkinitcpio"

  local hypr_envs="$HOME/.config/hypr/envs.conf"
  if [[ -f "$hypr_envs" ]] && ! grep -q "NVIDIA" "$hypr_envs"; then
    printf '\n# NVIDIA\nenv = NVD_BACKEND,direct\nenv = LIBVA_DRIVER_NAME,nvidia\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\n' >>"$hypr_envs"
    log_success "Added NVIDIA env vars to hypr/envs.conf"
  fi
}

detect_intel() {
  local intel_gpu
  intel_gpu="$(lspci | grep -iE 'vga|3d|display' | grep -i 'intel' || true)"
  [[ -z "$intel_gpu" ]] && return 1
  log_info "Intel GPU detected: $intel_gpu"

  local intel_lower="${intel_gpu,,}"
  if [[ "$intel_lower" =~ "hd graphics"|"xe"|"iris" ]]; then
    sudo pacman -S --needed --noconfirm intel-media-driver && log_success "Installed intel-media-driver"
  elif [[ "$intel_lower" =~ "gma" ]]; then
    sudo pacman -S --needed --noconfirm libva-intel-driver && log_success "Installed libva-intel-driver"
  fi
}

preflight() {
  log_info "Running preflight checks..."
  OS=$(detect_os)
  log_info "Detected OS: $OS"

  [[ "$OS" == "unknown" || "$OS" == "linux" ]] && {
    log_error "Unsupported OS"
    exit 1
  }

  if [[ "$OS" == "macos" ]] && ! command -v brew &>/dev/null; then
    log_warn "Homebrew not found"
    if prompt_confirm "Install Homebrew?"; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      log_success "Homebrew installed"
    else
      log_error "Homebrew is required for macOS"
      exit 1
    fi
  elif [[ "$OS" == "arch" ]]; then
    if ! command -v yay &>/dev/null && prompt_confirm "Install yay (AUR helper)?"; then
      sudo pacman -S --needed --noconfirm git base-devel
      local tmp_dir
      tmp_dir=$(mktemp -d)
      git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
      (cd "$tmp_dir/yay" && makepkg -si --noconfirm) && rm -rf "$tmp_dir"
      log_success "yay installed"
    fi
    log_info "Some operations require sudo privileges"
    sudo -v
  fi
  log_success "Preflight checks passed"
}

install_packages() {
  log_info "Installing packages..."
  if [[ "$OS" == "macos" ]]; then
    if [[ -f "$DOTFILES_DIR/packages/Brewfile" ]]; then
      brew bundle --file="$DOTFILES_DIR/packages/Brewfile" && log_success "Homebrew packages installed"
    else
      log_warn "No packages/Brewfile found, skipping"
    fi
  elif [[ "$OS" == "arch" ]]; then
    local pacman_file="$DOTFILES_DIR/packages/arch.pacman"
    local aur_file="$DOTFILES_DIR/packages/arch.aur"

    if [[ -f "$pacman_file" ]]; then
      local packages
      packages=$(grep -v '^#' "$pacman_file" | grep -v '^$' | tr '\n' ' ')
      # shellcheck disable=SC2086
      [[ -n "$packages" ]] && sudo pacman -S --needed --noconfirm $packages && log_success "Pacman packages installed"
    fi

    if [[ -f "$aur_file" ]] && command -v yay &>/dev/null; then
      local aur_packages
      aur_packages=$(grep -v '^#' "$aur_file" | grep -v '^$' | tr '\n' ' ')

      # shellcheck disable=SC2086
      [[ -n "$aur_packages" ]] && yay -S --needed --noconfirm $aur_packages && log_success "AUR packages installed"
    fi
  fi
}

setup_symlinks() {
  log_info "Setting up symlinks..."
  mkdir -p "$BACKUP_DIR"

  # config/common/ symlinks (files -> ~/.file, dirs -> ~/.config/dir)
  if [[ -d "$DOTFILES_DIR/config/common" ]]; then
    for item in "$DOTFILES_DIR/config/common"/*; do
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

  # zsh files need special handling (zshrc -> ~/.zshrc, zprofile -> ~/.zprofile)
  local zsh_dir="$DOTFILES_DIR/config/common/zsh"
  [[ -f "$zsh_dir/zshrc" ]] && backup_and_symlink "$zsh_dir/zshrc" "$HOME/.zshrc"
  [[ -f "$zsh_dir/zprofile" ]] && backup_and_symlink "$zsh_dir/zprofile" "$HOME/.zprofile"

  # nvim config
  [[ -d "$DOTFILES_DIR/nvim" ]] && backup_and_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

  # OS-specific config symlinks
  if [[ -d "$DOTFILES_DIR/config/$OS" ]]; then
    for item in "$DOTFILES_DIR/config/$OS"/*; do
      [[ -e "$item" ]] || continue
      local name
      name=$(basename "$item")
      [[ "$name" == "themes" ]] && continue
      backup_and_symlink "$item" "$HOME/.config/$name"
    done
  fi
  log_success "Symlinks configured"
}

setup_arch_extras() {
  [[ "$OS" != "arch" ]] && return
  log_info "Setting up Arch-specific configuration..."

  prompt_confirm "Run hardware detection (NVIDIA/Intel)?" && {
    detect_nvidia || true
    detect_intel || true
  }

  if prompt_confirm "Enable services (sddm, docker, ufw, power-profiles-daemon)?"; then
    for svc in sddm docker ufw power-profiles-daemon; do
      if systemctl list-unit-files | grep -q "^$svc"; then
        sudo systemctl enable --now "$svc" 2>/dev/null && log_success "Enabled: $svc"
      else
        log_warn "Service not found: $svc"
      fi
    done
  fi

  if [[ -d "$DOTFILES_DIR/bin/arch" ]]; then
    mkdir -p "$HOME/.local/bin"
    for script in "$DOTFILES_DIR/bin/arch"/*; do
      [[ -f "$script" ]] || continue
      backup_and_symlink "$script" "$HOME/.local/bin/$(basename "$script")"
      chmod +x "$script"
    done
  fi
  log_success "Arch extras configured"
}

setup_shell() {
  log_info "Setting up shell..."
  if [[ ! -d "$HOME/.oh-my-zsh" ]] && prompt_confirm "Install Oh My Zsh?"; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "Oh My Zsh installed"
  fi

  if [[ "$SHELL" != *"zsh"* ]] && prompt_confirm "Set zsh as default shell?"; then
    local zsh_path
    zsh_path=$(command -v zsh)
    [[ -n "$zsh_path" ]] && chsh -s "$zsh_path" && log_success "Default shell set to zsh"
  fi
  log_success "Shell setup complete"
}

setup_theme() {
  # Skip theme setup on macOS (no Hyprland theming)
  [[ "$OS" == "macos" ]] && return

  log_info "Setting up theme..."
  mkdir -p "$HOME/.config/theme"

  local theme_dir="$DOTFILES_DIR/config/$OS/themes"
  local theme_source="$theme_dir/$THEME_NAME"

  # Symlink entire themes directory (needed for CSS @import paths)
  if [[ -d "$theme_dir" ]]; then
    backup_and_symlink "$theme_dir" "$HOME/.config/themes"
    log_success "Themes directory symlinked"
  fi

  # Symlink current theme for easy access
  if [[ -d "$theme_source" ]]; then
    backup_and_symlink "$theme_source" "$HOME/.config/theme/current"
    log_success "Theme set to: $THEME_NAME"
  else
    log_warn "Theme not found: $theme_source"
  fi
}

print_summary() {
  echo -e "\n========================================\n${GREEN}Installation Complete!${NC}\n========================================"
  echo "OS: $OS | Log: $LOG_FILE"
  [[ -d "$BACKUP_DIR" && "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]] && echo "Backups: $BACKUP_DIR"
  echo -e "\nNext steps:\n  1. Restart terminal or: source ~/.zshrc"
  [[ "$OS" == "arch" ]] && echo "  2. Reboot to apply hardware changes"
  echo "=== Install completed at $(date) ===" >>"$LOG_FILE"
}

main() {
  echo -e "\n========================================\n       Dotfiles Installation\n========================================\n"
  init_logging

  prompt_confirm "This will install dotfiles and may overwrite existing configs. Continue?" || {
    log_info "Cancelled"
    exit 0
  }

  preflight
  install_packages
  setup_symlinks
  setup_arch_extras
  setup_shell
  setup_theme
  print_summary
}

main "$@"
