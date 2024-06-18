#!/usr/bin/env sh

export DOTFILES_BASE="$HOME/dotfiles"

info() {
  echo "[ \033[00;94m..\033[0m ]  \033[00;94m$1\033[0m"
}

success() {
  echo "[ \033[00;92mOK\033[0m ]  \033[00;92m$1\033[0m"
}

fail() {
  echo "[ \033[00;91mFAIL\033[0m ]  \033[00;91m$1\033[0m"
  exit
}

link_file() {
  if [ -e "$2" ]; then
    if [ "$(readlink "$2")" = "$1" ]; then
      success "skipped, already linked $2"
      return 0
    else
      if [[ -f "$2" ]]; then
        info "Backup file $2"
        mv "$2" "$2.backup"
        success "$2 moved to $2.backup"
      fi
    fi
  fi
  ln -s "$1" "$2"
  success "$1 linked to $2"
}

install_oh_my_zsh() {
  search_locations=("/bin/zsh" "/usr/bin/zsh")
  for zsh_location in $search_locations; do
    if [[ ! -f "${zsh_location}" ]]; then
      fail "ZSH is not installed!"
    fi
  done

  info "Installing oh-my-zsh"

  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  success "oh-my-zsh has been installed"
}

install_zsh_plugins() {
  info "Installing zsh plugin: zsh-autosuggestions"
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  success "zsh-autosuggestions has been installed"

  info "Installing zsh plugin: zsh-syntax-highlighting"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  success "zsh-syntax-highlighting has been installed"
}

setup_gitconfig() {
  info 'Setup gitconfig'

  if [[ "$(git config --global --get dotfiles.managed)" != "true" ]]; then
    mv ~/.gitconfig ~/.gitconfig.backup
    success "Backup ~/.gitconfig to ~/.gitconfig.backup"
  else
    info "already managed by dotfiles"
  fi

  git config --global include.path ~/.gitconfig.global
  git config --global dotfiles.managed true

  success "gitconfig installed"
}

setup_symlinks() {
  info "Setup symlinks"

  symlink_files=$(find -H "$DOTFILES_BASE" -maxdepth 3 -name '*.symlink' -not -path '*.git*')
  while read src; do
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done <<< "$symlink_files"
}

setup_tools_development() {
  info "Setting up tools for development"

  if [[ ! -d ~/Development/tools ]]; then
    mkdir -p ~/Development/tools
    success "~/Development/tools/ has been created"
  fi

  link_file "$DOTFILES_BASE/tools/docker-compose.yml" ~/Development/tools/docker-compose.yml
}

setup_work_folder() {
  info "Setting up Work folder"

  if [[ ! -d ~/Work ]]; then
    mkdir -p ~/Work
    success "~/Work/ has been created"
  fi

  if [[ ! -f ~/Work/.gitconfig ]]; then
    touch ~/Work/.gitconfig
    success "~/Work/.gitconfig has been created"
  fi


  if [[ ! -f ~/Work/switch-clusters ]]; then
    touch ~/Work/switch-clusters
    chmod +x ~/Work/switch-clusters
    success "~/Work/switch-clusters has been created"
  fi


  if [[ ! -f ~/Work/prepare-work-env ]]; then
    touch ~/Work/prepare-work-env
    chmod +x ~/Work/prepare-work-env
    success "~/Work/prepare-work-env has been created"
  fi
}

setup_neovim() {
  info "Setting up NeoVim"

  if [[ ! -d ~/.config ]]; then
    mkdir -p ~/.config
    success "~/.config has been created"
  fi

  link_file "$DOTFILES_BASE/nvim" ~/.config/nvim
}

install_oh_my_zsh
install_zsh_plugins
setup_gitconfig
setup_symlinks
setup_tools_development
setup_work_folder
setup_neovim

success "install dotfiles finished"
exit 0
