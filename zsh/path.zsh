if [[ "$(uname -s)" == "Darwin" ]]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

  # https://github.com/Homebrew/homebrew-cask/pull/120606
  source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc
fi
