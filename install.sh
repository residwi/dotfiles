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

setup_docker() {
  [[ "$OS" != "arch" ]] && return
  log_info "Configuring Docker daemon..."

  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF

  sudo mkdir -p /etc/systemd/resolved.conf.d
  echo -e '[Resolve]\nDNSStubListenerExtra=172.17.0.1' | sudo tee /etc/systemd/resolved.conf.d/20-docker-dns.conf >/dev/null
  sudo systemctl restart systemd-resolved

  sudo usermod -aG docker "${USER}"

  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null <<'EOF'
[Unit]
DefaultDependencies=no
EOF

  sudo systemctl daemon-reload
  log_success "Docker configured"
}

setup_fast_shutdown() {
  [[ "$OS" != "arch" ]] && return

  if [[ ! -f /etc/systemd/system.conf.d/10-faster-shutdown.conf ]]; then
    log_info "Configuring faster shutdown..."
    sudo mkdir -p /etc/systemd/system.conf.d
    sudo tee /etc/systemd/system.conf.d/10-faster-shutdown.conf >/dev/null <<'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF
    sudo systemctl daemon-reload
    log_success "Fast shutdown configured (5s timeout)"
  fi
}

setup_pacman() {
  [[ "$OS" != "arch" ]] && return

  if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    log_info "Configuring pacman..."
    sudo sed -i '/^\[options\]/a Color\nILoveCandy\nVerbosePkgLists\nParallelDownloads = 5' /etc/pacman.conf
    log_success "Pacman configured (Color, ILoveCandy, ParallelDownloads)"
  fi
}

setup_user_groups() {
  [[ "$OS" != "arch" ]] && return
  log_info "Adding user to required groups..."
  sudo usermod -aG input "${USER}"
  log_success "Added user to input group"
}

setup_sddm() {
  [[ "$OS" != "arch" ]] && return

  sudo mkdir -p /etc/sddm.conf.d
  if [[ ! -f /etc/sddm.conf.d/autologin.conf ]]; then
    cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=hyprland-uwsm

[Theme]
Current=breeze
EOF
    log_success "SDDM configured with hyprland-uwsm session"
  fi
}

setup_mimetypes() {
  [[ "$OS" != "arch" ]] && return
  log_info "Setting default applications..."

  update-desktop-database ~/.local/share/applications 2>/dev/null || true

  for mime in image/png image/jpeg image/gif image/webp image/bmp image/tiff; do
    xdg-mime default imv.desktop "$mime"
  done

  xdg-mime default org.gnome.Evince.desktop application/pdf

  xdg-settings set default-web-browser firefox.desktop
  xdg-mime default firefox.desktop x-scheme-handler/http
  xdg-mime default firefox.desktop x-scheme-handler/https

  for mime in video/mp4 video/x-msvideo video/x-matroska video/x-flv video/webm video/quicktime video/mpeg; do
    xdg-mime default mpv.desktop "$mime"
  done

  log_success "Default applications configured"
}

