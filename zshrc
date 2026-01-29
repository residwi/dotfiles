export DOTFILES_BASE="$HOME/dotfiles"

# Load core configs
[[ -r "$DOTFILES_BASE/zsh/env.zsh" ]] && source "$DOTFILES_BASE/zsh/env.zsh"
[[ -r "$DOTFILES_BASE/zsh/path.zsh" ]] && source "$DOTFILES_BASE/zsh/path.zsh"

# Load tool configs
for config in "$DOTFILES_BASE/zsh/tools"/*.zsh(N); do
  [[ -r "$config" ]] && source "$config"
done

source "$DOTFILES_BASE/zsh/oh-my-zsh"

[[ -f ~/.aliases ]] && source ~/.aliases

# Load local overrides (these should override everything else)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ -f ~/.aliases.local ]] && source ~/.aliases.local
