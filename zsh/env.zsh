export EDITOR=vim

export TZ='Asia/Jakarta'
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

export SSH_AUTH_SOCK=$HOME/.gnupg/S.gpg-agent.ssh

# Docker
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# FZF
export FZF_BASE=/opt/homebrew/opt/fzf
export FZF_DEFAULT_OPTS='--height 40%'
export DEVELOPMENT_TOOLS_PATH=$HOME/Development/tools
