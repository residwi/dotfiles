alias grep='grep --color=auto'
alias zshrc="$EDITOR ~/.zshrc"
alias llha='ls -lha'

# Tools development
function tools() {
  docker-compose -f "${HOME}/Development/tools/docker-compose.yml" $@
}

alias redis-cli="tools run -it --rm redis redis-cli -h localhost -p 6379"

# Work
alias switch-clusters='~/Work/switch-clusters'
alias prepare-work-env='~/Work/prepare-work-env'

