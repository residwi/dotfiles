export EDITOR=vim

export TZ='Asia/Jakarta'
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

# Docker
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# FZF
export FZF_BASE=$(which fzf)
export FZF_DEFAULT_OPTS='--height 40%'
export DEVELOPMENT_TOOLS_PATH=$HOME/Development/tools

export PGHOST=localhost

export GPG_TTY=$(tty)

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