# reference: https://github.com/basecamp/omarchy/blob/dev/install/login/limine-snapper.sh
setup_snapper() {
  [[ "$OS" != "arch" ]] && return

  if ! command -v limine &>/dev/null; then
    log_warn "Limine not found, skipping snapper setup"
    return
  fi

  log_info "Setting up Snapper with Limine..."

  if command -v yay &>/dev/null; then
    yay -S --needed --noconfirm limine-snapper-sync limine-mkinitcpio-hook
  else
    log_warn "yay not found, skipping limine-snapper-sync installation"
    return
  fi

  # Find limine.conf location
  local limine_config=""
  local search_paths=(
    "/boot/EFI/arch-limine/limine.conf"
    "/boot/EFI/BOOT/limine.conf"
    "/boot/EFI/limine/limine.conf"
    "/boot/limine/limine.conf"
    "/boot/limine.conf"
  )

  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      limine_config="$path"
      break
    fi
  done

  if [[ -z "$limine_config" ]]; then
    log_error "Limine config not found, skipping snapper setup"
    return
  fi

  log_info "Found limine config: $limine_config"

  # Extract kernel cmdline from existing config
  local cmdline
  cmdline=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

  if [[ -z "$cmdline" ]]; then
    log_warn "Could not extract cmdline from limine config"
    cmdline="root=UUID=XXXX rw"
  fi

  # Auto-detect OS name from limine.conf entry
  local os_name
  os_name=$(grep '^/:' "$limine_config" | head -1 | sed 's|^/:||')
  os_name="${os_name:-Arch Linux}"

  log_info "Detected OS name: $os_name"

  # Detect EFI mode
  local is_efi=""
  [[ -d /sys/firmware/efi ]] && is_efi="yes"

  # Configure mkinitcpio hooks for snapshot booting
  log_info "Configuring mkinitcpio hooks..."

  sudo mkdir -p /etc/mkinitcpio.conf.d

  sudo tee /etc/mkinitcpio.conf.d/snapper-hooks.conf >/dev/null <<'EOF'
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF

  sudo tee /etc/mkinitcpio.conf.d/thunderbolt.conf >/dev/null <<'EOF'
MODULES+=(thunderbolt)
EOF

  log_success "Configured mkinitcpio hooks"

  # Create /etc/default/limine
  log_info "Creating /etc/default/limine..."

  if [[ -n "$is_efi" ]]; then
    sudo tee /etc/default/limine >/dev/null <<EOF
TARGET_OS_NAME="$os_name"

ESP_PATH="/boot"

KERNEL_CMDLINE[default]="$cmdline"
KERNEL_CMDLINE[default]+=" quiet"

ENABLE_UKI=yes
CUSTOM_UKI_NAME="arch"

ENABLE_LIMINE_FALLBACK=yes

FIND_BOOTLOADERS=yes

BOOT_ORDER="*, *fallback, Snapshots"

MAX_SNAPSHOT_ENTRIES=5

SNAPSHOT_FORMAT_CHOICE=5
EOF
  else
    sudo tee /etc/default/limine >/dev/null <<EOF
TARGET_OS_NAME="$os_name"

ESP_PATH="/boot"

KERNEL_CMDLINE[default]="$cmdline"
KERNEL_CMDLINE[default]+=" quiet"

FIND_BOOTLOADERS=yes

BOOT_ORDER="*, *fallback, Snapshots"

MAX_SNAPSHOT_ENTRIES=5

SNAPSHOT_FORMAT_CHOICE=5
EOF
  fi

  log_success "Created /etc/default/limine"

  # Standardize limine.conf location
  if [[ "$limine_config" != "/boot/limine.conf" ]] && [[ -f "$limine_config" ]]; then
    sudo rm "$limine_config"
    log_info "Removed old config: $limine_config"
  fi

  # Create /boot/limine.conf with Catppuccin Mocha theming
  log_info "Creating /boot/limine.conf..."
  sudo tee /boot/limine.conf >/dev/null <<'EOF'
default_entry: 2
interface_branding: Arch Linux
interface_branding_color: 2
hash_mismatch_panic: no

term_background: 1e1e2e
backdrop: 1e1e2e

term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;cba6f7;94e2d5;cdd6f4
term_palette_bright: 45475a;f38ba8;a6e3a1;f9e2af;89b4fa;cba6f7;94e2d5;cdd6f4

term_foreground: cdd6f4
term_foreground_bright: cdd6f4
term_background_bright: 313244
EOF

  log_success "Created /boot/limine.conf"

  # Create snapper configs
  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    sudo snapper -c root create-config /
    log_success "Created snapper config: root"
  fi

  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    sudo snapper -c home create-config /home
    log_success "Created snapper config: home"
  fi

  # Enable btrfs quota
  sudo btrfs quota enable / 2>/dev/null || true

  # Tweak snapper configs
  for config in root home; do
    local config_file="/etc/snapper/configs/$config"
    if [[ -f "$config_file" ]]; then
      sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' "$config_file"
      sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' "$config_file"
      sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' "$config_file"
      sudo sed -i 's/^SPACE_LIMIT="0.5"/SPACE_LIMIT="0.3"/' "$config_file"
      sudo sed -i 's/^FREE_LIMIT="0.2"/FREE_LIMIT="0.3"/' "$config_file"
    fi
  done

  # Enable services
  sudo systemctl enable limine-snapper-sync.service
  sudo systemctl enable snapper-timeline.timer
  sudo systemctl enable snapper-cleanup.timer

  # Regenerate initramfs with new hooks
  log_info "Regenerating initramfs..."
  sudo mkinitcpio -P

  # Update limine configuration
  log_info "Running limine-update..."
  sudo limine-update

  # Clean up archinstall-created Limine boot entries
  if [[ -n "$is_efi" ]] && command -v efibootmgr &>/dev/null; then
    while IFS= read -r bootnum; do
      sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1
    done < <(efibootmgr | grep -E "^Boot[0-9]{4}\*? Arch Linux Limine" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')
    log_info "Cleaned up old EFI boot entries"
  fi

  log_success "Snapper configured with Limine"
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
    # Require limine bootloader for snapper integration
    if ! command -v limine &>/dev/null; then
      log_error "Limine bootloader is required. Install it during Arch installation."
      log_error "See: https://wiki.archlinux.org/title/Limine"
      exit 1
    fi

    if ! command -v yay &>/dev/null && prompt_confirm "Install yay (AUR helper)?"; then
      sudo pacman -S --needed --noconfirm git base-devel
      local tmp_dir
      tmp_dir=$(mktemp -d)
      git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
      (cd "$tmp_dir/yay" && makepkg -si --noconfirm) && rm -rf "$tmp_dir"
      log_success "yay installed"
    fi

    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
      log_info "Enabling multilib repository..."
      sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
      sudo pacman -Sy
      log_success "Multilib repository enabled"
    fi

    log_info "Some operations require sudo privileges"
    sudo -v
  fi
  log_success "Preflight checks passed"
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
  elif [[ "$OS" == "arch" ]]; then
    local pacman_file="$DOTFILES_DIR/packages/arch.pacman"
    local aur_file="$DOTFILES_DIR/packages/arch.aur"

    log_info "Updating package database..."
    sudo pacman -Sy

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
  echo ""
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

  # zsh files (zshrc -> ~/.zshrc, zprofile -> ~/.zprofile)
  local zsh_dir="$DOTFILES_DIR/zsh"
  [[ -f "$zsh_dir/zshrc" ]] && backup_and_symlink "$zsh_dir/zshrc" "$HOME/.zshrc"
  [[ -f "$zsh_dir/zprofile" ]] && backup_and_symlink "$zsh_dir/zprofile" "$HOME/.zprofile"

  # OS-specific config symlinks
  if [[ -d "$DOTFILES_DIR/config/$OS" ]]; then
    for item in "$DOTFILES_DIR/config/$OS"/*; do
      [[ -e "$item" ]] || continue
      local name
      name=$(basename "$item")

      # Skip themes (handled separately), systemd (handled below), and hypr (copied instead of symlinked)
      [[ "$name" == "themes" || "$name" == "systemd" || "$name" == "hypr" ]] && continue

      backup_and_symlink "$item" "$HOME/.config/$name"
    done
  fi

  # Hypr configs (copied to allow local modifications like NVIDIA detection)
  if [[ -d "$DOTFILES_DIR/config/$OS/hypr" ]]; then
    if [[ ! -d "$HOME/.config/hypr" ]]; then
      log_info "Copying hypr configs..."
      cp -R "$DOTFILES_DIR/config/$OS/hypr" "$HOME/.config/hypr"
      log_success "Hypr configs copied to ~/.config/hypr"
    else
      log_info "Hypr config already exists, skipping (preserving user edits)"
    fi
  fi

  # Systemd user services
  if [[ -d "$DOTFILES_DIR/config/$OS/systemd/user" ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    for service in "$DOTFILES_DIR/config/$OS/systemd/user"/*; do
      [[ -f "$service" ]] || continue
      backup_and_symlink "$service" "$HOME/.config/systemd/user/$(basename "$service")"
    done
    systemctl --user daemon-reload
  fi

  # XDG terminals list
  [[ -f "$DOTFILES_DIR/config/$OS/xdg-terminals.list" ]] &&
    backup_and_symlink "$DOTFILES_DIR/config/$OS/xdg-terminals.list" "$HOME/.config/xdg-terminals.list"

  # Desktop files
  if [[ -d "$DOTFILES_DIR/config/$OS/applications" ]]; then
    mkdir -p "$HOME/.local/share/applications"
    for desktop in "$DOTFILES_DIR/config/$OS/applications"/*.desktop; do
      [[ -f "$desktop" ]] || continue
      backup_and_symlink "$desktop" "$HOME/.local/share/applications/$(basename "$desktop")"
    done
  fi

  log_success "Symlinks configured"
}

setup_arch_extras() {
  [[ "$OS" != "arch" ]] && return
  echo ""
  log_info "Setting up Arch Linux configuration..."

  prompt_confirm "Run hardware detection (NVIDIA/Intel)?" && {
    detect_nvidia || true
    detect_intel || true
  }

  if prompt_confirm "Enable system services?"; then
    for svc in sddm.service docker.service ufw.service power-profiles-daemon.service bluetooth.service; do
      if systemctl list-unit-files --no-legend "$svc" 2>/dev/null | grep -q "$svc"; then
        sudo systemctl enable --now "$svc" && log_success "Enabled: $svc"
      else
        log_warn "Service not found: $svc"
      fi
    done
  fi

  prompt_confirm "Configure Docker daemon?" && setup_docker
  prompt_confirm "Configure SDDM autologin?" && setup_sddm
  prompt_confirm "Configure Snapper (btrfs snapshots)?" && setup_snapper
  prompt_confirm "Set default applications (mimetypes)?" && setup_mimetypes
  setup_user_groups
  setup_fast_shutdown
  setup_pacman

  # Configure mDNS resolution for printer discovery
  if grep -q "^hosts:" /etc/nsswitch.conf && ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve files myhostname dns/' /etc/nsswitch.conf
    log_success "Configured mDNS resolution"
  fi

  # Network stack setup
  if prompt_confirm "Configure network stack (iwd + systemd-resolved)?"; then
    if [[ -x "$DOTFILES_DIR/bin/arch/setup-network" ]]; then
      "$DOTFILES_DIR/bin/arch/setup-network"
    fi
  fi

  if [[ -d "$DOTFILES_DIR/bin/arch" ]]; then
    mkdir -p "$HOME/.local/bin"
    for script in "$DOTFILES_DIR/bin/arch"/*; do
      [[ -f "$script" ]] || continue
      backup_and_symlink "$script" "$HOME/.local/bin/$(basename "$script")"
      chmod +x "$script"
    done
  fi

  # System configs (require sudo)
  if [[ -d "$DOTFILES_DIR/config/arch/systemd/logind.conf.d" ]]; then
    sudo mkdir -p /etc/systemd/logind.conf.d
    for conf in "$DOTFILES_DIR/config/arch/systemd/logind.conf.d"/*; do
      [[ -f "$conf" ]] || continue
      sudo cp "$conf" "/etc/systemd/logind.conf.d/$(basename "$conf")"
    done
    log_success "Installed logind configs"
  fi

  if [[ -d "$DOTFILES_DIR/config/arch/systemd/sleep.conf.d" ]]; then
    sudo mkdir -p /etc/systemd/sleep.conf.d
    for conf in "$DOTFILES_DIR/config/arch/systemd/sleep.conf.d"/*; do
      [[ -f "$conf" ]] || continue
      sudo cp "$conf" "/etc/systemd/sleep.conf.d/$(basename "$conf")"
    done
    log_success "Installed sleep configs"
  fi

  if [[ -d "$DOTFILES_DIR/config/arch/modprobe.d" ]]; then
    sudo mkdir -p /etc/modprobe.d
    for conf in "$DOTFILES_DIR/config/arch/modprobe.d"/*; do
      [[ -f "$conf" ]] || continue
      sudo cp "$conf" "/etc/modprobe.d/$(basename "$conf")"
    done
    log_success "Installed modprobe configs"
  fi

  log_success "Arch extras configured"
}

setup_keyring() {
  [[ "$OS" == "macos" ]] && return

  local keyring_dir="$HOME/.local/share/keyrings"
  if [[ -f "$keyring_dir/default" ]]; then
    log_info "GNOME Keyring already configured, skipping"
    return
  fi

  log_info "Setting up GNOME Keyring..."
  mkdir -p "$keyring_dir"
  chmod 700 "$keyring_dir"

  cat >"$keyring_dir/Default_keyring.keyring" <<EOF
[keyring]
display-name=Default keyring
ctime=$(date +%s)
mtime=$(date +%s)
lock-on-idle=false
lock-after=false
EOF
  chmod 600 "$keyring_dir/Default_keyring.keyring"

  echo "Default_keyring" >"$keyring_dir/default"
  chmod 644 "$keyring_dir/default"

  log_success "GNOME Keyring configured (auto-unlock enabled)"
}

setup_firewall() {
  [[ "$OS" != "arch" ]] && return
  echo ""

  command -v ufw &>/dev/null || return

  if prompt_confirm "Configure UFW firewall (deny incoming, allow outgoing)?"; then
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw --force enable
    log_success "UFW firewall configured"
  fi
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

  echo ""
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

  # Apply GTK theme (one-time setup)
  if command -v gsettings &>/dev/null; then
    # GTK theme
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

    # Icon theme
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"

    # Fonts
    gsettings set org.gnome.desktop.interface font-name "Liberation Sans 11"
    gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 10"

    # Cursor
    gsettings set org.gnome.desktop.interface cursor-theme "Adwaita"
    gsettings set org.gnome.desktop.interface cursor-size 24

    log_success "GTK theme applied: Adwaita-dark with Papirus-Dark icons"
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
  setup_keyring
  setup_firewall
  setup_shell
  setup_theme
  print_summary
}

main "$@"
