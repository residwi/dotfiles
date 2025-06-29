namespace :install do
  desc "Install Homebrew and packages"
  task :homebrew do
    include Utils

    section "Install Homebrew"

    if command_exists?("brew")
      success "Homebrew already installed"
    else
      run %( /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" )
    end
  end

  desc "Install brew packages"
  task :brew_packages do
    include Utils

    section "Install Homebrew packages"

    warning "Homebrew not installed, skipping package installation" unless command_exists?("brew")

    brewfile_path = File.join(DOTFILES_BASE, "Brewfile")
    if File.exist?(brewfile_path)
      run "brew bundle --file=#{brewfile_path}"
    else
      warning "No Brewfile found, skipping package installation"
    end
  end
end
