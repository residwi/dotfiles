export DOTFILES_BASE="$HOME/dotfiles"

# Loads all readable .zsh config files from pre, main, and post folders in order
_load_zsh_configs() {
  local config_dir="$DOTFILES_BASE/zsh/configs"

  for config in "$config_dir/pre"/*.zsh(N); do
    [[ -r "$config" ]] && source "$config"
  done

  for config in "$config_dir"/*.zsh(N); do
    [[ -r "$config" ]] && source "$config"
  done

  for config in "$config_dir/post"/*.zsh(N); do
    [[ -r "$config" ]] && source "$config"
  done
}

_load_zsh_configs && unset -f _load_zsh_configs

autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

source "$DOTFILES_BASE/zsh/oh-my-zsh"

[[ -f ~/.aliases ]] && source ~/.aliases

# Load local overrides (these should override everything else)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ -f ~/.aliases.local ]] && source ~/.aliases.local
