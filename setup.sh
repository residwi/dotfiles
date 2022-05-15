#!/bin/bash

function install_oh_my_zsh {
    if [[ "$SHELL" != "/bin/zsh" ]]; then
        echo -e "\033[31;1m ZSH is not installed! \033[0m"
        exit 0
    fi

    echo -e "\033[92mInstalling oh-my-zsh...\033[0m"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

function install_zsh_plugins {
    echo -e "\033[92mInstalling zsh plugins...\033[0m"
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
}

function setup_symlinks {
    echo -e "\033[92mSetting up symlinks... \033[0m"
    ln -sfnv "$PWD/.asdfrc" ~/.asdfrc
    ln -sfnv "$PWD/.gitconfig" ~/.gitconfig
    ln -sfnv "$PWD/.zshrc" ~/.zshrc
}

function setup_tools_development {
    echo -e "\033[92mSetting up tools development... \033[0m"
    touch ~/.gitconfig.user
    mkdir -p ~/Development/tools
    ln -sfnv "$PWD/tools/docker-compose.yml" ~/Development/tools/docker-compose.yml
}

function setup_work_folder {
    echo -e "\033[92mCreate Work folder... \033[0m"
    mkdir ~/Work
    touch ~/Work/.gitconfig
}

install_oh_my_zsh
install_zsh_plugins
setup_symlinks
setup_tools_development
setup_work_folder

echo -e "\033[92mDone! \033[0m"
exit 0
